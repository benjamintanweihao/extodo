defmodule Extodo.EventServer do
  defrecord State, events: :orddict.new, clients: :orddict.new 
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
    IO.puts "Subscribing ..."

    ref = Process.whereis(__MODULE__) |> Process.monitor
    __MODULE__ <- { self, ref, { :subscribe, pid } }

    receive do
      { ^ref, :ok } ->
        { :ok, ref }
      { :DOWN, ^ref, :process, _pid, reason } ->
        { :error, reason }
      after 5000 ->
        { :error, :timeout }
    end
  end

  def add_event(name, description, time_out) do
    IO.puts "Adding Event ... #{name} #{description}"

    ref = make_ref
    __MODULE__ <- { self, ref, { :add, name, description, time_out } }

    receive do
      { ^ref, msg } -> msg
    after 5000 ->
      { :error, :timeout }
    end
  end

  def cancel(name) do
    ref = make_ref
    __MODULE__ <- { self, ref, { :cancel, name } }
    receive do
      { ^ref, :ok } -> :ok
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
    IO.puts "Just looooopppeeed"
    IO.puts "What is state?"
    IO.inspect state

    receive do
      { pid, msg_ref, { :subscribe, client } } -> 
        ref = Process.monitor(client)
        new_clients = :orddict.store(ref, client, state.clients)
    
        IO.puts "Received subscribed. Here's the client list:"
        IO.inspect new_clients

        pid <- { msg_ref, :ok }
        loop(State[clients: new_clients])
        
      { pid, msg_ref, { :add, name, description, time_out } } -> 
        case valid_datetime(time_out) do
          true ->
            event_pid = Extodo.Event.start_link(name, time_out)
            new_events = :orddict.store(name, Event[name: name,
                                             description: description,
                                                     pid: event_pid,
                                                 timeout: time_out], state.events)
            pid <- { msg_ref, :ok }

            new_state = state.events new_events
            loop(new_state)

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
  
        new_state = state.events events
        loop(new_state)

      { :done, name } ->
        IO.puts "Received :done"

        case :orddict.find(name, state.events) do
          { :ok, e } ->
            IO.puts "WHAT IS THE STATE?"
            IO.inspect state

            send_to_clients({ :done, e.name, e.description }, state.clients )

            new_events = :orddict.erase(name, state.events)
            new_state  = state.events new_events
            loop(new_state)
          :error ->
            # This may happen if we cancel an event and it fires at the same time
            loop(state)
        end
         
      :shutdown -> 
        exit(:shutdown) 
    
      { :DOWN, ref, :process, _pid, _reason } ->
        new_state = state.clients :orddict.erase(ref, state.clients)     
        loop(new_state)     
    
      :code_change ->
        __MODULE__.loop(state)  

      unknown ->
        IO.puts "Unknown message: #{unknown}"
        loop(state)
    end
  end

  def init do 
    IO.puts "Initializing ...."
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

  def valid_time({ h, m, s }) do
    valid_time(h, m, s)
  end

  def valid_time(h, m, s) do
    Enum.member?(0..24, h) and Enum.member?(0..60, m) and Enum.member?(0..60, s)
  end

  def send_to_clients(msg, client_dict) do
    IO.puts "Sending to clients ..."
    IO.inspect client_dict
    :orddict.map(fn(_ref, pid) -> pid <- msg end, client_dict)
  end 

  def listen(delay) do
    receive do
      m = { :done, _name, _description } -> 
            [m|listen(0)]
    after delay * 1000 ->
      []
    end
  end
end
