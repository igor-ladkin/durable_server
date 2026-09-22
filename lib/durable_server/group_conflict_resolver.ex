defmodule DurableServer.GroupConflictResolver do
  @moduledoc false

  _ = """
  DurableServer-specific conflict resolution for group registry conflicts.

  When a network partition heals or race conditions occur, multiple processes may
  have claimed the same key. DurableServers use object storage as the ownership
  authority: every successful lock acquisition advances a monotonically increasing
  lock epoch in the same conditional write that acquires the lock.

  Current Group conflict resolvers are pure rank functions. Ranking by lock epoch
  lets Group retain the latest successful storage claimant and authoritatively
  retire only stale owners after validating its replicated view. The current
  resolver must not terminate either claimant: doing so before Group commits the
  losing unregister can create a repeated anti-entropy death loop.

  The legacy pairwise Group API delegates loser termination to the resolver. Its
  compatibility callback uses the same deterministic rank and terminates only
  the loser, never both owners.

  This module is registered as the `:resolve_registry_conflict` callback for
  Group instances started by DurableServer.Supervisor.
  """

  alias DurableServer.GroupMeta

  def resolve(_name, _key, {pid, %GroupMeta{} = meta, time}) do
    {Map.get(meta, :lock_epoch, 0), time, pid}
  end

  def resolve(_name, _key, {pid, _meta, time}), do: {0, time, pid}

  # Compatibility with Group 0.2.x's pairwise resolver API, which expects a
  # custom resolver to terminate the loser itself. Both sides compute the same
  # winner, so only the stale owner is ever terminated.
  def resolve(name, key, {pid1, meta1, _time1} = claim1, {pid2, meta2, _time2} = claim2) do
    {winner_pid, winner_meta, loser_pid} =
      if resolve(name, key, claim2) > resolve(name, key, claim1) do
        {pid2, meta2, pid1}
      else
        {pid1, meta1, pid2}
      end

    Process.exit(loser_pid, {:group_registry_conflict, key, winner_meta})
    winner_pid
  end
end
