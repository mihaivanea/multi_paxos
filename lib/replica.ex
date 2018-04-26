# Mihail Vanea (mv1316)

defmodule Replica do

  def start(_, database, _) do
    receive do
      {:bind, leaders} ->  
        next(nil, 1, 1, MapSet.new(), MapSet.new(), MapSet.new(), leaders, database)
    end
  end # start

  defp next(state, slot_in, slot_out, requests, proposals, decisions, leaders, database) do
    receive do
      {:request, c} -> 
        n_requests = MapSet.put(requests, c)
        {new_slot_in, new_requests, new_proposals} = 
          propose(slot_in, slot_out, n_requests, proposals, decisions, leaders)
        next(state, new_slot_in, slot_out, new_requests, new_proposals, decisions, leaders, database)
      {:decision, s, c} -> 
        new_decisions = MapSet.put(decisions, {s, c})
        {new_proposals, new_requests, new_slot_out, new_state} = while_decision(
          new_decisions, proposals, requests, slot_out, c, state, leaders, database)
        {new_slot_in, new_requests, new_proposals} = 
          propose(slot_in, new_slot_out, new_requests, new_proposals, new_decisions, leaders)
        next(new_state, new_slot_in, new_slot_out, new_requests, new_proposals, new_decisions, leaders, database)
    end
  end # next

  defp while_decision(decisions, proposals, requests, slot_out, c, state, leaders, database) do
    if DAC.there_exists(decisions, {slot_out, c}) do
      c_prime = get_cmd(for {^slot_out, c} <- MapSet.to_list(decisions), do: c)
      {new_proposals, new_requests} = if DAC.there_exists(proposals, {slot_out, c}) do
          c_second = get_cmd(Enum.take((for {^slot_out, c} <- MapSet.to_list(proposals), do: c), 1))
          new_proposals = MapSet.delete(proposals, {slot_out, c_second})
          new_requests = if c_second != c_prime do MapSet.put(
            requests, c_second) else requests end
          {new_proposals, new_requests}
        else
          {proposals, requests}
        end
      {new_slot_out, new_state} = perform(c_prime, decisions, slot_out, state, database)
      while_decision(decisions, new_proposals, new_requests, new_slot_out, c, new_state, leaders, database)
    else
      {proposals, requests, slot_out, state}
    end
  end # while_decision

  defp propose(slot_in, slot_out, requests, proposals, decisions, leaders) do
    while_propose(slot_in, slot_out, requests, proposals, decisions, leaders)

  end # propose

  defp perform(cmd, decisions, slot_out, state, database) do
    {_, _, op} = cmd
    slots = for {s, ^cmd} <- decisions, do: s
    # TODO: reconfig() for crash tolerance
    if Enum.any?(slots, fn(s) -> s < slot_out end) do
      {slot_out + 1, state}
    else
      # TODO: for crash tolerance
      # {next, result} = op(state) 
      send(database, {:execute, op})
      # TODO: for crash tolerance
      # send(k, {:response, cid, result})
      {slot_out + 1, state}
    end
  end # perform

  defp get_cmd([x]) do get_cmd(x) end
  defp get_cmd(x) do x end

  defp while_propose(slot_in, slot_out, requests, proposals, decisions, leaders) do
    if slot_in < slot_out + 200 and !Enum.empty?(requests) do
      # if statement for fault tolerance
      c = get_cmd(Enum.at(requests, 0))
      {new_requests, new_proposals} = 
        if !DAC.there_exists(decisions, {slot_in, c}) do
          n_requests = MapSet.delete(requests, c)
          n_proposals = MapSet.put(proposals, {slot_in, c})
          for l <- leaders, do:
            send(l, {:propose, slot_in, c})
          {n_requests, n_proposals}
        else
          {requests, proposals}
        end
      while_propose(slot_in + 1, slot_out, new_requests, new_proposals, decisions, leaders)
    else
      {slot_in, requests, proposals}
    end
  end # while_propose

end # Replica
