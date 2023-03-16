defmodule StatsState do
  def initial(db_pid, update_pid) do
    table = :ets.new(:stats, [:named_table, :public, :ordered_set])
    %{stats: table, db_pid: db_pid, update_pid: update_pid}
  end

  def get_db_pid(state) do
    state.db_pid
  end

  def get_update_pid(state) do
    state.update_pid
  end

  def update_stats(stats, state) do
    Enum.each(stats, fn {id, stats} ->
      :ets.insert(state.stats, {id, stats})
    end)

    state
  end

  @spec get_product_stats(any, atom | %{:stats => atom | :ets.tid(), optional(any) => any}) :: any
  def get_product_stats(product_id, state) do
    case :ets.lookup(state.stats, product_id) do
      [] -> []
      [{_, stats}] -> stats
    end
  end
end
