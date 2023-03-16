defmodule ImtOrder.App do
  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    port = Application.fetch_env!(:imt_order, :port)

    Logger.info("[#{Node.self()}] [ImtOrder.App] Starting on port #{port}")

    children = [
      {Plug.Cowboy, scheme: :http, plug: ImtOrder.API, options: [port: port]},
      %{id: Order.Supervisor, start: {Order.Supervisor, :start_link, [[]]}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
