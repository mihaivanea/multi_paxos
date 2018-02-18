# Mihail Vanea (mv1315)

defmodule Accpetor do

  def start() do
    ballot_num = 0
    accepted = MapSet.new()
    next(ballot_num, accepted)
  end # start

  defp next(ballot_num, accepted) do
    receive do
      {:p1a, leader, b} -> 
        if b > ballot_num do
          ballot_num = b
        end
        send(leader, {:p1b, self(), ballot_num, accepted})
      {:p2a, leader, {b, s, c}} -> 
        if b == ballot_num do
          accepted = MapSet.put(accepted, {b, s, c})
        end
        send(leader, {:p2b, self(), ballot_num})
    end
  end # next

end # Acceptor
