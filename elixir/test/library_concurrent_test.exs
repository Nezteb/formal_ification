defmodule LibraryConcurrentTest do
  use ExUnit.Case, async: true

  setup do
    %{borrow: if(System.get_env("BUGGY") == "1", do: :borrow_buggy, else: :borrow)}
  end

  # The same size TLC checks: 1 copy, 2 patrons, borrowing at the same time.
  # No property library. Whether it catches the race depends on how the
  # scheduler orders the two processes. On a multi-core machine it fails. With
  # 1 scheduler (`ELIXIR_ERL_OPTIONS="+S 1"`), like a 1-CPU CI runner, it passes.
  test "2 patrons at once never get more than 1 copy", %{borrow: borrow} do
    library = start_supervised!({Library, 1})

    [:socrates, :beelzebub]
    |> Task.async_stream(&apply(Library, borrow, [library, &1]))
    |> Stream.run()

    assert MapSet.size(Library.loans(library)) <= 1
  end
end
