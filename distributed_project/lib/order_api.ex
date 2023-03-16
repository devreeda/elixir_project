defmodule ImtOrder.API do
  use API.Exceptions
  use Plug.Router
  # plug Plug.Logger
  plug(:match)
  plug(:dispatch)

  get "/aggregate-stats/:product" do
    stats = StatsToDb.get(product)

    res =
      stats
      |> Enum.reduce(%{ca: 0, total_qty: 0}, fn {sold_qty, price}, acc ->
        %{acc | ca: acc.ca + sold_qty * price, total_qty: acc.total_qty + sold_qty}
      end)

    res = Map.put(res, :mean_price, res.ca / if(res.total_qty == 0, do: 1, else: res.total_qty))

    conn |> send_resp(200, Poison.encode!(res)) |> halt()
  end

  put "/stocks" do
    require Logger
    {:ok, bin, conn} = read_body(conn, length: 100_000_000)

    for line <- String.split(bin, "\n") do
      case String.split(line, ",") do
        [_, _, _] = l ->
          [prod_id, store_id, quantity] = Enum.map(l, &String.to_integer/1)

          MicroDb.HashTable.put("stocks", {store_id, prod_id}, quantity)

        _ ->
          :ignore_line
      end
    end

    conn |> send_resp(200, "") |> halt()
  end

  post "/order" do
    require Logger

    {:ok, bin, conn} = read_body(conn)
    order = Poison.decode!(bin)

    case Order.Supervisor.start_server(order["id"]) do
      {:ok, pid} ->
        :ok = GenServer.call(pid, {:new, order}, 20_000)
        conn |> send_resp(200, "") |> halt()

      err ->
        Logger.error("[Create] Error #{inspect(err)}")
        conn |> send_resp(500, "") |> halt()
    end
  end

  # payment arrived, get order and process package delivery !
  post "/order/:orderid/payment-callback" do
    require Logger

    {:ok, bin, conn} = read_body(conn)
    %{"transaction_id" => transaction_id} = Poison.decode!(bin)

    {:ok, pid} = Order.Supervisor.start_server(orderid)

    case GenServer.call(pid, {:payment, transaction_id}, 20_000) do
      {:ok, _} ->
        conn |> send_resp(200, "") |> halt()

      err ->
        Logger.error("[Payment] Error #{inspect(err)}")
        conn |> send_resp(500, "") |> halt()
    end
  end
end
