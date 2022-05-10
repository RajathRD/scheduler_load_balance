defmodule Simulation do
  import Kernel

  defstruct(
    num_schedulers: nil,
    schedulers: nil,
    nodes: nil
  )

  def print_state(state) do
    IO.puts("#{inspect(state)}")
  end

  defp launch_node(scheduler) do
    spawn(fn -> Node.start(scheduler) end)
  end

  defp launch_scheduler do
    spawn(fn -> Scheduler.start() end)
  end

  def setup(num_s) do
    File.rm_rf("./logs")
    File.mkdir("./logs")
    state = %Simulation{
      num_schedulers: num_s,
      schedulers: nil,
      nodes: nil
    }

    state = %{state | schedulers: Enum.map(1..state.num_schedulers, fn _ -> launch_scheduler() end)}
    state = %{state | nodes: Enum.map(state.schedulers, fn s_pid -> launch_node(s_pid) end)}

    :timer.sleep(500)
    Enum.map(
      0..length(state.nodes)-1,
      fn i ->
        node = Enum.at(state.nodes, i)
        send(Enum.at(state.nodes, i), {:update_nodes, List.delete_at(state.nodes, i)}) end
    )

    :timer.sleep(500)
    IO.puts("Simulator Setup Completed")
    state
  end
end
