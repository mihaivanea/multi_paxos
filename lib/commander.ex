# Mihail Vanea (mv1315)

defmodule Commander do

  def start(leader, acceptors, replicas, {b, s, c}) do
    waitfor = acceptors 
    for a <- acceptors, do:
      send(a, {:p2a, self(), {b, s, c}})
    next(leader, acceptors, replicas, {b, s, c}, waitfor)
  end # start

  defp next(leader, acceptors, replicas, {b, s, c}, waitfor) do
    receive do
      {:p2b, a, b_prime} ->
        if b_prime == b  do
          waitfor = MapSet.delete(waitfor, a)
          if MapSet.size(waitfor) < (MapSet.size(acceptors) / 2) do
            for r <- replicas, do:
              send(r, {:decision, s, c})
            Process.exit(self(), :exit)
          end
        else
          send(leader, {:preempted, b_prime})
          Process.exit(self(), :exit)
        end
    end
  end # next

end # Commander
