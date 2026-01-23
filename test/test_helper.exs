# Exclude E2E tests from regular test runs by default.
# Run E2E tests with: GALLFORMERS_E2E=1 mix test --include e2e
ExUnit.start(exclude: [:e2e])
Ecto.Adapters.SQL.Sandbox.mode(Gallformers.Repo, :manual)
