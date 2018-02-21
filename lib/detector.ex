defmodule Detector do

  def start(r_prime, leader_prime, leader) do
    next(r_prime, leader_prime, leader)
  end # start

  defp next(r_prime, leader_prime, leader) do
    IO.write("d")
    send(leader_prime, {:ping, self()})
    receive do
      {:pong} -> 
        next(r_prime, leader_prime, leader)
    after
      100 ->
        send(leader, {:failure, r_prime})
    end
  end # next

end # Detector
