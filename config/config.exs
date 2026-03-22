# This file is responsible for configuring your application and its
# dependencies.  See `Mix.Project` configuration in `mix.exs`.
import Config

# Shoehorn boots the application even if a dependency fails to start.
config :shoehorn, init: [:nerves_runtime, :nerves_pack]

# Use Ringlogger so logs are accessible via the IEx console.
config :logger, backends: [RingLogger]

if Mix.target() == :host do
  import_config "host.exs"
else
  import_config "target.exs"
end
