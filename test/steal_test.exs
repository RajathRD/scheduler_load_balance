defmodule StealTest do
  use ExUnit.Case

  test "Simulation Init Test" do
    sim_state = Simulation.setup(2)
    scheduler_1 = Enum.at(sim_state.schedulers, 0)
    scheduler_2 = Enum.at(sim_state.schedulers, 1)
    n_jobs = 10

    # make sure that length of client_config is same as number of schedulers
    # [duration, interval]
    client_config = [[100, 500], [500, 100]]

    Enum.map(
      0..length(client_config)-1,
      fn i ->
        tuple = Enum.at(client_config, i)
        duration = Enum.at(tuple, 0)
        timeout = Enum.at(tuple, 1)
        spawn(fn -> Client.submit_njobs(
          scheduler=Enum.at(sim_state.schedulers, i),
          duration=duration,
          timeout=timeout,
          id=i*n_jobs,
          n=i*n_jobs + n_jobs - 1
        ) end)
      end
    )
    # spawn(fn -> Client.submit_njobs(scheduler=scheduler_1, duration=500, timeout=200, id=0, n=n_jobs) end)
    # spawn(fn -> Client.submit_njobs(scheduler=scheduler_2, duration=100, timeout=200, id=10, n=10+n_jobs) end)

    :timer.sleep(10_000)
  end
end
