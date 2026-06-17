# Enforces a minimum total line-coverage threshold from the ExCoveralls report.
#
#   mix coveralls.json                         # writes cover/excoveralls.json
#   mix run --no-start ci/check_coverage.exs 70
#
# Exits non-zero if total covered/relevant line coverage is below the threshold
# (default 70). Files excluded via coveralls.json `skip_files` never appear in the
# report, so they don't affect this calculation.

threshold =
  case System.argv() do
    [arg | _] ->
      case Float.parse(arg) do
        {value, _} -> value
        :error -> 70.0
      end

    [] ->
      70.0
  end

report = "cover/excoveralls.json"

unless File.exists?(report) do
  IO.puts(:stderr, "coverage report not found at #{report} (run `mix coveralls.json` first)")
  System.halt(1)
end

%{"source_files" => files} = report |> File.read!() |> Jason.decode!()

{relevant, covered} =
  Enum.reduce(files, {0, 0}, fn %{"coverage" => lines}, acc ->
    Enum.reduce(lines, acc, fn
      nil, {rel, cov} -> {rel, cov}
      hits, {rel, cov} when is_integer(hits) and hits > 0 -> {rel + 1, cov + 1}
      _hits, {rel, cov} -> {rel + 1, cov}
    end)
  end)

percentage = if relevant == 0, do: 100.0, else: covered / relevant * 100.0

IO.puts(
  "Total coverage: #{:erlang.float_to_binary(percentage, decimals: 2)}% " <>
    "(#{covered}/#{relevant} relevant lines) — threshold " <>
    "#{:erlang.float_to_binary(threshold, decimals: 2)}%"
)

# Small epsilon so exactly-at-threshold passes despite float rounding.
if percentage + 1.0e-9 < threshold do
  IO.puts(:stderr, "FAILED: coverage below threshold")
  System.halt(1)
else
  IO.puts("OK: coverage meets threshold")
end
