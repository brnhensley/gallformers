import Config

config :gallformers, env: :test

# Run async tasks synchronously to avoid sandbox connection issues
config :gallformers, async_tasks: false

# Configure your database
# Use a schema-only test database (no production data)
config :gallformers, Gallformers.Repo,
  database: "gallformers_test",
  username: System.get_env("PGUSER", System.get_env("USER")),
  password: System.get_env("PGPASSWORD"),
  hostname: System.get_env("PGHOST", "localhost"),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# Use stub instead of real WCVP database for WCVP lookups in most tests
config :gallformers, wcvp_lookup: Gallformers.Wcvp.LookupStub

# No `pool: Ecto.Adapters.SQL.Sandbox` — WCVP is read-only reference data.
# Fixture data is loaded once by `make test-db` (via wcvp_test_setup.sql).
# Tests read concurrently without write isolation.
config :gallformers, Gallformers.Repo.WCVP,
  database: "wcvp_test",
  username: System.get_env("PGUSER", System.get_env("USER")),
  password: System.get_env("PGPASSWORD"),
  hostname: System.get_env("PGHOST", "localhost")

# Server is disabled by default for fast unit tests.
# E2E tests enable the server via GALLFORMERS_E2E=1 environment variable (in runtime.exs).
config :gallformers, GallformersWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "QXMJq8FP0hqnpEVCf4NmW0l3LLZMBoncyOmBqm2OrxKFnFuPBa7iIlHN6+5sD8dE"

# Wallaby E2E test configuration (only used when GALLFORMERS_E2E=1)
config :wallaby,
  otp_app: :gallformers,
  base_url: "http://localhost:4002",
  driver: Wallaby.Chrome,
  screenshot_dir: "test/screenshots",
  screenshot_on_failure: true,
  chromedriver: [
    headless: System.get_env("E2E_HEADED") != "1",
    capabilities: %{
      chromeOptions: %{
        args: [
          "--no-sandbox",
          "window-size=1280,800",
          "--fullscreen",
          "--disable-features=MacAppCodeSignClone",
          "--enable-unsafe-swiftshader",
          "--user-agent=Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36"
        ]
      }
    }
  ]

# In test we don't send emails
config :gallformers, Gallformers.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Disable real S3 calls in tests - functions return mock/empty data instead
config :gallformers, s3_enabled: false

# Disable request logger in tests (no /data/logs in test env)
config :gallformers, request_logger_enabled: false

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
