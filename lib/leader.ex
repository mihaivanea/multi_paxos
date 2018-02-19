# Mihail Vanea (mv1315)

defmodule Leader do

  def start(acceptors, replicas) do
    ballot_num = {0, self()}
    active = false
    proposals = Mapset.new()
    # TODO: change scout index
    # scout_name = DAC.node_name(config.setup, "scout", 0)
    DAC.node_spawn("scout", Scout, :start, [self(), acceptors, ballot_num])
    next(acceptors, replicas, ballot_num, active, proposals)
  end # start

  defp next(acceptors, replicas, ballot_num, active, proposals) do
    receive do
      {:propose, s, c} ->
        if !there_exists(proposals, s) do
          if active do
            # TODO: change commander index
            # commander_name = DAC.node_name(config.setup, "commander", 0)
            DAC.node_spawn("commander", Commander, :start, [self(), 
              acceptors, replicas, {ballot_num, s, c}])
          end
          next(acceptors, replicas, ballot_num, active, MapSet.put(proposals, {s, c}))
        end
      {:adopted, ballot_num, pvalues} ->
        updated_proposals = update(proposals, pmax(pvalues))
        for {s, c} <- updated_proposals, do:
          DAC.node_spawn("commander", Commander, :start, [self(), 
            acceptors, replicas, {ballot_num, s, c}])
        next(acceptors, replicas, ballot_num, true, updated_proposals)
      {:preempted, {r_prime, leader_prime}} ->
        if {r_prime, leader_prime} > ballot_num do
          DAC.node_spawn("scout", Scout, :start, [self(), acceptors, ballot_num])
          next(acceptors, replicas, {r_prime + 1, self()}, false, proposals)
        end
    end
    next(acceptors, replicas, ballot_num, active, proposals)
  end # next

  defp there_exists(set, {s, c}) do
    Enum.at((for {s, c1} <- MapSet.to_list(set), do: {s, c1}), 
      fn({s, c1}) -> c != c1 end)
  end # there_exists

  defp get_highest_ballot(pvalues, slot) do
    for_slot = for {b, slot, c} <- pvalues, do: {b, slot, c}
    b_list = for {b, _, _} <- for_slot, do: b
    max_bal = Enum.max(b_list) 
    for {max_bal, s, c} <- for_slot, do: {s, c}
  end # get_highest_ballot

  defp pmax(pvalues) do
    pvalues = MapSet.to_list(pvalues)
    s_list = for {_, s, _} <- pvalues, do: s
    highest = []
    for slot <- s_list, do:
      highest ++ [get_highest_ballot(pvalues, slot)]
  end # pmax

  defp update(x, y) do
    x_list = MapSet.to_list(x)
    x_list = Enum.filter(x_list, fn {_, s, _} -> !there_exists(x, s) end) 
    MapSet.union(MapSet.new(x_list), y)
  end # update

end # Leader
