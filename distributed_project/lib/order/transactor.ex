defmodule Order.Transactor do
  use GenServer, restart: :transient

  def start_link(order_id) do
    GenServer.start_link(__MODULE__, order_id, name: :"#{order_id}_transactor")
  end

  def init(order_id) do
    {:ok, %{order_id: order_id, step: :init}}
  end

  def handle_call({:new, order}, _from, state) do
    selected_store =
      Enum.find(1..200, fn store_id ->
        Enum.all?(order["products"], fn %{"id" => prod_id, "quantity" => q} ->
          case MicroDb.HashTable.get("stocks", {store_id, prod_id}) do
            nil -> false
            store_q when store_q >= q -> true
            _ -> false
          end
        end)
      end)

    order = Map.put(order, "store_id", selected_store)

    case make_new_order_request(order) do
      {:ok, _} ->
        MicroDb.HashTable.put("orders", order["id"], order)

      _ ->
        IO.inspect("Error while making new order request", label: "[ERROR]")
    end

    {:reply, :ok, %{state | step: :new}}
  end

  def handle_call({:payment, transaction_id}, _from, state) do
    order_id = state.order_id

    case MicroDb.HashTable.get("orders", order_id) do
      nil ->
        {:stop, :normal, :error, order_id}

      order ->
        order = Map.put(order, "transaction_id", transaction_id)

        case retry_payment(order, order_id) do
          {:ok, _} ->
            MicroDb.HashTable.put("orders", order_id, order)

            {:stop, :normal, {:ok, order_id}, order_id}

          {:error, _} ->
            {:stop, :normal, {:error, order_id}, order_id}
        end
    end
  end

  def retry_payment(order, id, try \\ 0)
  def retry_payment(_, _, 3), do: {:error, :to_many_tries}

  def retry_payment(order, id, try) do
    case make_process_delivery_request(order) do
      {:ok, response} ->
        {info, _, _} = response
        {_, status_code, _} = info

        if status_code == 200 do
          MicroDb.HashTable.put("orders", id, order)
          {:ok, order}
        else
          retry_payment(order, id, try + 1)
        end

      _ ->
        retry_payment(order, id, try + 1)
    end
  end

  def make_new_order_request(order) do
    :httpc.request(
      :post,
      {'http://localhost:9091/order/new', [], 'application/json', Poison.encode!(order)},
      [],
      []
    )
  end

  def make_process_delivery_request(order) do
    :httpc.request(
      :post,
      {'http://localhost:9091/order/process_delivery', [], 'application/json',
       Poison.encode!(order)},
      [],
      []
    )
  end

  def terminate(_reason, _state) do
  end
end
