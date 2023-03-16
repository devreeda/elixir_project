defmodule Stats.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      %{
        id: StatsToDb,
        start: {StatsToDb, :start_link, [[]]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
