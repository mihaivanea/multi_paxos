# Mihail Vanea (mv1315)

defmodule Scout do

  def start(leader, acceptors, b) do
    waitfor = acceptors
    pvalues = MapSet.new()
    for a <- acceptors, do: 
      send(a, {:p1a, self(), b})
    next(leader, acceptors, b, waitfor, pvalues)
  end # start

  defp next(leader, acceptors, b, waitfor, pvalues) do
    IO.write("s")
    receive do
      {:p1b, a, b_prime, r} ->
        if b_prime == b do
          new_pvalues = MapSet.union(pvalues, r)
          new_waitfor = List.delete(waitfor, a)
          if length(new_waitfor) < (length(acceptors) / 2) do
            send(leader, {:adopted, b, new_pvalues})
            Process.exit(self(), :exit)
          end
          next(leader, acceptors, b, new_waitfor, new_pvalues)
        else
          IO.puts("HERE")
          send(leader, {:preempted, b_prime})
          Process.exit(self(), :exit)
        end
    end
  end # next

end # Scout
