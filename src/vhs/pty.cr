require "c/fcntl"
require "c/termios"
require "c/unistd"

{% unless flag?(:unix) %}
  {% raise "vhs record needs POSIX pseudo-terminals (posix_openpt + termios); this port builds on macOS, Linux, and the BSDs" %}
{% end %}

lib LibC
  struct Winsize
    ws_row : UInt16
    ws_col : UInt16
    ws_xpixel : UInt16
    ws_ypixel : UInt16
  end

  fun posix_openpt(oflag : Int32) : Int32
  fun grantpt(fd : Int32) : Int32
  fun unlockpt(fd : Int32) : Int32
  fun ptsname(fd : Int32) : UInt8*
  # ioctl is variadic in libc, and the extra arguments must be passed as such:
  # with a fixed prototype the arm64 macOS ABI puts the pointer in a register
  # that the callee's va_arg never reads, so every request silently does nothing.
  fun ioctl(fd : Int32, request : ULong, ...) : Int32
end

module Vhs
  # Pty ports the slice of creack/pty and golang.org/x/term that
  # upstream `record.go` uses.
  #
  # A pseudo-terminal is a master/slave file-descriptor pair: the recorded shell
  # runs with the slave as its stdio so it looks interactive, while the recorder
  # reads and writes the master. The POSIX calls are `posix_openpt`/`grantpt`/
  # `unlockpt`/`ptsname`; Linux, macOS and the BSDs all provide them.
  module Pty
    extend self

    O_RDWR   = 0x0002
    O_NOCTTY = {% if flag?(:darwin) %} 0x20000 {% elsif flag?(:linux) %} 0x0100 {% else %} 0x0000 {% end %}

    TIOCGWINSZ = {% if flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) || flag?(:netbsd) %} 0x40087468_u64 {% else %} 0x5413_u64 {% end %}
    TIOCSWINSZ = {% if flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) || flag?(:netbsd) %} 0x80087467_u64 {% else %} 0x5414_u64 {% end %}
    TIOCGPGRP  = {% if flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) || flag?(:netbsd) %} 0x40047477_u64 {% else %} 0x540F_u64 {% end %}
    TIOCSCTTY  = {% if flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) || flag?(:netbsd) %} 0x20007461_u64 {% else %} 0x540E_u64 {% end %}

    # HELPER_NAME is the launcher that gives the recorded shell its own session
    # and controlling terminal (src/vhs_record_shell.cr).
    HELPER_NAME = "vhs-record-shell"

    @@helper_path : String? = nil

    # helper_path is the launcher to run: a value set by the caller or the
    # environment ($VHS_RECORD_HELPER), else the copy next to the running binary,
    # else one on PATH.
    def helper_path : String
      @@helper_path ||= find_helper
    end

    def helper_path=(path : String?) : Nil
      @@helper_path = path
    end

    private def find_helper : String
      if override = ENV["VHS_RECORD_HELPER"]?
        return override
      end

      if exe = Process.executable_path
        sibling = File.join(File.dirname(exe), HELPER_NAME)
        return sibling if File::Info.executable?(sibling)
      end

      Process.find_executable(HELPER_NAME) || raise RuntimeError.new(
        "#{HELPER_NAME} not found: build it with `make build`, install it next to vhs, " \
        "put it on PATH, or set VHS_RECORD_HELPER")
    end

    # Session is a running child whose stdio is a pty, plus the master side.
    class Session
      getter master : IO::FileDescriptor
      getter process : Process

      def initialize(@master : IO::FileDescriptor, @process : Process)
      end

      # read reads from the pty master. A closed slave surfaces as EIO on Linux
      # and macOS, which every pty consumer treats as end of file; so does this.
      def read(slice : Bytes) : Int32
        @master.read(slice)
      rescue IO::Error
        0
      end

      # write writes to the pty master, i.e. types into the recorded shell.
      def write(slice : Bytes) : Nil
        @master.write(slice)
        @master.flush
      rescue IO::Error
        # The shell may have exited between a keystroke and its write; upstream
        # ignores copy errors the same way.
      end

      # close closes the master side, like upstream's terminal.Close().
      #
      # Upstream never waits for the shell: closing the master hangs the pty up,
      # and the Go runtime reaps the process. `process` is exposed for callers
      # that want the exit status.
      def close : Nil
        @master.close unless @master.closed?
      end
    end

    # start runs `command` with its stdio on a new pty and returns the session.
    #
    # Upstream calls pty.Start(exec.Command(shell)), so the program is the shell
    # name with no arguments; `env` is merged into the inherited environment
    # exactly like `append(os.Environ(), "VHS_RECORD=true")`.
    #
    # The child is the record launcher, which makes itself a session leader,
    # adopts the pty slave as its controlling terminal, applies `size` and execs
    # the shell, so the recorded pid and exit status are the shell's.
    #
    # `size` is creack/pty's StartWithSize: upstream's `vhs record` starts the pty
    # and then calls pty.InheritSize, which is the same ioctl, but doing it in the
    # launcher means the size is right before the shell exists.
    def start(command : String, env : Hash(String, String)? = nil, size : LibC::Winsize? = nil) : Session
      ensure_command(command)
      master_fd = open_master
      slave_path = slave_name(master_fd)
      # The launcher execs this name as given, so the shell keeps upstream's
      # argv[0] (os/exec resolves PATH but leaves Args[0] alone) and does its own
      # PATH lookup.
      args = [slave_path, command]
      args.concat([size.ws_row.to_s, size.ws_col.to_s]) if size

      begin
        process = Process.new(
          helper_path,
          args,
          env: env,
          input: Process::Redirect::Close,
          output: Process::Redirect::Close,
          error: Process::Redirect::Inherit,
        )
      rescue ex
        LibC.close(master_fd)
        raise ex
      end

      # The launcher owns the slave from here; the recorder keeps only the master,
      # so the pty reaches end of file as soon as the shell exits.
      master = IO::FileDescriptor.new(master_fd)
      master.sync = true
      Session.new(master, process)
    end

    # ensure_command checks the shell before the launcher starts, so a missing
    # shell raises here like os/exec does instead of dying after the pty exists.
    # Resolution is only for the check: the launcher still execs the given name.
    private def ensure_command(command : String) : Nil
      return if command.includes?(File::SEPARATOR) && File::Info.executable?(command)
      return if Process.find_executable(command)

      raise File::NotFoundError.new("exec: #{command}: no such file or directory", file: command)
    end

    private def open_master : Int32
      fd = LibC.posix_openpt(O_RDWR | O_NOCTTY)
      raise RuntimeError.from_errno("posix_openpt") if fd < 0

      begin
        raise RuntimeError.from_errno("grantpt") if LibC.grantpt(fd) != 0
        raise RuntimeError.from_errno("unlockpt") if LibC.unlockpt(fd) != 0
      rescue ex
        LibC.close(fd)
        raise ex
      end

      fd
    end

    private def slave_name(fd : Int32) : String
      name = LibC.ptsname(fd)
      raise RuntimeError.from_errno("ptsname") if name.null?

      String.new(name)
    end
  end

  # Term ports the terminal-state helpers record.go needs from
  # golang.org/x/term: raw mode, restore, and window-size copying.
  module Term
    extend self

    # terminal? reports whether the IO is a terminal, like
    # term.IsTerminal/isatty. Crystal's IO::FileDescriptor#tty? is that isatty.
    def terminal?(io : IO) : Bool
      io.as?(IO::FileDescriptor).try(&.tty?) || false
    end

    # raw puts the terminal into raw mode and returns the previous state, like
    # term.MakeRaw.
    def raw(io : IO::FileDescriptor) : LibC::Termios
      previous = get_state(io)
      raw = previous
      LibC.cfmakeraw(pointerof(raw))
      raise RuntimeError.from_errno("tcsetattr") if LibC.tcsetattr(io.fd, LibC::TCSAFLUSH, pointerof(raw)) != 0

      previous
    end

    # restore returns the terminal to a state previously returned by `raw`,
    # like term.Restore.
    def restore(io : IO::FileDescriptor, state : LibC::Termios) : Nil
      raise RuntimeError.from_errno("tcsetattr") if LibC.tcsetattr(io.fd, LibC::TCSAFLUSH, pointerof(state)) != 0
    end

    # winsize reads the terminal window size.
    def winsize(io : IO::FileDescriptor) : LibC::Winsize?
      size = uninitialized LibC::Winsize
      return nil if LibC.ioctl(io.fd, Pty::TIOCGWINSZ, pointerof(size)) != 0

      size
    end

    # foreground_pgroup reads the terminal's foreground process group, which is
    # tcgetpgrp(3). A terminal with no controlling session reports nil.
    def foreground_pgroup(io : IO::FileDescriptor) : Int32?
      pgroup = 0
      return nil if LibC.ioctl(io.fd, Pty::TIOCGPGRP, pointerof(pgroup)) != 0
      return nil if pgroup == 0

      pgroup
    end

    # set_winsize applies a window size to a terminal.
    def set_winsize(io : IO::FileDescriptor, size : LibC::Winsize) : Bool
      set_winsize(io.fd, size)
    end

    # set_winsize applies a window size to a raw file descriptor. The record
    # launcher needs this form: wrapping a pty fd in an IO puts it in the event
    # loop as non-blocking, and the shell would inherit O_NONBLOCK on its stdio.
    def set_winsize(fd : Int32, size : LibC::Winsize) : Bool
      copy = size
      LibC.ioctl(fd, Pty::TIOCSWINSZ, pointerof(copy)) == 0
    end

    private def get_state(io : IO::FileDescriptor) : LibC::Termios
      state = uninitialized LibC::Termios
      raise RuntimeError.from_errno("tcgetattr") if LibC.tcgetattr(io.fd, pointerof(state)) != 0

      state
    end
  end
end
