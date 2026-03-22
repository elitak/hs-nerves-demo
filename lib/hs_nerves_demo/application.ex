defmodule HsNervesDemo.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # On the target, start Nerves.Runtime first so hardware services are ready
    # before the Blinker process opens the GPIO pin.
    runtime_children =
      if Application.get_env(:hs_nerves_demo, :stub_hardware, false) do
        []
      else
        [Nerves.Runtime]
      end

    children = runtime_children ++ [HsNervesDemo.Blinker]

    opts = [strategy: :one_for_one, name: HsNervesDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
