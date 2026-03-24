defmodule Gallformers.Mailer do
  @moduledoc false
  use Boundary, deps: [], exports: :all
  use Swoosh.Mailer, otp_app: :gallformers
end
