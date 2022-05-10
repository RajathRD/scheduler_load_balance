defmodule Scheduler do
  import Util

  import Kernel


  @schedule_timeout 50
  @steal_timeout 50
  @shed_timeout 50
  @slack_timeout 500
  @balance_type :steal

  defstruct(
    task_queue: nil,
    node_state: nil,
    node: nil,
    schedulers: nil,
    schedule_timeout: nil,
    schedule_timer: nil,
    steal_timer: nil,
    shed_timer: nil
  )

  def init() do
    %Scheduler{
      task_queue: :queue.new(),
      node_state: nil,
      node: nil,
      schedulers: nil,
      schedule_timeout: @schedule_timeout,
      schedule_timer: nil,
      steal_timer: nil,
      shed_timer: nil
    }
  end

  def print_queue(state) do
    IO.puts("Queue: #{inspect(state.task_queue)}")
  end

  def add_job(state, job) do
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

  def start_steal_timer(state) do
    %{state | steal_timer: Util.timer(@steal_timeout, :steal_timeout)}
  end

  def stop_steal_timer(state) do
    Util.cancel_timer(state.steal_timer)
    %{state | steal_timer: nil}
  end

  def start_shed_timer(state) do
    %{state | shed_timer: Util.timer(@shed_timeout, :shed_timeout)}
  end

  def stop_shed_timer(state) do
    Util.cancel_timer(state.shed_timer)
    %{state | shed_timer: nil}
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
        job = Map.put(job, :scheduler, self())
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

  defp work_steal(state) do
    if :queue.len(state.task_queue) == 0 do
      sch = Enum.random(state.schedulers)
      # IO.puts("#{inspect(self())} triggered steal from #{inspect(sch)}")
      send(sch, WorkSteal.RequestRPC.new(self(), 0))
      state
    else
      start_steal_timer(state)
    end
  end

  defp calculate_load(state) do
    if :queue.len(state.task_queue) > 0 do
      temp = Enum.reduce(:queue.to_list(state.task_queue), fn x, y -> %{duration: x.duration + y.duration} end)
      temp.duration
    else
      0
    end
  end

  defp work_shed(state) do
    load = calculate_load(state)
    # if :queue.len(state.task_queue) > 4 do
    if load > 750 do
      IO.puts("#{inspect(self())} triggered work shedding")
      load = Enum.reduce(
        :queue.to_list(state.task_queue),
        fn x, y -> %{duration: x.duration + y.duration} end
      )
      sch = Enum.random(state.schedulers)
      send(sch, WorkShed.RequestRPC.new(self(), load.duration))
      state
    else
      start_shed_timer(state)
    end
  end

  def start do
    state = init()
    state = start_schedule_timer(state)
    Util.timer(@slack_timeout, :slack)

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

      {:update_schedulers, schedulers} ->
        state = %{state | schedulers: schedulers}
        # IO.puts("#{inspect(self())} stored: #{inspect(schedulers)}")
        run(state)

      %WorkSteal.RequestRPC{
        node: node,
        load: load
      } ->
        num_jobs = :queue.len(state.task_queue)
        state = if num_jobs > 1 do
          # IO.puts("#{inspect(self())} agreed to steal}")
          half_n = ceil(num_jobs/2)
          {task_queue, steal_payload} = :queue.split(half_n, state.task_queue)
          send(node, WorkSteal.ReplyRPC.new(self(), true, steal_payload))
          %{state | task_queue: task_queue}
        else
          send(node, WorkSteal.ReplyRPC.new(self(), false, nil))
          state
        end
        run(state)

      %WorkSteal.ReplyRPC{
        node: node,
        accept: accept,
        payload: payload
      } ->
        # IO.puts("#{inspect(self())} received steal reply #{accept} from #{inspect(node)}")

        state = if accept do
          %{state | task_queue: :queue.join(state.task_queue, payload)}
        else
          state
        end
        state = start_steal_timer(state)
        run(state)

      %WorkShed.RequestRPC{
        node: node,
        load: load
      } ->
        my_load = calculate_load(state)
        if my_load <= load/2 do
          IO.puts("#{inspect(self())} accepted shedding from #{inspect(node)}. Triggered Steal.")

          send(
            node,
            WorkShed.ReplyRPC.new(self(), true)
          )
          send(
            node,
            WorkSteal.RequestRPC.new(self(), 0)
          )
        else
          send(
            node,
            WorkShed.ReplyRPC.new(self(), false)
          )
        end
        run(state)

      %WorkShed.ReplyRPC{
        node: node,
        accept: accept
      } ->
        state = start_shed_timer(state)
        run(state)

      :steal_timeout ->
        state = stop_steal_timer(state)
        state = work_steal(state)
        run(state)

      :shed_timeout ->
        state = stop_shed_timer(state)
        state = work_shed(state)
        run(state)

      :slack ->
        state = case @balance_type do
          :steal ->
            start_steal_timer(state)
          :shed ->
            start_shed_timer(state)
          _ ->
            state
        end

        run(state)
    end
  end
end
