# Mihail Vanea (mv1315)

defmodule Acceptor do

  def start(_) do
    ballot_num = {-1, self()}
    accepted = MapSet.new()
    next(ballot_num, accepted)
  end # start

  defp next(ballot_num, accepted) do
    receive do
      {:p1a, leader, b} -> 
        new_ballot_num = if b > ballot_num do b else ballot_num end
        send(leader, {:p1b, self(), new_ballot_num, accepted})
        next(new_ballot_num, accepted)
      {:p2a, leader, {b, s, c}} -> 
        new_accepted = 
          if b == ballot_num do
            MapSet.put(accepted, {b, s, c})
          else
            accepted
          end
        send(leader, {:p2b, self(), ballot_num})
        next(ballot_num, new_accepted)
    end
  end # next

end # Acceptor
