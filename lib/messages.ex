defmodule Job.Payload do
  defstruct(
    client: nil,
    scheduler: nil,
    id: nil,
    arrival_time: nil,
    duration: nil,
    start_time: nil,
    finish_time: nil
  )

  def new(
    client,
    job_id,
    duration) do
    %Job.Payload {
      client: client,
      scheduler: nil,
      id: job_id,
      duration: duration,
      start_time: nil,
      finish_time: nil
    }
  end

  def random_large(client, job_id) do
      %Job.Payload {
        client: client,
        scheduler: nil,
        id: job_id,
        arrival_time: 0,
        duration: Enum.random(100..400),
        start_time: nil,
        finish_time: nil
      }
  end

  def random_small(client, job_id) do
    %Job.Payload {
      client: client,
      scheduler: nil,
      id: job_id,
      arrival_time: 0,
      duration: Enum.random(100..400),
      start_time: nil,
      finish_time: nil
    }
  end
end

defmodule Job.Creation.RequestRPC do
  defstruct(
    scheduler: nil,
    job: nil
  )

  def new(scheduler, job) do
    %Job.Creation.RequestRPC{
      scheduler: scheduler,
      job: job
    }
  end
end

defmodule Job.Creation.ReplyRPC do
  defstruct(
    node: nil,
    accept: nil,
    job: nil
  )

  def new(node, accept, job) do
    %Job.Creation.ReplyRPC{
      node: node,
      accept: accept,
      job: job
    }
  end
end

defmodule Resource.ReleaseRPC do
  defstruct(
    node: nil,
    job: nil
  )

  def new(node, job) do
    %Resource.ReleaseRPC{
      node: node,
      job: job
    }
  end
end

defmodule Register.RequestRPC do
  defstruct(
    node: nil
  )

  def new(pid) do
    %Register.RequestRPC{
      node: pid
    }
  end
end
defmodule Register.ReplyRPC do
  defstruct(
    scheduler: nil,
    success: nil
  )

  def new(pid, success) do
    %Register.ReplyRPC{
      scheduler: pid,
      success: success
    }
  end
end


defmodule WorkSteal.RequestRPC do
  defstruct(
    node: nil,
    load: nil
  )

  def new(node, load) do
    %WorkSteal.RequestRPC{
      node: node,
      load: load
    }
  end
end

defmodule WorkSteal.ReplyRPC do

  defstruct(
    node: nil,
    accept: nil,
    payload: nil
  )

  def new(node, accept, payload) do
    %WorkSteal.ReplyRPC{
      node: node,
      accept: accept,
      payload: payload
    }
  end
end

defmodule WorkShed.RequestRPC do
  defstruct(
    node: nil,
    load: nil
  )

  def new(node, load) do
    %WorkShed.RequestRPC{
      node: node,
      load: load
    }
  end
end

defmodule WorkShed.ReplyRPC do
  defstruct(
    node: nil,
    accept: nil
  )

  def new(node, accept) do
    %WorkShed.ReplyRPC{
      node: node,
      accept: accept
    }
  end
end
