# Mihail Vanea (mv1315)

defmodule Replica do

  def start(leaders, initial_state) do
    state = initial_state
    slot_in = 1
    slot_out = 1
    requests = MapSet.new()
    proposals = MapSet.new()
    decisions = MapSet.new()
    next(state, slot_in, slot_out, requests, proposals, decisions)
  end # start

  defp next(state, slot_in, slot_out, requests, proposals, decisions) do
    receive do
      {:request, c} -> 
        new_requests = MapSet.put(requests, c)
        propose()
        next(state, slot_in, slot_out, new_requests, proposals, decisions)
      {:decision, s, c} -> 
        new_decisions = MapSet.put(decisions, {s, c})
        {new_proposals, new_requests} = while_decision(new_decisions, proposals,
          requests, slot_out, c)
        propose()
        next(state, slot_in, slot_out, new_requests, new_proposals, new_decisions)
    end
  end # next

  defp while_decision(decisions, proposals, requests, slot_out, c) do
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
      perform(c_prime)
      while_decision(decisions, new_proposals, new_requests, slot_out, c)
    else
      {proposals, requests}
    end
  end # while_decision

  defp propose() do
  end # propose

  defp perform({k, cid, op}) do
  end # perform

end # Replica
