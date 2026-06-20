defmodule QuoteAssist.SlugTest do
  use ExUnit.Case, async: true

  alias QuoteAssist.Slug

  describe "slugify/1" do
    test "lowercases, hyphenates runs of non-alphanumerics, and trims" do
      assert Slug.slugify("Acme Travel") == "acme-travel"
      assert Slug.slugify("  Globex, Inc.  ") == "globex-inc"
      assert Slug.slugify("Already-good") == "already-good"
      assert Slug.slugify("Multiple   spaces & symbols!!") == "multiple-spaces-symbols"
      assert Slug.slugify("") == ""
      assert Slug.slugify(nil) == ""
    end
  end

  describe "auto/4" do
    test "derives the slug from the name while auto-tracking" do
      assert {"acme", true, "acme"} = Slug.auto("Acme", "", "", true)
      # next keystroke: the form re-submits our last auto value, so keep deriving
      assert {"acme-travel", true, "acme-travel"} = Slug.auto("Acme Travel", "acme", "acme", true)
    end

    test "stops tracking once the user edits the slug" do
      # the submitted slug differs from our last auto value → user typed a custom one
      assert {"custom", false, "acme"} = Slug.auto("Acme Travel", "custom", "acme", true)
      # and once off, it stays off and keeps the user's value
      assert {"custom", false, "acme"} = Slug.auto("Whatever", "custom", "acme", false)
    end
  end
end
