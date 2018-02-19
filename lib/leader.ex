# Mihail Vanea (mv1315)

defmodule Leader do

  def start(acceptors, replicas) do
    ballot_num = {0, self()}
    active = false
    proposals = MapSet.new()
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

  def there_exists(set, {s, c}) do
    cmd_list = for {^s, c} <- set, do: c
    match_slots = for {^s, c1} <- MapSet.to_list(set), do: {s, c1}
    match_slots = for m <- match_slots, do: {m, c}
    Enum.any?(match_slots, fn({{_, c}, c1}) -> c1 != c and Enum.member?(cmd_list, c1) end)
  end # there_exists

  def get_highest_ballot(pvalues, slot) do
    for_slot = for {b, ^slot, c} <- pvalues, do: {b, slot, c}
    b_list = for {b, _, _} <- for_slot, do: b
    max_bal = Enum.max(b_list) 
    for {^max_bal, s, c} <- for_slot, do: {s, c}
  end # get_highest_ballot

  def pmax(pvalues) do
    s_list = for {_, s, _} <- MapSet.to_list(pvalues), do: s
    highest = []
    for slot <- s_list, do:
      highest ++ [get_highest_ballot(MapSet.to_list(pvalues), slot)]
  end # pmax

  def update(x, y) do
    x_list = Enum.filter(MapSet.to_list(x), fn {s, c} -> !there_exists(x, {s, c}) end) 
    MapSet.union(MapSet.new(x_list), y)
  end # update

end # Leader
