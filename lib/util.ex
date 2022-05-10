defmodule Util do
  import Kernel

  def timer(timeout, msg) do
    Process.send_after(self(), msg, timeout)
  end

  def cancel_timer(obj) do
    Process.cancel_timer(obj)
  end

  defp register(pid, name) do
    Process.register(pid, name)
  end

  def spawn(name, func) do
    pid = spawn(name, func)
    Process.register(pid, name)
  end
end
