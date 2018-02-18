# Mihail Vanea (mv1315)

defmodule Scout do

  def start(leader, acceptors, b) do
    waitfor = acceptors
    pvalues = MapSet.new()
    for a <- acceptors, do: 
      send(a, {:p1a, self(), b})
    next(leader, acceptors, b, pvalues)
  end # start

  defp next(leader, acceptors, b, pvalues) do
    receive do
      {:p1b, a, b_prime, r} ->
        if b_prime == b do
          pvalues = MapSet.put(pvalues, r)
          waitfor = MapSet.delete(waitfor, a)
          if MapSet.size(waitfor) < (MapSet.size(acceptors) / 2) do
            send(leader, {:adopted, b, pvalues})
            Process.exit(self(). :exit)
          else
            send(leader, {:preempted, b_prime})
            Process.exit(self(). :exit)
          end
        end
    end
  end # next

end # Scout
