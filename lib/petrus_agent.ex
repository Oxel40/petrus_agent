defmodule PetrusAgent do
  @moduledoc """
  Documentation for `PetrusAgent`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> PetrusAgent.hello()
      :world

  """
  def hello do
    :world
  end
end

defmodule PetrusAgent.Client do
  use WebSockex

  def start_link(state) do
    {:ok, pid} = WebSockex.start_link("ws://localhost:4000/test/websocket", __MODULE__, state)
    # {:ok, pid} = WebSockex.start_link("wss://flying-petrus.fly.io/test/websocket", __MODULE__, state)
    #WebSockex.send_frame(pid, {:text, inspect state})
    {:ok, pid}
  end

  def handle_frame({:binary, _bin}, state) do
    IO.puts "Received binary for printing"
    {:ok, state}
  end

  def handle_frame({type, msg}, state) do
    IO.puts "Received Message - Type: #{inspect type} -- Message: #{inspect msg}"
    #Process.sleep 1000
    #state_ = state+1
    #{:reply, {:text, inspect state_}, state_}
    {:ok, state}
  end
end

defmodule PetrusAgent.Application do
  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("starting")
    children = [
      {PetrusAgent.Client, 0}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
