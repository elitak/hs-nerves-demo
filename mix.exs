defmodule HsNervesDemo.MixProject do
  use Mix.Project

  @app :hs_nerves_demo
  @version "0.1.0"
  @all_targets [:bbb]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.14",
      archives: [nerves_bootstrap: "~> 1.11"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_target: [run: :host, test: :host]
    ]
  end

  def application do
    [
      mod: {HsNervesDemo.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp deps do
    [
      # Nerves core
      {:nerves, "~> 1.10", runtime: false},
      {:shoehorn, "~> 0.9.1"},
      {:ring_logger, "~> 0.10.0"},
      {:toolshed, "~> 0.3.0"},

      # Nerves runtime (host + target)
      {:nerves_runtime, "~> 0.13.0"},

      # Networking / SSH console (target only)
      {:nerves_pack, "~> 0.7.0", targets: @all_targets},

      # BeagleBone Black system image (target only)
      {:nerves_system_bbb, "~> 2.18", runtime: false, targets: :bbb},

      # GPIO LED control (target only)
      {:circuits_gpio, "~> 1.0", targets: @all_targets}
    ]
  end

  def release do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod
    ]
  end
end
