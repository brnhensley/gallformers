import Config

config :gallformers, env: :test

# Configure your database
# Use a schema-only test database (no production data)
config :gallformers, Gallformers.Repo,
  database: Path.expand("../priv/gallformers_test.sqlite", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox,
  # Use :delete instead of :wal to prevent the main DB file from being modified
  # when WAL checkpoints occur (even with sandbox rollbacks)
  journal_mode: :delete,
  busy_timeout: 5000

# Server is disabled by default for fast unit tests.
# E2E tests enable the server via GALLFORMERS_E2E=1 environment variable.
config :gallformers, GallformersWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "QXMJq8FP0hqnpEVCf4NmW0l3LLZMBoncyOmBqm2OrxKFnFuPBa7iIlHN6+5sD8dE",
  server: System.get_env("GALLFORMERS_E2E") == "1"

# Wallaby E2E test configuration (only used when GALLFORMERS_E2E=1)
config :wallaby,
  otp_app: :gallformers,
  driver: Wallaby.Chrome,
  screenshot_dir: "test/screenshots",
  screenshot_on_failure: true,
  chromedriver: [
    headless: System.get_env("E2E_HEADED") != "1"
  ]

# In test we don't send emails
config :gallformers, Gallformers.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
