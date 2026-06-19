defmodule QuoteAssistWeb.CoreComponentsTest do
  @moduledoc """
  Unit tests for shared UI components. `error_modal/1` is the SweetAlert-style dialog
  that error flashes (login failures, etc.) render as — info/success keep the toast.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias QuoteAssistWeb.CoreComponents

  @endpoint QuoteAssistWeb.Endpoint

  describe "error_modal/1" do
    test "renders an error flash as a centered modal dialog" do
      html =
        render_component(&CoreComponents.error_modal/1,
          flash: %{"error" => "Invalid email or password"}
        )

      assert html =~ "mtb-modal-backdrop"
      assert html =~ "Something went wrong"
      assert html =~ "Invalid email or password"
      # The acknowledge action clears the :error flash.
      assert html =~ "lv:clear-flash"
    end

    test "renders nothing when there is no error flash" do
      html = render_component(&CoreComponents.error_modal/1, flash: %{"info" => "Saved"})

      refute html =~ "mtb-modal-backdrop"
    end
  end
end
