# Mihail Vanea (mv1315)

defmodule Replica do

  def start(leaders, initial_state) do
    state = initial_state
    slot_in = 1
    slot_out = 1
    requests = MapSet.new()
    proposals = MapSet.new()
    decisions = MapSet.new()
    next(state, slot_in, slot_out, requests, proposals, decisions, leaders)
  end # start

  defp next(state, slot_in, slot_out, requests, proposals, decisions, leaders) do
    receive do
      {:request, c} -> 
        new_requests = MapSet.put(requests, c)
        {new_slot_in, new_requests, new_proposals} = 
          propose(slot_in, slot_out, new_requests, proposals, decisions, leaders)
        next(state, new_slot_in, slot_out, new_requests, new_proposals, decisions, leaders)
      {:decision, s, c} -> 
        new_decisions = MapSet.put(decisions, {s, c})
        {new_proposals, new_requests, new_slot_out, new_state} = while_decision(
          new_decisions, proposals, requests, slot_out, c, state, leaders)
        {new_slot_in, new_requests, new_proposals} = 
          propose(slot_in, new_slot_out, new_requests, new_proposals, new_decisions, leaders)
        next(new_state, new_slot_in, new_slot_out, new_requests, new_proposals, new_decisions, leaders)
    end
  end # next

  defp while_decision(decisions, proposals, requests, slot_out, c, state, leaders) do
    if DAC.there_exists(decisions, {slot_out, c}) do
      c_prime = for {^slot_out, c} <- MapSet.to_list(decisions), do: c
      {new_proposals, new_requests} = if DAC.there_exists(proposals, {slot_out, c}) do
          c_second = for {^slot_out, c} <- MapSet.to_list(proposals), do: c
          new_proposals = MapSet.delete(proposals, {slot_out, c_second})
          new_requests = if c_second != c_prime do requests = MapSet.put(
            requests, c_second) else requests end
          {new_proposals, new_requests}
        else
          {proposals, requests}
        end
      {new_slot_out, new_state} = perform(c_prime, decisions, slot_out, state)
      while_decision(decisions, new_proposals, new_requests, new_slot_out, c, new_state, leaders)
    else
      {proposals, requests, slot_out, state}
    end
  end # while_decision

  defp propose(slot_in, slot_out, requests, proposals, decisions, leaders) do
    while_propose(slot_in, slot_out, requests, proposals, decisions, leaders)

  end # propose

  defp perform({k, cid, op}, decisions, slot_out, state) do
    slots = for {s, c} <- decisions, do: s
    # TODO: reconfig() for crash tolerance
    if Enum.any?(slots, fn(s) -> s < slot_out end) do
      {slot_out + 1, state}
    else
      {next, result} = op(state) 
      send()
      send(k, {:response, cid, result})
      {slot_out + 1, next}
    end
  end # perform

  defp while_propose(slot_in, slot_out, requests, proposals, decisions, leaders) do
    if slot_in < slot_out + window and Enum.empty?(requests)do
      # if statement for fault tolerance
      c = Enum.at(requests, 0) 
      {new_requests, new_proposals} = 
        if !DAC.there_exists(decisions, {slot_in, c}) do
          new_requests = MapSet.delete(requests, c)
          new_proposals = MapSet.put(proposals, {slot_in, c})
          for l <- leaders, do:
            send(l, {:propose, slot_in, c})
          {new_requests, new_proposals}
        else
          {requests, proposals}
        end
      while_propose(slot_in + 1, slot_out, new_requests, new_proposals, decisions, leaders)
    else
      {slot_in, requests, proposals}
    end
  end # while_propose

end # Replica
