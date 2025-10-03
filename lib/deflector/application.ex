defmodule Deflector.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Deflector.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Deflector.DynamicSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Deflector.Supervisor]
    Supervisor.start_link(children, opts)
  end
end