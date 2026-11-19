defmodule LibraryTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @borrow if System.get_env("BUGGY") == "1", do: :borrow_buggy, else: :borrow

  # The same property as `NeverOverLent` in TLA+ and `never_over_lent` in Lean.
  # StreamData picks the number of copies and a random list of borrows and
  # returns, then runs them one at a time against the real code.
  property "never lends out more copies than it owns" do
    check all copies <- integer(1..5),
              ops <- list_of(member_of([:borrow, :give_back])) do
      {:ok, library} = Library.start_link(copies)

      Enum.reduce(ops, 0, fn
        :borrow, on_loan ->
          on_loan = if apply(Library, @borrow, [library]) == :ok, do: on_loan + 1, else: on_loan
          assert on_loan <= copies
          on_loan

        :give_back, 0 ->
          0

        :give_back, on_loan ->
          Library.give_back(library)
          on_loan - 1
      end)
    end
  end

  test "50 patrons at once never get more than 1 copy" do
    {:ok, library} = Library.start_link(1)

    winners =
      1..50
      |> Task.async_stream(fn _ -> apply(Library, @borrow, [library]) end)
      |> Enum.count(&(&1 == {:ok, :ok}))

    assert winners == 1
  end
end
