defmodule Library do
  @moduledoc """
  One book, a fixed number of copies, a first-come-first-served hold queue.

  Same rules as `tla/Library.tla` and `lean/Library.lean`. Pass `buggy: true`
  to plant the bug: returns go back on the shelf even when someone is waiting.
  """

  defstruct shelf: 0, loans: MapSet.new(), holds: :queue.new(), buggy: false

  def new(copies, opts \\ []),
    do: %Library{shelf: copies, buggy: Keyword.get(opts, :buggy, false)}

  def borrow(lib, patron) do
    cond do
      lib.shelf == 0 -> {:error, :none_available}
      not :queue.is_empty(lib.holds) -> {:error, :holds_waiting}
      patron in lib.loans -> {:error, :already_borrowed}
      true -> {:ok, %{lib | shelf: lib.shelf - 1, loans: MapSet.put(lib.loans, patron)}}
    end
  end

  def hold(lib, patron) do
    cond do
      lib.shelf > 0 -> {:error, :copy_available}
      patron in lib.loans -> {:error, :already_borrowed}
      :queue.member(patron, lib.holds) -> {:error, :already_holding}
      true -> {:ok, %{lib | holds: :queue.in(patron, lib.holds)}}
    end
  end

  def return(lib, patron) do
    if patron in lib.loans do
      loans = MapSet.delete(lib.loans, patron)

      case :queue.out(lib.holds) do
        {{:value, next}, rest} when not lib.buggy ->
          {:ok, %{lib | loans: MapSet.put(loans, next), holds: rest}}

        _ ->
          {:ok, %{lib | shelf: lib.shelf + 1, loans: loans}}
      end
    else
      {:error, :not_borrowed}
    end
  end
end
