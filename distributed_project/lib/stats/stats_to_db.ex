defmodule StatsToDb do
  use GenServer

  @timeout 100

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def get(product_id) do
    data_node_name = Application.get_env(:imt_order, :statnode)
    GenServer.call({StatsToDb, data_node_name}, {:get, product_id})
  end

  def init(:ok) do
    db_pid = spawn_link(StatsDB, :update_db, [])
    update_pid = spawn_link(__MODULE__, :update, [self()])
    state = StatsState.initial(db_pid, update_pid)
    schedule_update(state)
    {:ok, state}
  end

  def handle_info(:update, state) do
    schedule_update(state)
    {:noreply, state}
  end

  def handle_info({:new_state, new_state}, _state) do
    {:noreply, new_state}
  end

  def handle_call({:get, product_id}, _from, state) do
    stats_from_cash = StatsState.get_product_stats(product_id, state)

    case stats_from_cash do
      nil -> {:reply, StatsDB.get_product_stats(product_id), state}
      _ -> {:reply, stats_from_cash, state}
    end
  end

  def schedule_update(state) do
    send(state.update_pid, {:update, state})
    Process.send_after(self(), :update, @timeout)
  end

  def update(pid) do
    receive do
      {:update, state} ->
        paths = StatsFileHandling.get_paths()

        files_content =
          paths
          |> StatsFileHandling.get_contents()
          |> List.flatten()
          |> StatsFileHandling.merge_contents()

        send(StatsState.get_db_pid(state), {:update_db, files_content})
        new_state = files_content |> StatsState.update_stats(state)
        StatsFileHandling.delete(paths)
        send(pid, {:new_state, new_state})
        update(pid)
    end
  end
end
