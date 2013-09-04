defmodule Extodo.Event do
  defrecord State, server: nil, name: "", to_go: 0
  #############
  # INTERFACE #
  #############

  def start(event_name, delay) do
    spawn(__MODULE__, :init, [self, event_name, delay])
  end

  def start_link(event_name, delay) do
    spawn_link(__MODULE__, :init, [self, event_name, delay])
  end

  # event's innards
  def init(server, event_name, date_time) do
    loop(State[server: server, name: event_name, to_go: time_to_go(date_time)])
  end

  def cancel(pid) do
    # monitor in case the process is already dead.

    # NOTE:
    # We are using monitor to check if the process is already dead.
    # If it is, we simply return ok. 
    # Otherwise, the ref will be returned.
    ref = Process.monitor(pid)
    pid <- { self, ref, :cancel }

    receive do
      { ^ref, :ok } -> 
        Process.demonitor(ref, [:flush])
        :ok
      { :DOWN, _ref, :process, _pid, _reason } ->
        :ok
    end
  end

  # NOTE: We need State[server: server] because we want to pattern match
  #       `server` in the 'after' block.
  def loop(state = State[server: server, to_go: [t|next]]) do
    receive do
      { ^server, ref, :cancel } -> 
        server <- { ref, :ok } 
    after t*1000 ->
      case next do
        [] -> 
          # This message is sent to EventServer
          server <- { :done, state.name }
        _ ->
          new_state = state.to_go next
          loop(new_state) 
      end
    end
  end

  def time_to_go(time_out = {{_,_,_}, {_,_,_}}) do
    now   = :calendar.local_time
    to_go = :calendar.datetime_to_gregorian_seconds(time_out) - 
            :calendar.datetime_to_gregorian_seconds(now)
    secs  = if to_go > 0 do
              to_go
            else
              0
            end
    normalize(secs)
  end

  def normalize(n) do
    limit = 49*24*60*60
    [rem(n, limit) | List.duplicate(limit, div(n, limit))]
  end
end
