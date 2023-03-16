defmodule StatsFileHandling do
  def get_paths do
    Path.wildcard("data/stat_*")
  end

  def delete(files) do
    Enum.each(files, fn file_name ->
      File.rm(file_name)
    end)
  end

  def get_contents(files_name) do
    files_name
    |> Enum.map(fn file_name ->
      spawn_link(__MODULE__, :get_file_content, [file_name, self()])
    end)
    |> Enum.map(fn _ ->
      receive do
        {:file_content, content} -> content
      end
    end)
  end

  def get_file_content(file_name, pid) do
    res =
      file_name
      |> File.stream!()
      |> Enum.to_list()
      |> Enum.map(fn line ->
        [id, sold, price] = line |> String.trim_trailing("\n") |> String.split(",")
        {sold, ""} = Integer.parse(sold)
        {price, ""} = Float.parse(price)
        {id, sold, price}
      end)

    send(pid, {:file_content, res})
  end

  def merge_contents(files_content) do
    files_content
    |> Enum.reduce(%{}, fn {id, sold, price}, acc ->
      case Map.get(acc, id) do
        nil ->
          Map.put(acc, id, [{sold, price}])

        list ->
          Map.put(acc, id, [{sold, price} | list])
      end
    end)
  end
end
