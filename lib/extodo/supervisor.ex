defmodule Extodo.Supervisor do

  def start(module, arguments) do
    spawn(__MODULE__, :init, [{module, arguments}])
  end

  def start_link(module, arguments) do
    spawn_link(__MODULE__, :init, [{module, arguments}])
  end

  def init({module, arguments}) do
    Process.flag(:trap_exit, :true)
    loop({module, :start_link, arguments})
  end

  def loop({module, fun, arguments}) do
    pid = apply(module, fun, arguments)

    receive do 
      { :EXIT, _from, :shutdown } ->
        # NOTE: This will kill the child too!
        exit(:shutdown)
      { :EXIT, ^pid, reason } ->
        IO.puts "Process #{inspect pid} exited for reason #{reason}."
        loop({module, fun, arguments})
    end
  end

end
