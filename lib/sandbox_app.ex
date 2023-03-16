defmodule ImtSandbox.App do
  use Application
  def start(_,_) do
    File.rmdir("data")
    File.mkdir("data")

    [node_name | host_name] = String.split(Atom.to_string(Node.self), "@")

    if node_name == "sim" do
      Supervisor.start_link([
        ImtOrder.App,
        ImtSim.Back,
        ImtSim.Front,
      ], strategy: :one_for_one)
    else
      Supervisor.start_link([ImtOrder.App], strategy: :one_for_one)
    end
  end
end
