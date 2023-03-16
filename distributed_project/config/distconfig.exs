nodes_length = length(Application.get_env(:distmix, :nodes))
sim_front = nodes_length
sim_back = nodes_length - 1
load_balencer = nodes_length - 2
data = nodes_length - 3

[
  imt_order: [
    port:
      case DistMix.nodei() do
        ^sim_front -> 9092
        ^sim_back -> 9091
        ^load_balencer -> 9090
        ^data -> 9093
        _ -> 9093 + DistMix.nodei()
      end,
    transactors: Application.get_env(:distmix, :nodes) |> Enum.drop(-4),
    statnode: Application.get_env(:distmix, :nodes) |> Enum.at(-4),
    app_type:
      case DistMix.nodei() do
        ^sim_front -> :sim_front
        ^sim_back -> :sim_back
        ^load_balencer -> :load_balencer
        ^data -> :data
        _ -> :app
      end,
    node_index: DistMix.nodei()
  ]
]
