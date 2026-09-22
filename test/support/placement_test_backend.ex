defmodule DurableServer.PlacementTestBackend do
  @moduledoc """
  Node-local storage for placement tests that do not need object storage.

  Only the selected remote node has child capacity in these tests, so all
  durable child writes go to that node's table. This is not a distributed
  storage implementation and must not be used to test competing claims.
  """
  @behaviour DurableServer.StorageBackend

  @impl true
  def init_backend(_opts) do
    {:ok,
     %{
       state: :ets.new(__MODULE__, [:set, :public]),
       defaults: %{
         heartbeat_tracking_mode: :poll,
         discovery_interval_ms: 60_000,
         heartbeat_interval_ms: 10_000,
         heartbeat_reconcile_interval_ms: 10_000
       }
     }}
  end

  @impl true
  def ensure_ready(_table), do: :ok

  @impl true
  def get_object(table, key, _opts) do
    case :ets.lookup(table, key) do
      [{^key, object}] -> {:ok, object}
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def put_object(table, key, body, _opts) do
    object = %{body: body, etag: etag()}
    true = :ets.insert(table, {key, object})
    {:ok, %{etag: object.etag}}
  end

  @impl true
  def try_claim(table, key, body) do
    object = %{body: body, etag: etag()}

    if :ets.insert_new(table, {key, object}),
      do: {:ok, {:claimed, object.etag}},
      else: {:error, :taken}
  end

  @impl true
  def update_object(table, key, fun, opts) do
    with {:ok, object} <- get_object(table, key, opts),
         {:ok, body} <- fun.(object) do
      put_object(table, key, body, opts)
    end
  end

  @impl true
  def delete_object(table, key) do
    case :ets.take(table, key) do
      [] -> {:error, :not_found}
      [_object] -> :ok
    end
  end

  @impl true
  def list_all_objects_stream(table, prefix, _opts) do
    table
    |> :ets.tab2list()
    |> Stream.filter(fn {key, _object} -> String.starts_with?(key, prefix) end)
    |> Stream.map(fn {key, object} -> %{key: key, etag: object.etag} end)
  end

  @impl true
  def encode(_table, value), do: {:ok, value}

  @impl true
  def decode(_table, value), do: {:ok, value}

  defp etag, do: Integer.to_string(System.unique_integer([:positive, :monotonic]))
end
