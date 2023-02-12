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
    {code, pid} = WebSockex.start_link("ws://localhost:4000/test/websocket", __MODULE__, state)
    # {code, pid} =
    #   WebSockex.start_link("wss://flying-petrus.fly.io/test/websocket/", __MODULE__, state,
    #     debug: [:trace]
    #   )

    case code do
      :ok ->
        {:ok, pid}

      _ ->
        IO.inspect(pid)
        {code, pid}
    end

    # WebSockex.send_frame(pid, {:text, inspect state})
    # {:ok, pid}
  end

  def handle_frame({:binary, _bin}, state) do
    IO.puts("Received binary for printing")
    {:ok, state}
  end

  def handle_frame({:text, "op-printer-status"}, state) do
    IO.puts("Received binary for printing")
    {:ok, state}
  end

  def handle_frame({type, msg}, state) do
    IO.puts("Received Message - Type: #{inspect(type)} -- Message: #{inspect(msg)}")
    # Process.sleep 1000
    # state_ = state+1
    # {:reply, {:text, inspect state_}, state_}
    {:ok, state}
  end
end

defmodule PetrusAgent.Application do
  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("starting")

    children = [
      # {PetrusAgent.Client, 0}
      # GenServer.start_link(PetrusAgent.GunClient, {'flying-petrus.fly.dev', 443, '/test/websocket'}
      {PetrusAgent.GunClient, {'flying-petrus.fly.dev', 443, '/test/websocket'}}
      # {PetrusAgent.GunClient, {'localhost', 4000, '/test/websocket'}}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, debug: [:trace])
  end
end

defmodule PetrusAgent.GunClient do
  use GenServer
  require Logger

  def ws_upgrade({host, port, path}) do
    {:ok, gun_pid} = :gun.open(host, port, %{protocols: [:http]})
    {:ok, _protocol} = :gun.await_up(gun_pid)
    stream_ref = :gun.ws_upgrade(gun_pid, path)
    Logger.info("Trying to upgrade to websocket")

    %{uri: {host, port, path}, gun_pid: gun_pid, stream_ref: stream_ref}
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init({host, port, path}) do
    Logger.info("Websocket client started")

    {:ok, ws_upgrade({host, port, path})}
  end

  def handle_info(
        {:gun_upgrade, _pid, _stream, ["websocket"], headers},
        state
      ) do
    Logger.info("Upgraded successfully!\nHeaders:\n#{inspect(headers)}")

    send(self(), {:send_status, 5000})
    {:noreply, state}
  end

  def handle_info({:gun_up, _pid, protocol}, state) do
    Logger.info("Receved gun_up over #{inspect(protocol)}")
    {:noreply, state}
  end

  def handle_info(
        {:gun_down, _pid, protocol, reason, _killed_streams},
        state
      ) do
    Logger.info("Receved gun_down over #{inspect(protocol)}, reason: #{inspect(reason)}")
    # Try reestablish websocket connection
    # {:noreply, ws_upgrade(uri)}
    {:error, state}
  end

  def handle_info({:send_status, timedelay}, state) do
    if timedelay > 0 do
      parrent_pid = self()

      Task.start(fn ->
        Process.sleep(timedelay)
        send(parrent_pid, {:send_status, timedelay})
      end)
    end

    {status, _exit_code} = System.cmd("lpstat", ["-t"])
    :gun.ws_send(state[:gun_pid], state[:stream_ref], {:text, status})

    {:noreply, state}
  end

  def handle_info({:gun_ws, _pid, _stream, frame}, state) do
    Logger.info("Receved gun_ws, frame: #{inspect(frame)}")
    handle_frame(frame)
    {:noreply, state}
  end

  defp handle_frame({:binary, bin}) do
    hash = :crypto.hash(:md5, bin) |> Base.encode16()
    path = "/tmp/" <> hash <> ".pdf"
    File.write!(path, bin)
    Logger.info(inspect(System.cmd("lp", [path])))
    File.rm!(path)
  end

  defp handle_frame({:text, "clear queue"}) do
    Logger.info("clearing queue: " <> inspect(System.cmd("cancel", ["-a"])))
    send(self(), {:send_status, 0})
  end
end
