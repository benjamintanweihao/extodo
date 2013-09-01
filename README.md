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
iex> pid = Extodo.Event.start("Drink Beer", :calendar.local_time)
#PID<0.105.0>
iex> flush
{:done, "Drink Beer"}
:ok
```