defmodule Scheduler do
  import Util

  import Kernel


  @schedule_timeout 10

  defstruct(
    task_queue: nil,
    node_state: nil,
    node: nil,
    schedule_timeout: nil,
    schedule_timer: nil
  )

  def init() do
    %Scheduler{
      task_queue: :queue.new(),
      node_state: nil,
      node: nil,
      schedule_timeout: @schedule_timeout,
      schedule_timer: nil
    }
  end

  def print_queue(state) do
    IO.puts("Queue: #{inspect(state.task_queue)}")
  end

  def add_job(state, job) do
    job = Map.put(job, :scheduler, self())
    job = Map.put(job, :arrival_time, :os.system_time(:milli_seconds))
    %{state | task_queue: :queue.in(job, state.task_queue)}
  end

  def remove_job(state) do
    {{:value, _}, queue} = :queue.out(state.task_queue)
    %{state | task_queue: queue}
  end

  def update_node_state(state, :occupy) do
    %{state | node_state: true}
  end

  def update_node_state(state, :release) do
    %{state | node_state: false}
  end

  def start_schedule_timer(state) do
    %{state | schedule_timer: Util.timer(state.schedule_timeout, :schedule)}
  end

  def stop_schedule_timer(state) do
    Util.cancel_timer(state.schedule_timer)
    %{state | schedule_timer: nil}
  end

  def check_feasibility(state) do
    not state.node_state
  end

  defp update_node(state, pid) do
    state = %{state | node: pid}
    state = %{state | node_state: false}
  end
  defp next_schedule(state) do
    if :queue.len(state.task_queue) > 0 do
      job = :queue.get(state.task_queue)

      if check_feasibility(state) do
        send(
          state.node,
          Job.Creation.RequestRPC.new(
            self(),
            job
          )
        )
        true
      else
        false
      end
    else
      false
    end
  end

  def start do
    state = init()
    state = start_schedule_timer(state)
    IO.puts("Scheduler #{inspect(self())} is live")
    run(state)
  end

  def run(state) do
    receive do
      {:job_submit, job} ->
        state = add_job(state, job)
        run(state)

      %Job.Creation.ReplyRPC{
        node: node,
        accept: accept,
        job: job
      } ->
        state = if accept do
            # IO.puts("Node: #{node} - creation success for #{job.id} -> #{inspect(rstate)}")
            state = update_node_state(state, :occupy)
            remove_job(state)
          else
            # IO.puts("Node: #{node} - creation failure for #{job.id}")
            state
        end
        state = start_schedule_timer(state)
        run(state)

      :schedule ->
        state = if next_schedule(state) do
          stop_schedule_timer(state)
        else
          state = stop_schedule_timer(state)
          start_schedule_timer(state)
        end

        run(state)

      {:release, %Resource.ReleaseRPC{
        node: node,
        job: _
      }} ->
        state = update_node_state(state, :release)
        run(state)

      %Register.RequestRPC {
        node: node
      } ->
        state = update_node(state, node)
        send(node, Register.ReplyRPC.new(self(), true))
        run(state)
    end
  end
end
