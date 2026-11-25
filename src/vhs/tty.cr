require "socket"

module Vhs
  # Spawns the ttyd process, ported from upstream tty.go.
  #
  # ttyd serves xterm.js on a local port; the Rod browser connects to it, and the
  # text and cursor canvases are what the recorder captures.
  module Tty
    extend self

    # random_port returns a port number that is free right now.
    #
    # Upstream binds ":0", reads the assigned port, and closes the socket. The
    # port is then used by ttyd, so there is a small race; that is upstream's
    # behaviour too.
    def random_port : Int32
      server = TCPServer.new("127.0.0.1", 0)
      begin
        server.local_address.port
      ensure
        server.close
      end
    end

    # build_tty_cmd returns the ttyd arguments for the given port and shell.
    #
    # The terminal options match upstream: canvas renderer, no resize overlay,
    # sixel and custom glyphs enabled, single connection, writable.
    def build_tty_args(port : Int32, shell : Shell) : Array(String)
      args = [
        "--port=#{port}",
        "--interface", "127.0.0.1",
        "-t", "rendererType=canvas",
        "-t", "disableResizeOverlay=true",
        "-t", "enableSixel=true",
        "-t", "customGlyphs=true",
        "--once", # allow one connection, then exit
        "--writable",
      ]

      args.concat(shell.command)
      args
    end

    # start spawns ttyd for the shell and returns the process.
    #
    # The shell's environment is added to the inherited one, like upstream's
    # `append(shell.Env, os.Environ()...)`.
    def start(port : Int32, shell : Shell) : Process
      args = build_tty_args(port, shell)
      env = shell.env.empty? ? nil : to_env_hash(shell.env)

      Process.new("ttyd", args, env: env)
    end

    private def to_env_hash(entries : Array(String)) : Hash(String, String)
      entries.each_with_object({} of String => String) do |entry, hash|
        next unless entry.includes?('=')

        key, value = entry.split('=', 2)
        hash[key] = value
      end
    end
  end
end
