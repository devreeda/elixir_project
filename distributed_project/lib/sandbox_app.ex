defmodule ImtSandbox.App do
  use Application

  def start(_, _) do
    File.rmdir("data")
    File.mkdir("data")

    node_role = Application.fetch_env!(:imt_order, :app_type)

    node_to_start =
      case node_role do
        :sim_front -> ImtSim.Front
        :sim_back -> ImtSim.Back
        :app -> ImtOrder.App
        :load_balencer -> LoadBalancer
        :data -> Stats.Supervisor
      end

    Supervisor.start_link(
      node_to_start,
      strategy: :one_for_one
    )
  end
end
