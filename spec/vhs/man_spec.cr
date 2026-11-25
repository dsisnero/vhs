require "../spec_helper"

module Vhs
  # Characterization specs for the man.go port: the manual's section bodies, the
  # markdown manual, and the roff page.
  #
  # `spec/fixtures/vhs.1` is upstream's own output (`go run . man` at the pinned
  # vendor revision) with the two COMMANDS blocks this port does not have removed:
  # cobra's generated `help` and the `serve` SSH server.
  describe Man do
    it "renders the roff page upstream's mango-cobra produces" do
      expected = File.read(File.join("spec", "fixtures", "vhs.1"))

      Man.man_page("2026-11-25").should eq(expected)
    end

    it "documents the commands this port has, in alphabetical order" do
      Man::COMMANDS.map(&.name).should eq(%w[new publish record themes validate])
    end

    it "lists the root flags with their shorthands" do
      Man::ROOT_FLAGS.map(&.label).should eq(["-o, --output", "-p, --publish", "-q, --quiet"])
    end

    it "turns % symbols into markdown code spans and escapes angle brackets" do
      Man.sanitize_markdown("The %Output% command <path>").should eq("The `Output` command &lt;path&gt;")
    end

    it "drops % symbols for roff" do
      Man.sanitize_special("The %Output% command").should eq("The Output command")
    end

    it "keeps upstream's markdown manual structure" do
      manual = Man.markdown_manual

      manual.should start_with("# MANUAL\n")
      manual.should contain("# OUTPUT\n")
      manual.should contain("# SETTING\n")
      manual.should contain("# BUGS\n")
      manual.should contain("\n# AUTHOR\n")
      manual.should contain("* `Output` &lt;path&gt;.(gif|webm|mp4)")
    end

    it "roff-escapes periods the way mango does" do
      page = Man.man_page("2026-11-25")

      page.should contain("vhs\\&.charm\\&.sh")
      page.should contain("VHS reads \\&.tape files")
    end
  end
end
