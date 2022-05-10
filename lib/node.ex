defmodule Node do
  import Kernel

  require Logger
  defstruct(
    life_start_time: nil,
    resource: nil,
    scheduler: nil,
    num_jobs: nil,
    trace_log_path: nil,
    trace_log_file: nil,
    avg_jct: nil,
    other_nodes: nil
  )

  def init(scheduler) do
    trace_log_path = "./logs/" <> inspect(self()) <> "_job_trace.log"
    File.write(trace_log_path, "")
    {status, trace_file} = File.open(trace_log_path, [:write])

    case status do
      :ok ->
        true
      _ ->
        Logger.error("#{inspect(self())} Log File could not be created at #{trace_log_path}")
    end

    %Node{
      life_start_time: :os.system_time(:milli_seconds),
      resource: false,
      scheduler: scheduler,
      trace_log_path: trace_log_path,
      trace_log_file: trace_file,
      num_jobs: 0,
      avg_jct: 0,
      other_nodes: nil
    }
  end

  def occupy(state) do
    %{state | resource: true}
  end

  def release(state) do
    %{state | resource: false}
  end

  def check_feasibility(state, job) do
    not state.resource
  end

  def run_job(job) do
    Process.send_after(
      self(),
      {:done, job},
      job.duration
    )
  end

  defp mark_start_time(job) do
    Map.put(job, :start_time, :os.system_time(:milli_seconds))
  end

  defp mark_complete(job) do
    job = Map.put(job, :status, :done)
    Map.put(job, :finish_time, :os.system_time(:milli_seconds))
  end

  defp send_release_rpc(state, job) do
    send(state.scheduler, {
      :release,
      Resource.ReleaseRPC.new(self(), job)
    })
  end

  defp store_other_nodes(state, other_nodes) do
    %{state | other_nodes: other_nodes}
  end

  defp register(state) do
    send(
      state.scheduler,
      Register.RequestRPC.new(self())
    )
  end

  def start(scheduler) do
    state = init(scheduler)
    register(state)
    # IO.puts("Node: #{inspect(self())} is live")
    loop(state)
  end


  defp log_job(state, job) do
    # log_message = "#{inspect(job.client)},#{inspect(self())},#{inspect(job.scheduler)},#{job.id},#{job.arrival_time - state.life_start_time},#{job.duration},#{job.start_time- state.life_start_time},#{job.finish_time- state.life_start_time},#{job.finish_time - job.arrival_time}"
    log_message = "#{job.id},#{job.arrival_time - state.life_start_time},#{job.duration},#{job.start_time- state.life_start_time},#{job.finish_time- state.life_start_time},#{job.finish_time - job.arrival_time}\n"
    IO.write(state.trace_log_file, log_message)
    log_message = "ID: #{job.id}, Arrival: #{job.arrival_time - state.life_start_time}, Duration: #{job.duration}, Start Time: #{job.start_time- state.life_start_time}, Finish Time: #{job.finish_time- state.life_start_time}, JCT: #{job.finish_time - job.arrival_time}"
    IO.puts(log_message)
    # %{state | log: state.log ++ [job]}
  end

  defp update_jct(state, job) do
    state = %{state | avg_jct: state.num_jobs * state.avg_jct + (job.finish_time - job.arrival_time)}
    %{state | num_jobs: state.num_jobs + 1}
  end

  def loop(state) do
    receive do
      %Job.Creation.RequestRPC{
        scheduler: _,
        job: job
      } ->

        state = if check_feasibility(state, job) do
          # IO.puts("Node #{inspect(self())} - Job #{job.id} Created")
          job = mark_start_time(job)
          run_job(job)
          state = occupy(state)
          send(state.scheduler, Job.Creation.ReplyRPC.new(self(), true, job))

          state
        else
          # IO.puts("Node #{inspect(self())} - Job #{job.id} Rejected")
          send(state.scheduler, Job.Creation.ReplyRPC.new(self(), false, job))

          state
        end
        loop(state)

      {:done, job} ->
        # IO.puts("Node #{inspect(self())} - Job #{job.id} Completed")
        state = release(state)
        job = mark_complete(job)
        state = update_jct(state, job)
        send_release_rpc(state, job)
        log_job(state, job)
        loop(state)

      %Register.ReplyRPC{
        scheduler: scheduler,
        success: success
      } ->
        IO.puts("Node #{inspect(self())} - Registered to #{inspect(scheduler)} successefully")
        loop(state)

      {:update_nodes, nodes} ->
        state = store_other_nodes(state, nodes)
        IO.puts("#{inspect(self())} stored: #{inspect(nodes)}")
        loop(state)
    end
  end
end
