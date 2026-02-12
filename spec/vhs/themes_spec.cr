require "../spec_helper"

module Vhs
  describe "themes" do
    describe ".sorted_theme_names" do
      it "loads all themes" do
        themes = Vhs.sorted_theme_names
        # Go test expects 348 themes
        themes.size.should eq(348)
      end
    end

    describe ".find_theme" do
      it "exact match" do
        theme = Vhs.get_theme("Catppuccin Latte")
        theme.name.should eq("Catppuccin Latte")
      end

      it "match found with suggestion" do
        ex = expect_raises(Vhs::ThemeNotFoundError) do
          Vhs.get_theme("caTppuccin ltt")
        end
        ex.suggestions.should eq(["Catppuccin Latte"])
      end

      it "no match found" do
        ex = expect_raises(Vhs::ThemeNotFoundError) do
          Vhs.get_theme("stArf1sh")
        end
        ex.suggestions.should be_empty
      end

      it "single char" do
        ex = expect_raises(Vhs::ThemeNotFoundError) do
          Vhs.get_theme("s")
        end
        ex.suggestions.should be_empty
      end

      it "empty string" do
        # Empty string returns DEFAULT_THEME (tested in command_spec)
        theme = Vhs.get_theme("")
        theme.should eq(Vhs::DEFAULT_THEME)
      end
    end
  end
end
