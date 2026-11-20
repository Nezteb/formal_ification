defmodule LibraryStreamDataTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  setup do
    %{borrow: if(System.get_env("BUGGY") == "1", do: :borrow_buggy, else: :borrow)}
  end

  # The same property as `NeverOverLent` in TLA+ and `never_over_lent` in Lean.
  # StreamData picks the number of copies and a random list of borrows and
  # returns by 10 patrons, then runs them one at a time against the real code.
  # It never runs two borrows at once, so it passes on the buggy code.
  property "never lends out more copies than it owns", %{borrow: borrow} do
    check all copies <- integer(1..5),
              steps <- list_of(tuple({member_of([borrow, :return]), integer(1..10)})) do
      library = start_supervised!({Library, copies}, id: make_ref())

      for {step, patron} <- steps do
        apply(Library, step, [library, patron])
        assert MapSet.size(Library.loans(library)) <= copies
      end
    end
  end
end
