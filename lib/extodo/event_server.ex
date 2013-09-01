defmodule Extodo.EventServer do
  defrecord State, events: nil, clients: nil 
  defrecord Event, name: "", description: "", pid: nil, timeout: {{1970,1,1},{0,0,0}}

  ########################################
  # INTERFACE |> HIDE HIDE YOUR MESSAGES #
  ########################################
  
  def start do
    Process.register(pid = spawn(__MODULE__, :init, []), __MODULE__)
    pid
  end

  def start_link do
    Process.register(pid = spawn_link(__MODULE__, :init, []), __MODULE__) 
    pid
  end
  
  def terminate do
    __MODULE__ <- :shutdown
  end

  def subscribe(pid) do
    ref = Process.whereis(__MODULE__) |> Process.monitor
    __MODULE__ <- { self, ref, { :subscribe, pid } }

    receive do
      { ref, :ok } ->
        { :ok, ref }
      { :DOWN, _ref, :process, _pid, reason } ->
        { :error, reason }
      after 5000 ->
        { :error, :timeout }
    end
  end

  def add_event(name, description, time_out) do
    ref = make_ref
    __MODULE__ <- { self, ref, { :add, name, description, time_out } }

    receive do
      { _ref, msg } -> msg
    after 5000 ->
      { :error, :timeout }
    end
  end

  def cancel(name) do
    ref = make_ref
    __MODULE__ <- { self, ref, { :cancel, name } }
    receive do
      { _ref, :ok } -> :ok
    after 5000 ->
      { :error, :timeout }
    end
  end

  def listen(delay) do
    receive do
      m = { :done, _name, _description } ->
            [m|listen(0)]
    after delay * 1000 ->
      []
    end
  end

  def loop(state) do
    receive do
      { pid, msg_ref, { :subscribe, client } } -> 
        ref = Process.monitor(client)
        new_clients = :orddict.store(ref, client, state.clients)
        pid <- { msg_ref, :ok }
        loop(State[clients: new_clients])
        
      { pid, msg_ref, { :add, name, description, time_out } } -> 
        case valid_datetime(time_out) do
          true ->
            event_pid = Extodo.Event.start_link(name, time_out)
            new_events = :orddict.store(name, Event[name: name,
                                             description: description,
                                                     pid: event_pid,
                                                 timeout: time_out])
            pid <- { msg_ref, :ok }
            loop(State[events: new_events])
          false ->
            pid <- { msg_ref, { :error, :bad_timeout } }
            loop(state)
        end 
        
      { pid, _msg_ref, { :cancel, name } } -> 
        events = case :orddict.find(name, state.events) do
                   { :ok, e } ->
                    Extodo.Event.cancel(e.event.pid)
                    :orddict.erase(name, state.events)
                   :error ->
                     state.events
                 end
        pid <- { :msg_ref, :ok }
        loop(State[events: events])

      { :done, name } ->
        case :orddict.find(name, state.events) do
          { :ok, e } ->
            send_to_clients({ :done, e.event.name, e.event.description }, state.clients )
            new_events = :orddict.erase(name, state.events)
            loop(State[events: new_events])
          :error ->
            # This may happen if we cancel an event and it fires at the same time
            loop(state)
        end
         
      :shutdown -> 
        exit(:shutdown) 
    
      { :DOWN, ref, :process, _pid, _reason } ->
        loop(State[clients: :orddict.erase(ref, state.clients)])     
    
      :code_change ->
        __MODULE__.loop(state)  

      unknown ->
        IO.puts "Unknown message: #{unknown}"
        loop(state)
    end
  end

  def init do 
    loop(State[events: :orddict.new, clients: :orddict.new])
  end
  
  def valid_datetime({ date, time }) do
    try do
      :calendar.valid_date(date) and valid_time(time) 
    catch
      _ -> IO.puts "WRONG FORMAT"   
    end
  end

  def valid_datetime(_) do
    false
  end

  def valid_time({H,M,S}) do
    valid_time(H,M,S)
  end

  def valid_time(H,M,S) when H >= 0 and H < 24 and 
                             M >= 0 and M < 60 and 
                             S >= 0 and S < 60 do
    true
  end

  def valid_time(_,_,_) do
    false
  end

  def send_to_clients(msg, client_dict) do
    :orddict.map(fn(_ref, pid) -> pid <- msg end, client_dict)
  end 

end
