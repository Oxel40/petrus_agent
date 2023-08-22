defmodule PetrusAgent do
end

defmodule PetrusAgent.Application do
  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("starting")

    {:ok, _} = Application.ensure_all_started(:gun)

    children = [
      {PetrusAgent.Client, Application.fetch_env!(:petrus_agent, :url)}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, debug: [:trace])
  end
end

defmodule PetrusAgent.Client do
  use GenServer
  require Logger

  def ws_upgrade({host, port, path}) do
    Logger.info("Open connection to #{host} on port #{port}")

    {:ok, gun_pid} = :gun.open(host, port, %{tls_opts: [verify: :verify_none]})

    gun_pid
    |> :gun.info()
    |> inspect()
    |> Logger.info()

    {:ok, _protocol} = :gun.await_up(gun_pid)

    Logger.info("Trying to upgrade to websocket at #{path}")

    stream_ref =
      :gun.ws_upgrade(gun_pid, path, [
        {~c"x-printer-auth", secret()}
      ])

    Logger.info("Done")
    
    %{uri: {host, port, path}, gun_pid: gun_pid, stream_ref: stream_ref}
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init({host, port, path}) do
    Logger.info("Websocket client started")
    Logger.info("Connecting to: #{inspect({host, port, path})}")

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

  defp secret do
    Application.fetch_env!(:petrus_agent, :agent_secret)
  end
end
