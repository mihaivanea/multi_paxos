defmodule Detector do

  def start(r_prime, leader_prime, leader) do
    next(r_prime, leader_prime, leader)
  end # start

  defp next(r_prime, leader_prime, leader) do
    #IO.puts("PING")
    #IO.puts "leader is #{inspect leader}, prime is #{inspect leader_prime}"
    send(leader_prime, {:ping, self()})
    receive do
      {:pong} -> 
        next(r_prime, leader_prime, leader)
    after
      1000 ->
        #IO.puts("DETECTOR SENDS FAILURE")
        send(leader, {:failure, r_prime})
    end
  end # next

end # Detector
