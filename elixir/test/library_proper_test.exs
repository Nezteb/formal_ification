defmodule LibraryProperTest do
  # The same test as `library_propcheck_test.exs`, written with PropEr's Erlang
  # modules, called from Elixir with no wrapper. The Agent has a registered
  # name, so this file can't run async.
  use ExUnit.Case

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
  # Elixir can't use Erlang's `?FORALL` macro, so this calls `:proper.forall/2`,
  # the function the macro expands to. `:proper.quickcheck/2` returns `true` or
  # `false`, and `:proper.counterexample/0` returns the last failing case as
  # Erlang terms. Nothing is saved between runs.
  #
  # `:proper.collect/2` records whether both parallel branches borrow, the only
  # kind of test case that can expose the race. Remove `:quiet` to see the
  # percentages. If `true` is near 0%, the generator isn't reaching the race.
  test "2 patrons borrowing in parallel never get more than 1 copy" do
    property =
      :proper.forall(:proper_statem.parallel_commands(__MODULE__), fn cmds ->
        {:ok, _} = Library.start_link(1, name: @library)
        {_sequential, _parallel, result} = :proper_statem.run_parallel_commands(__MODULE__, cmds)
        Agent.stop(@library)
        :proper.collect([both_branches_borrow: both_branches_borrow?(cmds)], result == :ok)
      end)

    assert :proper.quickcheck(property, [:quiet]), inspect(:proper.counterexample())
  end

  # The model says what the library should do, one call at a time. Its state is
  # the set of patrons with a copy, like `loans` in the TLA+ spec.
  def initial_state, do: MapSet.new()

  def command(_loans) do
    :proper_types.oneof([
      {:call, __MODULE__, :borrow, [:proper_types.oneof(@patrons)]},
      {:call, Library, :return, [@library, :proper_types.oneof(@patrons)]}
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
