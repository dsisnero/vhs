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

    # Session is a running child whose stdio is a pty, plus the master side.
    class Session
      getter master : IO::FileDescriptor
      getter process : Process

      def initialize(@master : IO::FileDescriptor, @process : Process)
      end

      # inherit_size copies the window size of `from` onto the pty, like
      # pty.InheritSize. It returns false when the source is not a terminal or
      # has no size to report.
      def inherit_size(from : IO) : Bool
        source = from.as?(IO::FileDescriptor)
        return false if source.nil? || !Term.terminal?(source)

        size = Term.winsize(source)
        return false if size.nil?

        Term.set_winsize(@master, size)
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
    def start(command : String, env : Hash(String, String)? = nil) : Session
      master_fd = open_master
      slave_path = slave_name(master_fd)
      slave = File.open(slave_path, "r+")

      begin
        process = Process.new(
          command,
          env: env,
          input: slave,
          output: slave,
          error: slave,
        )
      rescue ex
        slave.close
        LibC.close(master_fd)
        raise ex
      end

      # The child holds its own copy of the slave; the recorder only keeps the
      # master, so the pty reaches end of file as soon as the shell exits.
      slave.close

      master = IO::FileDescriptor.new(master_fd)
      master.sync = true
      Session.new(master, process)
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

    # set_winsize applies a window size to a terminal.
    def set_winsize(io : IO::FileDescriptor, size : LibC::Winsize) : Bool
      copy = size
      LibC.ioctl(io.fd, Pty::TIOCSWINSZ, pointerof(copy)) == 0
    end

    private def get_state(io : IO::FileDescriptor) : LibC::Termios
      state = uninitialized LibC::Termios
      raise RuntimeError.from_errno("tcgetattr") if LibC.tcgetattr(io.fd, pointerof(state)) != 0

      state
    end
  end
end
