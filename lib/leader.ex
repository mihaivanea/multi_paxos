# Mihail Vanea (mv1315)

defmodule Leader do

  def start(config) do
    receive do
      {:bind, acceptors, replicas} ->
        ballot_num = {0, self()}
        scout_name = DAC.node_name(config.setup, "scout", 0)
        DAC.node_spawn(scout_name, Scout, :start, [self(), acceptors, 
          ballot_num])
        state = %{}
        state = Map.put(state, :acceptors, acceptors)
        state = Map.put(state, :replicas, replicas)
        state = Map.put(state, :ballot_num, ballot_num)
        state = Map.put(state, :active_flag, false)
        state = Map.put(state, :proposals, MapSet.new())
        state = Map.put(state, :config, config)
        next(state)
    end
  end # start

  defp next(state) do
    receive do
      {:propose, s, c} ->
        if !DAC.there_exists(state[:proposals], {s, c}) do
          if state[:active_flag] do
            # TODO: change commander index
            commander_name = DAC.node_name(state[:config].setup, "commander", s)
            DAC.node_spawn(commander_name, Commander, :start, [self(), 
              state[:acceptors], state[:replicas], {state[:ballot_num], s, c}])
          end
          state = Map.update!(state, :proposals, 
            fn p -> MapSet.put(p, {s, c}) end)
          next(state)
        else
          next(state)
        end
      {:adopted, b, pvalues} ->
        updated_proposals = update(state[:proposals], pmax(pvalues))
        for {s, c} <- updated_proposals, do:
          DAC.node_spawn(DAC.node_name(state[:config].setup, "commander", s), 
            Commander, :start, [self(), state[:acceptors], state[:replicas], 
            {b, s, c}])
        state = Map.update!(state, :ballot_num, fn _ -> b end)
        state = Map.update!(state, :active_flag, fn _ -> true end)
        state = Map.update!(state, :proposals, fn _ -> updated_proposals end)
        next(state)
      {:preempted, {r_prime, leader_prime}} ->
        if {r_prime, leader_prime} > state[:ballot_num] do
          DAC.node_spawn(DAC.node_name(state[:config].setup, "detector", 
            r_prime), Detector, :start, [r_prime, leader_prime, self()])
        end
        next(state)
      {:ping, detector} ->
        send(detector, {:pong})
        next(state)
      {:failure, r_prime} ->
        DAC.node_spawn(DAC.node_name(state[:config].setup, "scout", 
          r_prime + 1), Scout, :start, [self(), state[:acceptors], {r_prime + 1,
          self()}])
        state = Map.update!(state, :ballot_num, 
          fn {r_prime, pid} -> {r_prime + 1, self()} end)
        state = Map.update!(state, :active_flag, fn _ -> false end)
        next(state)
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
    x_list = Enum.filter(MapSet.to_list(x), fn {s, c} -> 
      !DAC.there_exists(x, {s, c}) end) 
    MapSet.union(MapSet.new(x_list), MapSet.new(y))
  end # update

end # Leader
