module Vhs
  # The man page command, ported from upstream man.go (`vhs manual`, aliased as
  # `vhs man`, hidden).
  #
  # Upstream renders either a markdown manual (when stdout is a terminal, through
  # glamour) or a roff man page (when piped, built from the cobra command tree by
  # mango-cobra). The port has neither glamour nor cobra, so the markdown manual
  # is printed unstyled and the roff page is written to the same shape mango
  # produces — `spec/fixtures/vhs.1` is upstream's own output, pinned.
  module Man
    extend self

    # The root command's short description (upstream rootCmd.Short).
    SUMMARY = "Run a given tape file and generates its outputs."

    # special_char delimits the symbols that become code in markdown and are
    # dropped in roff (upstream's `specialChar`).
    SPECIAL_CHAR = "%"

    # DESCRIPTION is upstream's manDescription.
    DESCRIPTION = <<-'MD'
VHS lets you write terminal GIFs as code.
VHS reads .tape files and renders GIFs (videos).
A tape file is a script made up of commands describing what actions to perform in the render.

The following is a list of all possible commands in VHS:

* %Output% <path>.(gif|webm|mp4)
* %Require% <program>
* %Set% <setting> <value>
* %Sleep% <time>
* %Type% "<string>"
* %Ctrl% [+Alt][+Shift]+<char>
* %Backspace% [repeat]
* %Delete% [repeat]
* %Insert% [repeat]
* %Down% [repeat]
* %Enter% [repeat]
* %Left% [repeat]
* %Right% [repeat]
* %Tab% [repeat]
* %Up% [repeat]
* %PageUp% [repeat]
* %PageDown% [repeat]
* %Hide%
* %Show%
* %Wait%[+Screen][@<timeout>] /<regexp>/
* %Escape%
* %Alt%+<key>
* %Space% [repeat]
* %Source% <path>.tape
* %Screenshot% <path>.png
* %Copy% "<string>"
* %Paste%

MD

    # OUTPUT is upstream's manOutput.
    OUTPUT = <<-'MD'
The Output command instructs VHS where to save the output of the recording.
File names with the extension %.gif%, %.webm%, %.mp4% will have the respective file types.

MD

    # SETTINGS is upstream's manSettings.
    SETTINGS = <<-'MD'
The Set command allows VHS to adjust settings in the terminal, such as fonts, dimensions, and themes.

The following is a list of all possible setting commands in VHS:

* Set %Shell% <string>
* Set %FontSize% <number>
* Set %FontFamily% <string>
* Set %Height% <number>
* Set %Width% <number>
* Set %LetterSpacing% <float>
* Set %LineHeight% <float>
* Set %TypingSpeed% <time>
* Set %Theme% <json|string>
* Set %Padding% <number>
* Set %Framerate% <number>
* Set %PlaybackSpeed% <float>
* Set %WaitTimeout% <time>
* Set %WaitPattern% <regexp>

MD

    # BUGS and AUTHOR are upstream's manBugs and manAuthor; they carry no
    # trailing newline, which is why roff gives them no trailing .PP.
    BUGS   = "See GitHub Issues: <https://github.com/charmbracelet/vhs/issues>"
    AUTHOR = "Charm <vt100@charm.sh>"

    # COPYRIGHT is upstream's copyright section body.
    COPYRIGHT = "(C) 2021-2022 Charmbracelet, Inc.\nReleased under MIT license."

    # Flag is one option line in the man page.
    struct Flag
      getter label : String
      getter summary : String

      def initialize(@label : String, @summary : String)
      end

      # from builds the `-s, --shell` form mango prints, or `--markdown`.
      def self.from(long : String, summary : String, short : String? = nil) : Flag
        new(short ? "-#{short}, --#{long}" : "--#{long}", summary)
      end
    end

    # Command is one entry in the man page's COMMANDS section.
    struct Command
      getter name : String
      getter usage : String
      getter summary : String
      getter flags : Array(Flag)

      def initialize(@name : String, @usage : String, @summary : String, @flags = [] of Flag)
      end
    end

    # ROOT_FLAGS are the root command's own flags, in the order mango prints them.
    ROOT_FLAGS = [
      Flag.from("output", "file name(s) of video output", "o"),
      Flag.from("publish", "publish your GIF to vhs.charm.sh and get a shareable URL", "p"),
      Flag.from("quiet", "quiet do not log messages. If publish flag is provided, it will log shareable URL", "q"),
    ]

    # COMMANDS is the ported subcommand set in mango's alphabetical order.
    # Upstream also lists cobra's generated `help` and the `serve` SSH server,
    # which this port does not have (see plans/parity.md).
    COMMANDS = [
      Command.new("new", "<name>", "Create a new tape file with example tape file contents and documentation"),
      Command.new("publish", "<gif>", "Publish your GIF to vhs.charm.sh and get a shareable URL"),
      Command.new("record", "", "Create a new tape file by recording your actions",
        [Flag.from("shell", "shell for recording", "s")]),
      Command.new("themes", "", "List all the available themes, one per line",
        [Flag.from("markdown", "output as markdown")]),
      Command.new("validate", "<file>...",
        "Validate a glob file path and parses all the files to ensure they are valid without running them."),
    ]

    # markdown_manual is upstream's markdownManual.
    def markdown_manual : String
      String.build do |manual|
        manual << "# MANUAL\n" << sanitize_markdown(DESCRIPTION)
        manual << "# OUTPUT\n" << sanitize_markdown(OUTPUT)
        manual << "# SETTING\n" << sanitize_markdown(SETTINGS)
        manual << "# BUGS\n" << BUGS
        manual << "\n# AUTHOR\n" << AUTHOR
      end
    end

    # man_page renders the roff page mango-cobra produces for the command tree.
    def man_page(date : String = Time.utc.to_s("%Y-%m-%d")) : String
      String.build do |roff|
        roff << %(.TH VHS 1 "#{date}" "vhs" "#{SUMMARY}"\n)
        roff << ".SH NAME\n" << "vhs - " << escape(SUMMARY) << '\n'
        roff << ".SH SYNOPSIS\n"
        roff << %(\\fBvhs\\fP [\\fIoptions\\&.\\&.\\&.\\fP] [\\fIargument\\&.\\&.\\&.\\fP]\n)
        roff << ".SH DESCRIPTION\n" << body(DESCRIPTION)
        roff << ".SH OPTIONS\n"
        flags(roff, ROOT_FLAGS)
        roff << ".SH COMMANDS\n"
        COMMANDS.each { |command| command_entry(roff, command) }
        roff << ".SH OUTPUT\n" << body(OUTPUT)
        roff << ".SH SETTINGS\n" << body(SETTINGS)
        roff << ".SH BUGS\n" << escape(BUGS) << '\n'
        roff << ".SH AUTHOR\n" << escape(AUTHOR) << '\n'
        roff << ".SH COPYRIGHT\n" << body(COPYRIGHT)
      end
    end

    # sanitize_markdown turns the % symbols into code spans (upstream
    # sanitizeMarkdown).
    def sanitize_markdown(text : String) : String
      text.gsub('<', "&lt;").gsub('>', "&gt;").gsub(SPECIAL_CHAR, "`")
    end

    # sanitize_special drops the % symbols for roff (upstream sanitizeSpecial).
    def sanitize_special(text : String) : String
      text.gsub(SPECIAL_CHAR, "")
    end

    # escape roff-escapes periods, which is the only escaping mango's document
    # writer applies to text: "vhs.charm.sh" becomes "vhs\\&.charm\\&.sh".
    private def escape(text : String) : String
      text.gsub('.', "\\&.")
    end

    # body renders a section body: every source line becomes a paragraph (mango
    # emits .PP after each newline it is given), a blank line is its own .PP, and
    # `* ` lines become a bullet list. A body with no trailing newline gets no
    # trailing .PP, which is why upstream's single-line sections end differently.
    private def body(text : String) : String
      lines = sanitize_special(text).split('\n', remove_empty: false)
      # Every chunk except the last is newline-terminated; a trailing newline
      # only adds the final empty chunk.
      last = lines.size - 1

      String.build do |roff|
        in_list = false
        lines.each_with_index do |line, index|
          bullet = line.lchop?("* ")
          closed = index >= last

          if bullet
            unless in_list
              roff << ".RS\n"
              in_list = true
            end
            roff << ".IP \\(bu 3\n" << escape(bullet) << '\n'
          elsif line.empty?
            roff << ".PP\n" unless closed
          else
            roff << escape(line) << '\n'
            roff << ".PP\n" unless closed
          end
        end
        roff << ".RE\n" if in_list
      end
    end

    # command_entry renders one COMMANDS entry, including its own OPTIONS block.
    private def command_entry(roff : String::Builder, command : Command) : Nil
      roff << ".TP\n" << "\\fB" << command.name << "\\fP"
      roff << ' ' << escape(command.usage) unless command.usage.empty?
      roff << '\n' << ".RS 4\n" << escape(command.summary) << '\n' << ".RE\n"
      return if command.flags.empty?

      roff << ".TP\n" << "\\fBOPTIONS\\fP\n" << ".RS 4\n"
      nested_flags(roff, command.flags)
      roff << ".RE\n"
    end

    private def flags(roff : String::Builder, flags : Array(Flag)) : Nil
      flags.each do |flag|
        roff << ".TP\n" << "\\fB" << flag.label << "\\fP\n" << escape(flag.summary) << '\n'
      end
    end

    # nested_flags has no .TP of its own: mango puts each flag's label and summary
    # inside the OPTIONS block without repeating the entry marker.
    private def nested_flags(roff : String::Builder, flags : Array(Flag)) : Nil
      flags.each do |flag|
        roff << "\\fB" << flag.label << "\\fP\n" << escape(flag.summary) << '\n'
      end
    end
  end
end
