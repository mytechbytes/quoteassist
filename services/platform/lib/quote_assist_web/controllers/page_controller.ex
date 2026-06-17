defmodule QuoteAssistWeb.PageController do
  use QuoteAssistWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
