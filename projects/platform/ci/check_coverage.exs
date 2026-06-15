# Fails the build (exit 1) if total line coverage in cover/excoveralls.json is
# below the threshold passed as the first CLI arg. Run *after* `mix coveralls.json`:
#
#     mix run --no-start ci/check_coverage.exs 70
#
# Lives here (not a Mix task) so the Jenkins "Tests & Coverage" stage can gate on
# a parameterized threshold without adding a Python dependency. Skipped files
# (see coveralls.json) are already absent from the report.

threshold =
  case System.argv() do
    [arg | _] ->
      case Float.parse(arg) do
        {value, _} -> value
        :error -> 0.0
      end

    [] ->
      0.0
  end

report = "cover/excoveralls.json"

unless File.exists?(report) do
  IO.puts(:stderr, "coverage report #{report} not found — run `mix coveralls.json` first")
  System.halt(1)
end

%{"source_files" => files} = report |> File.read!() |> Jason.decode!()

{relevant, covered} =
  Enum.reduce(files, {0, 0}, fn %{"coverage" => lines}, acc ->
    Enum.reduce(lines, acc, fn
      nil, acc -> acc
      hits, {rel, cov} when hits > 0 -> {rel + 1, cov + 1}
      _hits, {rel, cov} -> {rel + 1, cov}
    end)
  end)

percent = if relevant > 0, do: 100.0 * covered / relevant, else: 100.0

IO.puts(
  "Coverage: #{:erlang.float_to_binary(percent, decimals: 1)}% " <>
    "(#{covered}/#{relevant} lines) — threshold #{threshold}%"
)

if percent < threshold do
  IO.puts(:stderr, "FAILED: coverage below threshold")
  System.halt(1)
end
