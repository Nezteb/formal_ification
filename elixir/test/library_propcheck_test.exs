defmodule LibraryPropCheckTest do
  # The same test as `library_proper_test.exs`, written with PropCheck, the
  # Elixir wrapper for PropEr. The Agent has a registered name, so this file
  # can't run async.
  use ExUnit.Case
  # `property` and `forall` macros, and generators like `oneof/1`.
  use PropCheck
  # `parallel_commands/1` and `run_parallel_commands/2`.
  use PropCheck.StateM

  @library __MODULE__.Library
  @patrons [:socrates, :beelzebub]

  # PropEr runs a few random commands, then two command lists at the same
  # time. It passes only if some one-at-a-time order of the parallel calls
  # explains every result, according to the model below.
  #
  # PropEr's `proper_statem` docs, under "Parallel testing", suggest adding
  # `:erlang.yield()` to the code under test, because the BEAM scheduler can be
  # too predictable to hit a race. This demo doesn't need it. PropEr tries up
  # to 100 cases and finds this race without it.
  #
  # PropCheck prints the counterexample as Elixir calls, saves it to
  # `_build/propcheck.ctex`, and replays it first on the next run.
  #
  # `collect` records whether both parallel branches borrow, the only kind of
  # test case that can expose the race. Run with `PROPCHECK_VERBOSE=1` to see
  # the percentages. If `true` is near 0%, the generator isn't reaching the race.
  property "2 patrons borrowing in parallel never get more than 1 copy" do
    forall cmds <- parallel_commands(__MODULE__) do
      {:ok, _} = Library.start_link(1, name: @library)
      {_sequential, _parallel, result} = run_parallel_commands(__MODULE__, cmds)
      Agent.stop(@library)
      collect(result == :ok, both_branches_borrow: both_branches_borrow?(cmds))
    end
  end

  # The model says what the library should do, one call at a time. Its state is
  # the set of patrons with a copy, like `loans` in the TLA+ spec.
  def initial_state, do: MapSet.new()

  def command(_loans) do
    oneof([
      {:call, __MODULE__, :borrow, [oneof(@patrons)]},
      {:call, Library, :return, [@library, oneof(@patrons)]}
    ])
  end

  def precondition(_loans, _call), do: true

  def next_state(loans, _result, {:call, _, :borrow, [p]}) do
    if available?(loans, p), do: MapSet.put(loans, p), else: loans
  end

  def next_state(loans, _result, {:call, _, :return, [_, p]}), do: MapSet.delete(loans, p)

  # The postconditions check the error cases too. A borrow with no copy left
  # must return `{:error, :unavailable}`, and returning a book you don't have
  # must return `{:error, :not_borrowed}`.
  def postcondition(loans, {:call, _, :borrow, [p]}, result) do
    result == if(available?(loans, p), do: :ok, else: {:error, :unavailable})
  end

  def postcondition(loans, {:call, _, :return, [_, p]}, result) do
    result == if(p in loans, do: :ok, else: {:error, :not_borrowed})
  end

  def borrow(patron) do
    borrow = if System.get_env("BUGGY") == "1", do: :borrow_buggy, else: :borrow
    apply(Library, borrow, [@library, patron])
  end

  # With 1 copy, a patron can borrow only if nobody has it and they don't already.
  defp available?(loans, p), do: MapSet.size(loans) < 1 and p not in loans

  defp both_branches_borrow?({_sequential, [left, right]}), do: borrows?(left) and borrows?(right)
  defp both_branches_borrow?(_cmds), do: false

  defp borrows?(branch), do: Enum.any?(branch, &match?({:set, _, {:call, _, :borrow, _}}, &1))
end
