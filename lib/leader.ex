# Mihail Vanea (mv1315)

defmodule Leader do

  def start(config) do
    receive do
      {:bind, acceptors, replicas} ->
        ballot_num = {0, self()}
        # TODO: change scout index
        scout_name = DAC.node_name(config.setup, "scout", 0)
        DAC.node_spawn(scout_name, Scout, :start, [self(), acceptors, ballot_num])
        next(acceptors, replicas, ballot_num, false, MapSet.new(), config)
    end
  end # start

  defp next(acceptors, replicas, ballot_num, active, proposals, config) do
    IO.write("l")
    receive do
      {:propose, s, c} ->
        if !DAC.there_exists(proposals, {s, c}) do
          if active do
            # TODO: change commander index
            commander_name = DAC.node_name(config.setup, "commander", s)
            DAC.node_spawn(commander_name, Commander, :start, [self(), 
              acceptors, replicas, {ballot_num, s, c}])
          end
          next(acceptors, replicas, ballot_num, active, MapSet.put(proposals, {s, c}), config)
        end
        next(acceptors, replicas, ballot_num, active, proposals, config)
      {:adopted, b, pvalues} ->
        updated_proposals = update(proposals, pmax(pvalues))
        for {s, c} <- updated_proposals, do:
          DAC.node_spawn(DAC.node_name(config.setup, "commander", s), 
            Commander, :start, [self(), acceptors, replicas, {b, s, c}])
        next(acceptors, replicas, b, true, updated_proposals, config)
      {:preempted, {r_prime, leader_prime}} ->
        if {r_prime, leader_prime} > ballot_num do
          new_ballot_num = {r_prime + 1, self()}
          DAC.node_spawn(DAC.node_name(config.setup, "scout", r_prime + 1), Scout, 
          :start, [self(), acceptors, new_ballot_num])
          next(acceptors, replicas, new_ballot_num, false, proposals, config)
        end
        next(acceptors, replicas, ballot_num, active, proposals, config)
    end
  end # next

  defp get_highest_ballot(pvalues, slot) do
    for_slot = for {b, ^slot, c} <- pvalues, do: {b, slot, c}
    b_list = for {b, _, _} <- for_slot, do: b
    max_bal = Enum.max(b_list) 
    res = for {^max_bal, slot, c} <- for_slot, do: {slot, c}
    Enum.at(res, 0)
  end # get_highest_ballot

  defp pmax(pvalues) do
    s_list = Enum.uniq(for {_, s, _} <- pvalues, do: s)
    for slot <- s_list, do: get_highest_ballot(MapSet.to_list(pvalues), slot)
  end # pmax

  defp update(x, y) do
    x_list = Enum.filter(MapSet.to_list(x), fn {s, c} -> !DAC.there_exists(x, {s, c}) end) 
    MapSet.union(MapSet.new(x_list), MapSet.new(y))
  end # update

end # Leader
