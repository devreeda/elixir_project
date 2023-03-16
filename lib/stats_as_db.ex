defmodule ImtOrder.StatsAsDb do
  def find_bisec(file, id_bin) do
    {id, ""} = Integer.parse(id_bin)
    f = File.open!(file)
    {:ok, file_info} = :file.read_file_info(file)
    vals = bisec(f, id, 0, elem(file_info, 1))
    :ok = File.close(f)
    vals
  end

  # start of file case
  def bisec(f, id, 0, max) when max < 6 do
    {:ok, _} = :file.position(f, {:bof, 0})
    data = IO.binread(f, 30)
    [before, _bin |_rest] = String.split(data,"\n", parts: 3)
    [line_id_bin | rest] = String.split(before, ",")
    {line_id, ""} = Integer.parse(line_id_bin)
    case line_id do
      ^id -> rest
      _ -> {:error, "not found"}
    end
  end

  def bisec(f, id, min, max) do
    split_pos = min + div(max - min, 2)
    {:ok, _} = :file.position(f, {:bof, split_pos})
    data = IO.binread(f, 30)
    [before, bin |_rest] = String.split(data,"\n", parts: 3)
    case bin do
      ""-> # edge case : eof
        bisec(f, id, min, split_pos)
      _->
        [line_id_bin | rest] = String.split(bin, ",")
        {line_id, ""} = Integer.parse(line_id_bin)
        case line_id do
          ^id -> rest
          line_id when line_id < id -> bisec(f, id, split_pos + byte_size(before) + byte_size(bin), max)
          _ -> bisec(f, id, min, split_pos)
        end
    end
  end

  def find_enum(file,id_bin) do
    File.stream!(file) |> Enum.find_value(fn line->
      case line |> String.trim_trailing("\n") |> String.split(",") do
        [^id_bin|rest]->rest
        _-> nil
      end
    end)
  end
end


defmodule ImtOrder.StatsToDb do

  def get(prod_id) do GenServer.call(__MODULE__,{:get,prod_id}) end

  use GenServer, shutdown: :infinity
  def start_link(arg) do GenServer.start_link(__MODULE__,arg,name: __MODULE__) end
  @tick 1000
  def init(_) do
    inmem_db = for prod_id<-1..10_000 do
      prod_id = "#{prod_id}"
      {prod_id,MicroDb.HashTable.get("stats",prod_id) || []}
    end |> Enum.into(%{})
    Process.flag(:trap_exit,true)
    Process.send_after(self(),:pull_files,@tick)
    {:ok,inmem_db}
  end
  def handle_cast({:update_db,list},inmem_db) do
    new_db = Enum.reduce(list,inmem_db, fn {prod_id,val}, db_acc->
      Map.update(db_acc,prod_id,[val],fn vals-> [val|vals] end)
    end)
    {:noreply,new_db}
  end
  def handle_call({:get,prod_id},_,inmem_db) do
    {:reply,inmem_db[prod_id],inmem_db}
  end
  def handle_info(:pull_files,inmem_db) do
    parent = self()
    spawn_link fn->
      files = Path.wildcard("data/stat_*")
      if files != [] do
        IO.puts "integrate #{inspect files}"
        list =
          Stream.map(files,fn file_name ->
              Stream.map(File.stream!(file_name),fn line->
                [prod_id,sold_qty,price] = line |> String.trim_trailing("\n") |> String.split(",")
                {prod_id,{String.to_integer(sold_qty),String.to_integer(price)}}
              end)
          end) |> Stream.concat |> Enum.to_list
        GenServer.cast(__MODULE__,{:update_db,list})
        for file_name<-files do File.rm!(file_name) end
      end
      Process.send_after(parent,:pull_files,@tick)
    end
    {:noreply,inmem_db}
  end
  def handle_info(_msg,inmem_db) do {:noreply,inmem_db} end

  def terminate(:shutdown,inmem_db) do
    for {prod_id,stats}<-inmem_db do
      MicroDb.HashTable.put("stats",prod_id,stats)
    end
  end
end
