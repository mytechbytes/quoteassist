defmodule QuoteAssistWeb.ErrorsTest do
  @moduledoc """
  The authorization exceptions (R6-errors) carry the `plug_status` that Phoenix's
  error handling reads to render the matching branded page.
  """
  use ExUnit.Case, async: true

  alias QuoteAssistWeb.Errors.{UnauthenticatedError, UnauthorizedError}

  test "UnauthorizedError maps to a 403" do
    assert %UnauthorizedError{}.plug_status == 403
    assert Plug.Exception.status(%UnauthorizedError{}) == 403
  end

  test "UnauthenticatedError maps to a 401" do
    assert %UnauthenticatedError{}.plug_status == 401
    assert Plug.Exception.status(%UnauthenticatedError{}) == 401
  end
end
