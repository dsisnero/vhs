require "../spec_helper"

# Helpers for the record specs. Top-level defs are inherited by every example,
# which methods nested in `describe` blocks are not.

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

# close_pty ends the child, reaps it, and closes the master. Closing the master
# alone does not wake a slave reader on macOS, so the child is stopped first.
def close_pty(session : Vhs::Pty::Session) : Nil
  session.process.terminate
  session.process.wait
  session.close
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

module Vhs
  # Characterization specs for the record.go port: the pty plumbing that upstream
  # gets from creack/pty and golang.org/x/term, plus Record itself.
  describe Pty do
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

    it "carries the child's exit status" do
      script = pty_script("fail.sh", "#!/bin/sh\nexit 3\n")

      session = Pty.start(script)
      buffer = Bytes.new(16)
      while session.read(buffer) > 0
      end

      session.close
      session.process.wait.exit_code.should eq(3)
    end

    it "round-trips a window size through the master" do
      session = Pty.start("cat")
      size = LibC::Winsize.new
      size.ws_col = 100
      size.ws_row = 40

      Term.set_winsize(session.master, size).should be_true

      if read = Term.winsize(session.master)
        read.ws_col.should eq(100)
        read.ws_row.should eq(40)
      else
        fail "the pty has no window size"
      end

      close_pty(session)
    end

    it "does not inherit a size from a non-terminal" do
      session = Pty.start("cat")
      session.inherit_size(IO::Memory.new).should be_false
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
