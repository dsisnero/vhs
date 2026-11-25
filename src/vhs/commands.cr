require "./assets"
require "./lexer"
require "./parser"

module Vhs
  # TAPE_EXTENSION is the tape file suffix (upstream main.go's `extension`).
  TAPE_EXTENSION = ".tape"

  # The baked `examples/demo.tape`, upstream's embedded demoTape.
  @@demo_template : String? = nil

  # demo_tape returns the scaffolded tape `vhs new` writes: the embedded demo tape
  # with its output redirected to `<name>.gif`, which is upstream's
  # `bytes.Replace(demoTape, "examples/demo.gif", name+".gif", 1)`.
  def self.demo_tape(name : String) : String
    template = @@demo_template ||= Assets.get("demo.tape").read
    template.sub("examples/demo.gif", "#{name}.gif")
  end

  # new_tape writes the demo tape to `<name>.tape` and returns that file name,
  # porting main.go's `new` command. An existing file is truncated, as with
  # os.Create; a `.tape` suffix on the argument is not doubled.
  def self.new_tape(name : String, dir : String? = nil) : String
    base = name.rchop?(TAPE_EXTENSION) || name
    file = dir ? File.join(dir, base + TAPE_EXTENSION) : base + TAPE_EXTENSION
    File.write(file, demo_tape(base))
    file
  end

  # theme_list renders `vhs themes`: every theme name, one per line, or a markdown
  # list. Upstream logs it, so the CLI writes it to stderr.
  def self.theme_list(markdown : Bool = false) : String
    prefix, suffix = markdown ? {"* `", "`"} : {"", ""}

    listing = IO::Memory.new
    listing << "# Themes\n\n" if markdown
    sorted_theme_names.each do |theme|
      listing << prefix << theme << suffix << '\n'
    end
    listing.to_s
  end

  # validate_tape parses `input` without running it and returns the syntax errors,
  # which is what main.go's `validate` command reports.
  def self.validate_tape(input : String) : Array(Parser::ParserError)
    parser = Parser.new(Lexer.new(input))
    parser.parse
    parser.errors
  end
end
