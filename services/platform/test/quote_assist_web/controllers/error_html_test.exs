defmodule QuoteAssistWeb.ErrorHTMLTest do
  use QuoteAssistWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing the error view directly.
  import Phoenix.Template, only: [render_to_string: 4]

  defp render(status), do: render_to_string(QuoteAssistWeb.ErrorHTML, status, "html", %{})

  test "renders a branded 401 page" do
    html = render("401")
    assert html =~ "401"
    assert html =~ "UNAUTHORIZED"
    assert html =~ "session has ended"
  end

  test "renders a branded 403 page" do
    html = render("403")
    assert html =~ "403"
    assert html =~ "FORBIDDEN"
    assert html =~ "restricted"
  end

  test "renders a branded 404 page" do
    html = render("404")
    assert html =~ "404"
    assert html =~ "NOT_FOUND"
  end

  test "renders a branded 500 page" do
    html = render("500")
    assert html =~ "500"
    assert html =~ "INTERNAL_ERROR"
  end

  test "renders a branded 503 page" do
    html = render("503")
    assert html =~ "503"
    assert html =~ "SERVICE_UNAVAILABLE"
  end

  test "each branded page is a complete document wired to the design system stylesheet" do
    html = render("404")
    assert html =~ "<!DOCTYPE html>"
    assert html =~ "/assets/css/app.css"
    assert html =~ "QuoteAssist"
  end

  test "falls back to the plain status message for an unhandled status" do
    assert render("406") == "Not Acceptable"
  end
end
