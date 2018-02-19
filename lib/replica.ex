# Mihail Vanea (mv1315)

defmodule Replica do

  def start(leaders, initial_state) do
    state = initial_state
    slot_in = 1
    slot_out = 1
    requests = MapSet.new()
    proposals = MapSet.new()
    decisions = MapSet.new()
    #next(state, slot_in, slot_out, requests, proposals, decisions)
  end # start

  #defp next(state, slot_in, slot_out, requests, proposals, decisions) do
  #  receive do
  #    {:request, c} -> 
  #      requests = MapSet.put(requests, c)
  #    {:decision, s, c} -> 
  #      decisions = MapSet.put(decisions, {s, c})
  #  end

  #end # next

  #defp while_decision() do


end # Replica
