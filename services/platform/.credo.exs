%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "config/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/priv/"]
      },
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: %{
        # Disabled for the QuoteAssist platform:
        # - MaxLineLength: the design system uses long inline `style` strings with
        #   color-mix(...) tokens in HEEx components.
        # - ModuleDoc: this is an application (controllers/LiveViews), not a library;
        #   @moduledoc on every web module is noise.
        disabled: [
          {Credo.Check.Readability.MaxLineLength, []},
          {Credo.Check.Readability.ModuleDoc, []}
        ]
      }
    }
  ]
}
