defmodule ImtOrder.App do
  use Supervisor
  def start_link(_) do

    [node_name | host_name] = String.split(Atom.to_string(Node.self), "@")

    if node_name == "sim" do
      Supervisor.start_link([
        ImtOrder.StatsToDb,
        {Plug.Cowboy, scheme: :http, plug: ImtOrder.API, options: [port: 9090]},
        {Registry, keys: :unique, name: Order.Registry},
        {DynamicSupervisor, name: OrderSupervisor, strategy: :one_for_one},
      ], strategy: :one_for_one)
    else
      Supervisor.start_link([
        {Registry, keys: :unique, name: Order.Registry},
        {DynamicSupervisor, name: OrderSupervisor, strategy: :one_for_one},
      ], strategy: :one_for_one)
    end
  end
end
