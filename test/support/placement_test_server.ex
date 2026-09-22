defmodule DurableServer.PlacementTestServer do
  @moduledoc false
  use DurableServer, vsn: 1

  # Keep the remote supervisor alive after the short-lived RPC worker exits.
  def start_supervisor(opts) do
    {:ok, pid} = DurableServer.Supervisor.start_link(opts)
    Process.unlink(pid)
    {:ok, pid}
  end

  @impl true
  def init(state, info) do
    if state[:blocked] do
      send(state.observer, {:bootstrap_started, info.key, self()})

      receive do
        :finish_bootstrap -> :ok
      end
    end

    {:ok, state}
  end

  @impl true
  def dump_state(state), do: state

  @impl true
  def load_state(_vsn, state), do: state
end
