defmodule OrderTransactor do
  use GenServer

  def child_spec(order_id) do
    %{id: "#{order_id}_transactor", start: {__MODULE__, :start_link, [order_id]}}
  end

  def find_remote_node(order_id) do
    # Ask all nodes if they got a process for this order_id. Stop at first good response
    Enum.find_value([Node.self() | Node.list()], fn node ->
      case :rpc.call(node, Registry, :lookup, [Order.Registry, order_id]) do
        [] -> nil
        [{pid, _}]=res ->
          IO.puts("Got #{inspect res} for #{inspect order_id}")
          {:ok, {node, pid}}
      end
    end)
  end

  def spawn_on_remote_node(order_id) do
    # Spawn on a random node
    random_node = Enum.random([Node.self | Node.list])
    case DynamicSupervisor.start_child({OrderSupervisor, random_node}, {__MODULE__, order_id}) do
      {:ok, pid} ->
        IO.puts("Spawning process for #{order_id} on #{random_node}")
        {:ok, {random_node, pid}}
      err -> err
    end
  end

  def checkout(order_id) do
    case find_remote_node(order_id) do
      nil -> spawn_on_remote_node(order_id)
      res -> res
    end
  end

  def start_link(order_id) do
    case GenServer.start_link(__MODULE__, order_id, name: {:via, Registry, {Order.Registry, order_id}}) do
      {:ok, p} -> {:ok, p}
      {:error, {:already_started, p}} -> {:ok, p}
      err -> err
    end
  end

  def init(order_id) do
    order = MicroDb.HashTable.get("orders", order_id) || nil
    {:ok, %{id: order_id, order: order}}
  end

  def handle_call({:new, order}, _from, %{id: order_id, order: nil}) do
    selected_store = Enum.find(1..200, fn store_id->
      Enum.all?(order["products"],fn %{"id"=>prod_id,"quantity"=>q}->
        case MicroDb.HashTable.get("stocks",{store_id,prod_id}) do
          nil-> false
          store_q when store_q >= q-> true
          _-> false
        end
      end)
    end)
    order = Map.put(order,"store_id",selected_store)
    :httpc.request(:post,{'http://localhost:9091/order/new',[],'application/json',Poison.encode!(order)},[],[])
    MicroDb.HashTable.put("orders",order["id"],order)
    {:reply, :ok, %{id: order["id"], order: order}}
  end

  def handle_call({:payment, %{"transaction_id" => transaction_id}}, _from ,%{id: id, order: order}) when not is_nil(order) do
    # Retry X time the request to post
    retry_fct = fn
      0, _ -> :error
      count, retry_fct ->
        case :httpc.request(:post,{'http://localhost:9091/order/process_delivery',[],'application/json',Poison.encode!(order)},[],[]) do
          {:ok,{{_,code,_},_,_}} when code < 400-> :ok
          _-> retry_fct.(count - 1, retry_fct)
        end
    end
    :ok = retry_fct.(3, retry_fct)
    order = Map.put(order,"transaction_id",transaction_id)
    MicroDb.HashTable.put("orders",order["id"],order)
    {:stop, :normal, {:ok, order}, %{id: id, order: order}}
  end
end
