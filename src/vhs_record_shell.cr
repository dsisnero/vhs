# vhs-record-shell is the launcher behind `vhs record`.
#
# `record` needs the recorded shell to own its pseudo-terminal: it has to be a
# session leader whose controlling terminal is the pty slave, otherwise the line
# discipline has no foreground process group (Ctrl+C delivers no SIGINT, Ctrl+Z
# cannot suspend) and bash prints "no job control in this shell".
#
# That belongs between fork and exec, and Crystal's Process has no pre-exec hook
# (nor a `setsid` binding), so this tiny program is spawned as an ordinary child
# and does the work before exec'ing the real shell:
#
#     setsid() → open(slave) → [TIOCSWINSZ] → ioctl(TIOCSCTTY)
#              → dup2(slave, 0/1/2) → execvp(shell)
#
# That is exactly upstream's combination of pty.StartWithSize (the window size)
# and syscall.SysProcAttr{Setsid: true, Setctty: true} (the session) in
# creack/pty.
#
#     vhs-record-shell /dev/ttys012 bash [rows cols]
require "./vhs/pty"

{% unless flag?(:unix) %}
  {% raise "vhs-record-shell needs POSIX sessions (setsid) and exec" %}
{% end %}

lib LibC
  fun setsid : Int32
end

module Vhs::RecordShell
  extend self

  def run(args = ARGV) : NoReturn
    unless args.size == 2 || args.size == 4
      STDERR.puts "usage: vhs-record-shell <pty-slave> <shell> [rows cols]"
      exit 2
    end

    slave_path = args[0]
    shell = args[1]

    # A new session; this process becomes its leader and its own process group.
    fail_with("setsid") if LibC.setsid == -1

    slave = open_slave(slave_path)
    apply_size(slave, args[2]?, args[3]?)
    become_controlling_terminal(slave)
    redirect_stdio(slave)

    # The Crystal runtime ignores SIGPIPE, and an ignored disposition survives
    # exec: without this the recorded shell, and everything it runs, would fail
    # to die from a closed pipe (`yes | head -1` would spin).
    Signal::PIPE.reset

    exec(shell)
  end

  private def open_slave(path : String) : Int32
    fd = LibC.open(path, Pty::O_RDWR)
    fail_with("open #{path}") if fd < 0

    fd
  end

  # apply_size sets the window size inherited from the recording terminal, like
  # creack/pty's StartWithSize. A failure is reported but not fatal: upstream only
  # logs a failed pty.InheritSize and records anyway.
  private def apply_size(fd : Int32, rows : String?, cols : String?) : Nil
    return if rows.nil? || cols.nil?

    row_count = rows.to_u16?
    col_count = cols.to_u16?
    return if row_count.nil? || col_count.nil?

    size = LibC::Winsize.new
    size.ws_row = row_count
    size.ws_col = col_count

    return if Term.set_winsize(fd, size)

    STDERR.puts "vhs-record-shell: could not resize pty: #{Errno.value.message}"
  end

  # become_controlling_terminal adopts the pty slave, like creack/pty's
  # `Setctty`; opening it after setsid is usually enough, the ioctl is explicit.
  private def become_controlling_terminal(fd : Int32) : Nil
    fail_with("TIOCSCTTY") if LibC.ioctl(fd, Pty::TIOCSCTTY, 0) != 0
  end

  private def redirect_stdio(fd : Int32) : Nil
    {0, 1, 2}.each do |target|
      fail_with("dup2") if LibC.dup2(fd, target) < 0
    end

    # `open` can hand back 0, 1 or 2 because the launcher starts with them closed.
    LibC.close(fd) if fd > 2
  end

  private def exec(shell : String) : NoReturn
    argv = [shell.to_unsafe, Pointer(UInt8).null]
    LibC.execvp(shell, argv.to_unsafe)

    fail_with("exec #{shell}")
  end

  private def fail_with(what : String) : NoReturn
    STDERR.puts "vhs-record-shell: #{what}: #{Errno.value.message}"
    STDERR.flush
    exit 1
  end
end

Vhs::RecordShell.run
