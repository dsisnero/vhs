require "../spec_helper"

# Helpers for the record specs. Top-level defs are inherited by every example,
# which methods nested in `describe` blocks are not.

# RecordShellBinary builds src/vhs_record_shell.cr once per spec run (and again
# whenever its source is newer) and points Vhs::Pty at the result. `make build`
# ships the same binary as bin/vhs-record-shell.
module RecordShellBinary
  extend self

  SOURCE = "src/vhs_record_shell.cr"
  OUTPUT = File.expand_path("temp/vhs-record-shell")

  def build : String
    compile unless fresh?
    Vhs::Pty.helper_path = OUTPUT
    OUTPUT
  end

  private def fresh? : Bool
    File.exists?(OUTPUT) && File.info(OUTPUT).modification_time >= File.info(SOURCE).modification_time
  end

  private def compile : Nil
    Dir.mkdir_p(File.dirname(OUTPUT))
    status = Process.run(
      ENV["CRYSTAL"]? || "crystal",
      ["build", SOURCE, "-o", OUTPUT],
      env: {"CRYSTAL_CACHE_DIR" => ENV["CRYSTAL_CACHE_DIR"]? || File.expand_path(".crystal-cache")},
      output: STDOUT,
      error: STDERR,
    )
    raise "could not build #{OUTPUT}" unless status.success?
  end
end

# with_shell sets $SHELL for the block and restores it afterwards.
def with_shell(value : String?, &)
  original = ENV["SHELL"]?
  begin
    if value.nil?
      ENV.delete("SHELL")
    else
      ENV["SHELL"] = value
    end
    yield
  ensure
    if original.nil?
      ENV.delete("SHELL")
    else
      ENV["SHELL"] = original
    end
  end
end

# not_a_terminal returns an open file descriptor that is not a tty.
def not_a_terminal : IO::FileDescriptor
  path = File.join("temp", "pty_spec", "not_a_tty")
  Dir.mkdir_p(File.dirname(path))
  File.write(path, "")
  File.open(path, "r")
end

# pty_script writes an executable shell script and returns its absolute path.
def pty_script(name : String, contents : String) : String
  dir = File.join("temp", "pty_spec")
  Dir.mkdir_p(dir)
  path = File.join(dir, name)
  File.write(path, contents)
  File.chmod(path, 0o755)
  File.expand_path(path)
end

# close_pty ends the child, reaps it, and closes the master. Closing the master
# alone does not wake a slave reader on macOS, so the child is stopped first.
def close_pty(session : Vhs::Pty::Session) : Nil
  session.process.terminate
  session.process.wait
  session.close
end

# wait_for_foreground polls the pty's foreground process group until the launcher
# has adopted the terminal. Process.new returns before the child runs setsid.
def wait_for_foreground(session : Vhs::Pty::Session) : Int32?
  deadline = Time.instant + 3.seconds
  while Time.instant < deadline
    if pgroup = Vhs::Term.foreground_pgroup(session.master)
      return pgroup
    end
    sleep 20.milliseconds
  end
  nil
end

# collect_pty reads the session in the background and returns the buffer plus the
# channel that fires when the pty reaches end of file.
def collect_pty(session : Vhs::Pty::Session) : {IO::Memory, Channel(Nil)}
  collected = IO::Memory.new
  done = Channel(Nil).new
  spawn do
    buffer = Bytes.new(4096)
    while (read = session.read(buffer)) > 0
      collected << String.new(buffer[0, read])
    end
    done.send(nil)
  end
  {collected, done}
end

module Vhs
  # Characterization specs for the record.go port: the pty plumbing that upstream
  # gets from creack/pty and golang.org/x/term, plus Record itself.
  describe Pty do
    before_each { RecordShellBinary.build }

    it "starts a child whose stdio is a terminal" do
      script = pty_script("probe.sh", <<-'SH')
        #!/bin/sh
        if [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then echo "stdio=tty"; else echo "stdio=notty"; fi
        echo "record=$VHS_RECORD"
        SH

      session = Pty.start(script, {"VHS_RECORD" => "true"})
      output = IO::Memory.new
      buffer = Bytes.new(4096)
      while (read = session.read(buffer)) > 0
        output << String.new(buffer[0, read])
      end

      session.close
      session.process.wait.success?.should be_true
      output.to_s.should contain("stdio=tty")
      output.to_s.should contain("record=true")
    end

    it "gives the shell a controlling terminal" do
      # creack/pty starts the child with Setsid + Setctty; the port does that in
      # the record launcher, so the shell owns the pty it runs on.
      session = Pty.start("cat")

      wait_for_foreground(session).should eq(session.process.pid)
      close_pty(session)
    end

    it "delivers Ctrl+C to the foreground command" do
      pending! "bash is required to record" if Process.find_executable("bash").nil?

      session = Pty.start("bash")
      collected, done = collect_pty(session)

      # `sleep` holds the foreground; ^C has to reach it for the shell to come
      # back and evaluate the next command. The terminal echoes the command as
      # typed, so the assertion looks for the result, not the input.
      session.write("sleep 60\r".to_slice)
      sleep 400.milliseconds
      session.write("\u0003".to_slice)
      sleep 300.milliseconds
      session.write("echo $((6*7))\r".to_slice)
      sleep 400.milliseconds
      session.write("exit\r".to_slice)

      exited = select
      when done.receive
        true
      when timeout(5.seconds)
        false
      end

      unless exited
        close_pty(session)
        fail "the shell never came back after Ctrl+C"
      end

      session.close
      collected.to_s.should contain("42")
    end

    it "carries the child's exit status" do
      script = pty_script("fail.sh", "#!/bin/sh\nexit 3\n")

      session = Pty.start(script)
      buffer = Bytes.new(16)
      while session.read(buffer) > 0
      end

      session.close
      session.process.wait.exit_code.should eq(3)
    end

    it "rejects a shell that does not exist" do
      expect_raises(File::NotFoundError) do
        Pty.start("vhs-no-such-shell")
      end

      expect_raises(File::NotFoundError) do
        Pty.start("/nonexistent/vhs-shell")
      end
    end

    it "applies the inherited window size before the shell starts" do
      size = LibC::Winsize.new
      size.ws_col = 100
      size.ws_row = 40

      session = Pty.start("cat", size: size)
      # The launcher applies the size before exec; the master only reports it once
      # the tty side is open.
      wait_for_foreground(session)
      read = Term.winsize(session.master)

      if read
        read.ws_col.should eq(100)
        read.ws_row.should eq(40)
      else
        fail "the pty has no window size"
      end

      close_pty(session)
    end

    it "resizes the pty through the master" do
      session = Pty.start("cat")
      wait_for_foreground(session)

      size = LibC::Winsize.new
      size.ws_col = 90
      size.ws_row = 30
      Term.set_winsize(session.master, size).should be_true

      read = Term.winsize(session.master)
      read.try(&.ws_col).should eq(90)
      read.try(&.ws_row).should eq(30)

      close_pty(session)
    end

    it "reports non-terminals" do
      Term.terminal?(IO::Memory.new).should be_false

      file = not_a_terminal
      begin
        Term.terminal?(file).should be_false
        Term.winsize(file).should be_nil
      ensure
        file.close
      end
    end
  end

  describe ".default_record_shell" do
    it "uses the basename of $SHELL" do
      with_shell("/usr/local/bin/fish") do
        Vhs.default_record_shell.should eq("fish")
      end
    end

    it "falls back to the default shell when $SHELL is unset or empty" do
      with_shell(nil) do
        Vhs.default_record_shell.should eq(DEFAULT_SHELL)
      end

      with_shell("") do
        Vhs.default_record_shell.should eq(DEFAULT_SHELL)
      end
    end

    it "keeps a bare shell name" do
      with_shell("zsh") do
        Vhs.default_record_shell.should eq("zsh")
      end
    end
  end

  describe ".record" do
    before_each { RecordShellBinary.build }

    it "records a session through the pty into tape commands" do
      pending! "bash is required to record" if Process.find_executable("bash").nil?

      input = IO::Memory.new("echo hi\rexit\r")
      output = IO::Memory.new
      terminal = IO::Memory.new

      Vhs.record("bash", input: input, output: output, terminal_output: terminal, log: IO::Memory.new)

      # The pty echoed the shell back to the recording terminal, and the tape
      # carries the same keystrokes as commands.
      terminal.to_s.should contain("echo hi")
      tape = output.to_s
      tape.should contain(%(Type "echo hi"))
      tape.should contain("Enter")
    end

    it "records a shell switch as a Set Shell command" do
      bash = Process.find_executable("bash")
      pending! "bash is required to record" if bash.nil?

      input = IO::Memory.new("exit\r")
      output = IO::Memory.new

      Vhs.record(bash, input: input, output: output, terminal_output: IO::Memory.new, log: IO::Memory.new)

      output.to_s.should contain("Set Shell #{bash}")
    end
  end
end
