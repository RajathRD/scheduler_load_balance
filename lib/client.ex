defmodule Client do
  import Kernel

  def infinite_submit(scheduler, duration, timeout, id) do

    job = Job.Payload.new(self(), id, duration)
    send(scheduler, {:job_submit, job})

    :timer.sleep(timeout)
    infinite_submit(scheduler, duration, timeout, id+1)
  end

  def submit_njobs(scheduler, duration, timeout, id, n) do

    job = Job.Payload.new(self(), id, duration)
    send(scheduler, {:job_submit, job})

    :timer.sleep(timeout)
    if id < n do
      submit_njobs(scheduler, duration, timeout, id+1, n)
    end
  end
end
