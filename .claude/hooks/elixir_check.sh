#!/bin/bash

# Exit immediately if any command in a pipeline fails
set -o pipefail

echo "=== Running Automated Elixir Quality Checks ==="

# 1. Run format check
echo "Checking code formatting..."
if ! mix format --check-formatted; then
	echo "❌ Formatting checks failed! Run 'mix format' or fix file styling." >&2
	exit 2
fi

# 2. Run compile with warnings-as-errors
echo "Checking compile with warnings-as-errors..."
if ! mix compile --warnings-as-errors; then
	echo "❌ compile with warnings as errors failed! Claude, please review the warnings above and fix the logic." >&2
	exit 2
fi

# 3. Run Credo Check
echo "Running mix credo --strict..."
if ! mix credo --strict; then
	echo "❌ Credo checks failed! Claude, please review the style violations above and fix the logic." >&2
	exit 2 
fi

# 4. Run Test Suite
echo "Running mix test..."
if ! mix test; then
	echo "❌ Elixir tests failed! Claude, please review the failing test cases above and fix the logic." >&2
	exit 2 
fi

# 5. Check Coveralls and Run Custom Coverage Script
echo "Generating coveralls.json and running threshold script..."

# Separate the commands to isolate exactly which step failed
if ! mix coveralls.json; then
	echo "❌ Coveralls JSON generation failed!" >&2
	exit 2
fi

if ! mix run --no-start ci/check_coverage.exs; then
	echo "❌ Coveralls threshold script check failed! Please verify metrics in ci/check_coverage.exs." >&2
	exit 2
fi

echo "✅ All Elixir code gates passed!"
exit 0
