# in this file : all module for backend simulation :
# generate stocks and stats, and receive orders

defmodule ImtSim.Back do
  use Supervisor

  @order_receiver_port 9091

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      ImtSim.Back.Stocks,
      ImtSim.Back.Stats,
      {Plug.Cowboy,
       scheme: :http, plug: ImtSim.Back.OrderReceiver, options: [port: @order_receiver_port]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule ImtSim.Back.Stocks do
  use GenServer

  # Generate file every 15 sec
  @timeout :timer.seconds(5)

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    {:ok, [], @timeout}
  end

  def handle_info(:timeout, []) do
    gen_stock_file()
    {:noreply, [], @timeout}
  end

  def gen_stock_file() do
    # generate stocks for 10 products in 200 stores : IDPROD,IDSTORE,QUANTITY
    nb_products = 10
    nb_stores = 200

    lines =
      Enum.flat_map(1..nb_products, fn product_id ->
        Enum.map(1..nb_stores, fn store_id ->
          # stock from 0 to 15, half of the time stock of 0 !
          "#{product_id},#{store_id},#{max(0, :rand.uniform(30) - 15)}\n"
        end)
      end)

    oms_stocks_api = 'http://localhost:9090/stocks'
    :httpc.request(:put, {oms_stocks_api, [], 'text/csv', IO.iodata_to_binary(lines)}, [], [])
  end
end

defmodule ImtSim.Back.Stats do
  use GenServer

  # Generate file every 10 sec
  @timeout :timer.seconds(10)

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    {:ok, [], @timeout}
  end

  def handle_info(:timeout, []) do
    gen_stat_file()
    {:noreply, [], @timeout}
  end

  def gen_stat_file() do
    # generate 10 product line : IDPROD,NBVENTE,PRIXVENTE
    nb_products = 10

    file =
      Enum.map(1..nb_products, fn product_id ->
        "#{product_id},#{:rand.uniform(30)},#{:rand.uniform(30)}\n"
      end)

    padded_ts = String.pad_leading("#{:erlang.system_time(:millisecond)}", 15, ["0"])
    file_name = "data/stat_#{padded_ts}.csv"
    File.write!(file_name, file)
    IO.puts("stat file #{file_name} generated")
  end
end

defmodule ImtSim.Back.OrderReceiver do
  use Plug.Router
  # plug Plug.Logger
  plug(:match)
  plug(:dispatch)

  post "/order/new" do
    # random duration between 2s and 4s with 0.25s step.
    # create_order_duration = :timer.seconds(2) + :rand.uniform(8) * 2
    create_order_duration = 0
    # simulate time requeste to create an order on order receiver
    Process.sleep(create_order_duration)

    conn
    |> send_resp(200, "")
    |> halt()
  end

  post "/order/process_delivery" do
    # 200ms
    process_delivery_duration = 200
    Process.sleep(process_delivery_duration)

    # fake a failure once in 15
    resp_code =
      case :rand.uniform(15) do
        # Failure
        1 -> 504
        # Success
        _ -> 200
      end

    conn
    |> send_resp(resp_code, "")
    |> halt()
  end

  match _ do
    conn
  end
end
