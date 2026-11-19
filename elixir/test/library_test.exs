defmodule LibraryTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @borrow if System.get_env("BUGGY") == "1", do: :borrow_buggy, else: :borrow

  # The same property as `NeverOverLent` in TLA+ and `never_over_lent` in Lean.
  # StreamData picks the number of copies and a random list of borrows and
  # returns by 10 patrons, then runs them one at a time against the real code.
  property "never lends out more copies than it owns" do
    check all copies <- integer(1..5),
              steps <- list_of(tuple({member_of([@borrow, :return]), integer(1..10)})) do
      {:ok, library} = Library.start_link(copies)

      for {step, patron} <- steps do
        apply(Library, step, [library, patron])
        assert MapSet.size(Library.loans(library)) <= copies
      end
    end
  end

  # The same size TLC checks: 1 copy, 2 patrons, borrowing at the same time.
  test "2 patrons at once never get more than 1 copy" do
    {:ok, library} = Library.start_link(1)

    [:socrates, :beelzebub]
    |> Task.async_stream(&apply(Library, @borrow, [library, &1]))
    |> Stream.run()

    assert MapSet.size(Library.loans(library)) <= 1
  end
end
