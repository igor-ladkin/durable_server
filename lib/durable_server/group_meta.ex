defmodule DurableServer.GroupMeta do
  @moduledoc false

  # The internal metadata stored in Group registry
  defstruct key: nil,
            module: nil,
            storage_key: nil,
            lock_epoch: 0,
            node_ref: nil,
            start_time: nil,
            user_meta: nil,
            supervisor: nil
end
