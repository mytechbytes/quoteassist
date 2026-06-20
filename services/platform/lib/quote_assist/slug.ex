defmodule QuoteAssist.Slug do
  @moduledoc """
  Slug helpers for create forms. `slugify/1` derives a URL-safe slug from a name;
  `auto/4` is the live "auto-fill until the user edits it" rule a create form uses so the
  slug tracks the name field until the user types a custom slug, after which their value
  is kept.
  """

  @doc "A lowercase, hyphenated slug derived from `name` (runs of non-alphanumerics → `-`)."
  def slugify(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  def slugify(_name), do: ""

  @doc """
  Live auto-fill rule for a create form. Given the current `name`, the `current` slug the
  form submitted, the `last` slug we auto-filled, and whether we're still `auto?`-tracking
  the name, returns `{slug, auto?, last}`. While auto-tracking and the submitted slug still
  matches our last auto value, the slug is re-derived from the name; once the user edits the
  slug away from that, auto-fill switches off and their value is kept.
  """
  def auto(name, current, last, true) do
    if current == last do
      derived = slugify(name)
      {derived, true, derived}
    else
      {current, false, last}
    end
  end

  def auto(_name, current, last, false), do: {current, false, last}
end
