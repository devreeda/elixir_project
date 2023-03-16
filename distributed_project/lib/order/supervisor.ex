defmodule Order.Supervisor do
  use DynamicSupervisor
  require Integer
  require Logger

  def start_server(order_id) do
    <<key_hashed::size(160)-integer>> = :crypto.hash(:sha, :erlang.term_to_binary(order_id))

    nodes = Application.get_env(:imt_order, :transactors)

    virtual_node_selected = rem(key_hashed, length(nodes))

    make_call(virtual_node_selected, order_id)
  end

  def make_call(index, order_id) do
    nodes = Application.get_env(:imt_order, :transactors)

    handler_node = nodes |> Enum.at(index)

    Logger.info(
      "[#{Node.self()}] [Order.Supervisor] Order #{order_id} will be handled by #{inspect(handler_node)}"
    )

    case :rpc.call(handler_node, Order.Supervisor, :start_child, [order_id]) do
      {:ok, pid} ->
        {:ok, pid}

      _ ->
        if(index < length(nodes) - 1) do
          make_call(index + 1, order_id)
        else
          make_call(0, order_id)
        end
    end
  end

  def start_link(init) do
    DynamicSupervisor.start_link(__MODULE__, init, name: __MODULE__)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(order_id) do
    case DynamicSupervisor.start_child(__MODULE__, {Order.Transactor, order_id}) do
      {:ok, p} ->
        {:ok, p}

      {:error, {:already_started, p}} ->
        {:ok, p}

      err ->
        err
    end
  end
end
