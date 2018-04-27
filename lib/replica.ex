defmodule Replica do

  def start(config, database, _) do
    receive do
      {:bind, leaders} ->
        state = %{}
        state = Map.put(state, :slot_in, 1)
        state = Map.put(state, :slot_out, 1)
        state = Map.put(state, :requests, MapSet.new())
        state = Map.put(state, :proposals, MapSet.new())
        state = Map.put(state, :decisions, MapSet.new())
        state = Map.put(state, :leaders, leaders)
        state = Map.put(state, :config, config)
        state = Map.put(state, :database, database)
        next(state)
    end
  end # start

  defp next(state) do
    receive do
      {:request, c} -> 
        state = Map.update!(state, :requests, 
          fn _ -> MapSet.put(state[:requests], c) end)
        {new_state} = propose(state)
        next(new_state)
      {:decision, s, c} -> 
        new_decisions = MapSet.put(state[:decisions], {s, c})
        state = Map.update!(state, :decisions, fn _ -> new_decisions end)
        {new_state} = while_decision(state, c)
        {new_state} = propose(new_state)
        next(new_state)
    end
  end # next

  defp while_decision(state, c) do
    if DAC.there_exists(state[:decisions], {state[:slot_out], c}) do
      slot_out = state[:slot_out]
      c_prime = get_cmd(
        for {^slot_out, c} <- MapSet.to_list(state[:decisions]), do: c)
      {new_proposals, new_requests} = 
        if DAC.there_exists(state[:proposals], {state[:slot_out], c}) do
          c_second = get_cmd(Enum.take((for {^slot_out, c} <- 
            MapSet.to_list(state[:proposals]), do: c), 1))
          new_proposals = MapSet.delete(state[:proposals], 
            {state[:slot_out], c_second})
          new_requests = if c_second != c_prime do MapSet.put(
            state[:requests], c_second) else state[:requests] end
          {new_proposals, new_requests}
        else
          {state[:proposals], state[:requests]}
        end
      state = Map.update!(state, :requests, fn _ -> new_requests end)
      state = Map.update!(state, :proposals, fn _ -> new_proposals end)
      {new_slot_out} = perform(c_prime, state)
      state = Map.update!(state, :slot_out, fn _ -> new_slot_out end)
      state = Map.update!(state, :proposals, fn _ -> new_proposals end)
      while_decision(state, c)
    else
      {state}
    end
  end # while_decision

  defp propose(state) do
    while_propose(state)
  end # propose

  defp perform(cmd, state) do
    {_, _, op} = cmd
    slots = for {s, ^cmd} <- state[:decisions], do: s
    if !Enum.any?(slots, fn(s) -> s < state[:slot_out] end) do
      send(state[:database], {:execute, op})
    end
    {state[:slot_out] + 1}
  end # perform

  defp get_cmd([x]) do get_cmd(x) end
  defp get_cmd(x) do x end

  defp while_propose(state) do
    if state[:slot_in] < state[:slot_out] + state[:config].window_size and 
      !Enum.empty?(state[:requests]) do
      # if statement for fault tolerance
      c = get_cmd(Enum.at(state[:requests], 0))
      {new_requests, new_proposals} = 
        if !DAC.there_exists(state[:decisions], {state[:slot_in], c}) do
          n_requests = MapSet.delete(state[:requests], c)
          n_proposals = MapSet.put(state[:proposals], {state[:slot_in], c})
          for l <- state[:leaders], do:
            send(l, {:propose, state[:slot_in], c})
          {n_requests, n_proposals}
        else
          {state[:requests], state[:proposals]}
        end
      state = Map.update!(state, :slot_in, fn slot_in -> slot_in + 1 end)
      state = Map.update!(state, :requests, fn _ -> new_requests end)
      state = Map.update!(state, :proposals, fn _ -> new_proposals end)
      while_propose(state)
    else
      {state}
    end
  end # while_propose

end # Replica
