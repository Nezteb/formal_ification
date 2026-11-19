defmodule LibraryTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @copies 2
  @buggy System.get_env("BUGGY") == "1"

  defp command do
    tuple({member_of([:borrow, :hold, :return]), member_of([:ana, :ben, :cy])})
  end

  # Applies each command in order. A rejected command leaves the state unchanged.
  defp run(commands) do
    Enum.scan(commands, Library.new(@copies, buggy: @buggy), fn {op, patron}, lib ->
      case apply(Library, op, [lib, patron]) do
        {:ok, lib} -> lib
        {:error, _} -> lib
      end
    end)
  end

  property "the numbers balance" do
    check all commands <- list_of(command(), max_length: 30) do
      for lib <- run(commands) do
        assert lib.shelf + MapSet.size(lib.loans) == @copies
      end
    end
  end

  property "nobody waits while a copy is on the shelf" do
    check all commands <- list_of(command(), max_length: 30) do
      for lib <- run(commands) do
        assert lib.shelf == 0 or :queue.is_empty(lib.holds)
      end
    end
  end
end
