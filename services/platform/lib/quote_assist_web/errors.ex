defmodule QuoteAssistWeb.Errors do
  @moduledoc """
  Authorization exceptions that map to branded error pages (R6-errors).

  Each carries a `plug_status`, so raising it anywhere in the request lifecycle —
  a controller action, a plug, or a LiveView `mount`/event — lets Phoenix's error
  handling render the matching `QuoteAssistWeb.ErrorHTML` page (a 403/401), rather
  than surfacing a 500 crash or a silent redirect. This is the "raise → branded
  page" path the permission gates use (owner-only routes, missing `*:` permissions);
  the tenant guards land in R7-rbac and reuse these.
  """

  defmodule UnauthorizedError do
    @moduledoc """
    Raised when an *authenticated* actor lacks permission for an action (e.g. a member
    hitting an owner-only route). Renders the branded 403 page.
    """
    defexception message: "You don't have access to this.", plug_status: 403
  end

  defmodule UnauthenticatedError do
    @moduledoc """
    Raised when an action requires authentication and none is present, in a context
    where a redirect to login isn't appropriate. Renders the branded 401 page.
    (Most unauthenticated requests are instead redirected to the host-correct login by
    `UserAuth` / `AdminAuth`.)
    """
    defexception message: "You must sign in to continue.", plug_status: 401
  end
end
