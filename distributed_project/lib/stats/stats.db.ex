defmodule StatsDB do
  def get_product_stats(id) do
    MicroDb.HashTable.get(:stats, id) || []
  end

  def update_products_stats(new_stats) do
    new_stats
    |> Enum.each(fn {id, list} ->
      MicroDb.HashTable.put(:stats, id, list ++ get_product_stats(id))
    end)
  end

  def update_db() do
    receive do
      {:update_db, new_stats} ->
        StatsDB.update_products_stats(new_stats)
        update_db()
    end
  end
end
