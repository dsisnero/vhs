require "../spec_helper"

# with_path_entry prepends `dir` to PATH for the block and restores it.
def with_path_entry(dir : String, &)
  original = ENV["PATH"]?
  begin
    ENV["PATH"] = "#{dir}#{Process::PATH_DELIMITER}#{original}"
    yield
  ensure
    if original.nil?
      ENV.delete("PATH")
    else
      ENV["PATH"] = original
    end
  end
end

# fake_command installs an executable shell script named `name` in `dir` and
# returns the directory, ready for with_path_entry.
def fake_command(dir : String, name : String, contents : String) : String
  Dir.mkdir_p(dir)
  path = File.join(dir, name)
  File.write(path, contents)
  File.chmod(path, 0o755)
  File.expand_path(dir)
end

module Vhs
  # Characterization specs for the publish.go port. The upload itself is
  # delegated to OpenSSH, so the specs cover the pieces the port owns: the data
  # directory, the ssh invocation, the key and known_hosts files, and the full
  # round trip against a stand-in `ssh`.
  describe ".data_path" do
    it "matches go-app-paths' user scope for vhs" do
      env = {"HOME" => "/home/vhs"}
      {% if flag?(:darwin) %}
        Vhs.data_path(env).should eq("/home/vhs/Library/Application Support/vhs")
      {% elsif flag?(:win32) %}
        Vhs.data_path(env).should eq("/home/vhs/AppData/Local/vhs")
      {% else %}
        Vhs.data_path(env).should eq("/home/vhs/.local/share/vhs")
      {% end %}
    end

    it "honours LOCALAPPDATA and XDG_DATA_HOME" do
      {% if flag?(:win32) %}
        Vhs.data_path({"HOME" => "/home/vhs", "LOCALAPPDATA" => "/cache"}).should eq("/cache/vhs")
      {% elsif !flag?(:darwin) %}
        Vhs.data_path({"HOME" => "/home/vhs", "XDG_DATA_HOME" => "/xdg"}).should eq("/xdg/vhs")
      {% end %}
    end

    it "rejects an unknown home directory" do
      env = {"HOME" => ""}
      expect_raises(PublishError) do
        Vhs.data_path(env)
      end
    end
  end

  describe ".ssh_arguments" do
    it "mirrors upstream's ssh.ClientConfig" do
      args = Vhs.ssh_arguments("/data/vhs_ed25519", "/data/known_hosts")

      args.should eq([
        "-F", File::NULL,
        "-T",
        "-i", "/data/vhs_ed25519",
        "-o", "IdentitiesOnly=yes",
        "-o", "BatchMode=yes",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "UserKnownHostsFile=/data/known_hosts",
        "-p", "22",
        "vhs@#{GHOST_HOST}",
      ])
    end
  end

  describe ".publish_known_hosts" do
    it "creates a 0600 file once" do
      dir = File.join("temp", "publish_known_hosts")
      Dir.mkdir_p(dir)
      path = File.join(dir, "known_hosts")
      File.delete(path) if File.exists?(path)

      Vhs.publish_known_hosts(dir).should eq(path)
      File.exists?(path).should be_true

      File.write(path, "ghost.charm.sh ssh-ed25519 AAAA\n")
      Vhs.publish_known_hosts(dir).should eq(path)
      File.read(path).should contain("ghost.charm.sh")
    end
  end

  describe ".publish_key" do
    it "generates an Ed25519 key on first use and reuses it" do
      pending! "ssh-keygen is required to publish" if Process.find_executable("ssh-keygen").nil?

      dir = File.join("temp", "publish_key")
      Dir.mkdir_p(dir)
      path = File.join(dir, "vhs_ed25519")
      File.delete(path) if File.exists?(path)

      Vhs.publish_key(dir).should eq(path)
      File.read(path).should contain("PRIVATE KEY")

      written = File.info(path).modification_time
      Vhs.publish_key(dir).should eq(path)
      File.info(path).modification_time.should eq(written)
    end
  end

  describe ".publish" do
    it "streams the GIF to ssh and returns the server's URL" do
      pending! "ssh-keygen is required to publish" if Process.find_executable("ssh-keygen").nil?

      root = File.join("temp", "publish_spec")
      dir = File.join(root, "data")
      Dir.mkdir_p(dir)
      uploaded = File.expand_path(File.join(root, "uploaded.gif"))
      File.delete(uploaded) if File.exists?(uploaded)

      script = "#!/bin/sh\ncat > \"#{uploaded}\"\necho \"https://vhs.charm.sh/vhs-abc123\"\n"
      bin = fake_command(File.join(root, "bin"), "ssh", script)

      gif = File.join(root, "demo.gif")
      File.write(gif, "GIF89a-bytes")

      with_path_entry(bin) do
        Vhs.publish(gif, data_path: dir).should contain("https://vhs.charm.sh/vhs-abc123")
      end

      File.read(uploaded).should eq("GIF89a-bytes")
      File.exists?(File.join(dir, "known_hosts")).should be_true
      File.exists?(File.join(dir, "vhs_ed25519")).should be_true
    end

    it "raises the ssh error when the upload fails" do
      root = File.join("temp", "publish_fail")
      dir = File.join(root, "data")
      Dir.mkdir_p(dir)

      bin = fake_command(File.join(root, "bin"), "ssh", "#!/bin/sh\necho 'permission denied' >&2\nexit 255\n")

      gif = File.join(root, "demo.gif")
      File.write(gif, "GIF89a-bytes")

      with_path_entry(bin) do
        error = expect_raises(PublishError) do
          Vhs.publish(gif, data_path: dir)
        end
        error.message.should eq("permission denied")
      end
    end
  end

  describe ".publish_share_instructions" do
    it "prints the markdown, HTML, and link snippets" do
      io = IO::Memory.new
      Vhs.publish_share_instructions("https://vhs.charm.sh/vhs-abc123", io)

      output = io.to_s.gsub(/\e\[[0-9;]*m/, "")
      output.should contain("Share your GIF with Markdown:")
      output.should contain("![Made with VHS](https://vhs.charm.sh/vhs-abc123)")
      output.should contain("Or HTML (with badge):")
      output.should contain("<a ")
      output.should contain("https://stuff.charm.sh/vhs/badge.svg")
      output.should contain("Or link to it:")
    end
  end
end
