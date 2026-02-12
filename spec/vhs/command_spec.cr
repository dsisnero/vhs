require "../spec_helper"

module Vhs
  describe "command functions" do
    describe ".command_funcs" do
      it "has the correct number of command functions" do
        # Count command functions in evaluator
        command_funcs_count = Vhs.command_funcs.size
        # The Go test expects 29 command functions
        command_funcs_count.should eq(29)
      end
    end

    describe ".settings" do
      it "has the correct number of setting functions" do
        # Count setting functions in evaluator
        settings_count = Vhs.settings.size
        # The Go Settings map has 21 entries (check from command.go)
        settings_count.should eq(21)
      end
    end
  end

  describe "Set Theme" do
    describe "get_theme" do
      it "returns default theme for empty string" do
        theme = Vhs.get_theme("  ")
        theme.should eq(Vhs::DEFAULT_THEME)
      end

      it "returns named theme" do
        theme = Vhs.get_theme("Catppuccin Latte")
        theme.should_not eq(Vhs::DEFAULT_THEME)
        theme.name.should eq("Catppuccin Latte")
      end

      it "parses JSON theme" do
        theme = Vhs.get_theme(%({"background": "#29283b"}))
        theme.should_not eq(Vhs::DEFAULT_THEME)
        theme.background.should eq("#29283b")
      end

      it "provides suggestion for misspelled theme" do
        # Expect error with suggestion
        expect_raises(Vhs::ThemeNotFoundError, "invalid `Set Theme \"cattppuccin latt\"`: did you mean \"Catppuccin Latte\"") do
          Vhs.get_theme("cattppuccin latt")
        end
      end

      it "returns default theme and error for invalid JSON" do
        expect_raises(Vhs::InvalidThemeError, /invalid.*Set Theme/) do
          Vhs.get_theme(%({"background))
        end
      end

      it "returns default theme and error for unknown theme" do
        expect_raises(Vhs::ThemeNotFoundError, /invalid.*Set Theme.*foobar/) do
          Vhs.get_theme("foobar")
        end
      end
    end
  end
end
