# Extodo

###Yet another TODO App … but, but in Elixir!

This is basically a more or less faithful port the example application of Chapter 13 of Fred Hebert's excellent [Learn You Some Erlang for Great Good!](http://learnyousomeerlang.com/) book.

###Rough Notes:

__NOTE__: What follows are my rough notes as I work through the chapter.

Page 182:

`iex -S mix`

`spawn(Extodo.Event, :loop, [State[server: self, name: "test", to_go: 5]])`

```
iex> pid = spawn(Extodo.Event, :loop, [State[server: self, name: "test", to_go: 500]])
#PID<0.106.0>
iex> reply_ref = make_ref()
#Reference<0.0.0.900>
iex> pid <- { self, reply_ref, :cancel }
{#PID<0.65.0>, #Reference<0.0.0.900>, :cancel}
iex> flush
{#Reference<0.0.0.900>, :ok}
:ok
```

* Check out what are references
* One reason we are using references is to make sure that we are receiving the response from the correct process/

Page 185:

```
iex> c("lib/extodo/event.ex")
Extodo.Event
[Extodo.Event, State]
iex> Extodo.Event.start("Event", 0)
#PID<0.211.0>
iex> flush()
{:done, "Event"}
:ok
iex> pid = Extodo.Event.start("Event", 0)
#PID<0.76.0>
iex> Extodo.Event.cancel(pid)
:ok
```

Page 186

```
iex>   #PID<0.105.0>
iex> flush
{:done, "Drink Beer"}
:ok
```
Page 194

```
Extodo.EventServer.start_link # Note to self. Why you cannot start_link a second time? Because a process name can only be used once. Duh.
Extodo.EventServer.subscribe(self)
# Note: All dates must be in the future, otherwise the calculated timeout is a negative value.
Extodo.EventServer.add_event("Hey There", "test", {{2013, 9, 5}, {0, 30, 00}})
```

Page 195
```
iex> sup_pid = Extodo.Supervisor.start(Extodo.EventServer, [])
# Notice that the sup_pid and event server pid are different. Obviously.
iex> Process.whereis(Extodo.EventServer)
iex> Process.exit(Process.whereis(Extodo.EventServer), :die)
Process #PID<0.70.0> exited for reason die.
# And … Keep going …
iex> Process.exit(Process.whereis(Extodo.EventServer), :'live and let die')
Process #PID<0.71.0> exited for reason live and let die.
iex> Process.exit(Process.whereis(Extodo.EventServer), :kaboom)
Process #PID<0.72.0> exited for reason kaboom.
```
But if we kill the supervisor:

```
# Do you know why we can't do this? Because it is not registered!
iex> Process.whereis(Extodo.Supervisor)
nil
Process.whereis(sup_pid)
iex> Process.exit(sup_pid, :shutdown)
true
# Kill the supervisor, and the event server process gets killed too.
iex> Process.whereis(Extodo.EventServer)
nil
```