defmodule Library do
  @moduledoc """
  The code for `tla/Library.tla`. The Agent holds the spec's `shelf` and
  `loans`, and each spec step is a function with the same name.
  """

  def start_link(copies), do: Agent.start_link(fn -> %{shelf: copies, loans: MapSet.new()} end)

  def loans(library), do: Agent.get(library, & &1.loans)

  @doc """
  The buggy borrow. It calls `look/2`, then `take/2` in a second message.
  Another patron can take the last copy in between.
  """
  def borrow_buggy(library, patron) do
    if look(library, patron), do: take(library, patron), else: {:error, :unavailable}
  end

  defp look(library, patron) do
    Agent.get(library, fn s -> s.shelf > 0 and patron not in s.loans end)
  end

  defp take(library, patron) do
    Agent.update(library, fn s ->
      %{s | shelf: s.shelf - 1, loans: MapSet.put(s.loans, patron)}
    end)
  end

  @doc "The fixed borrow. It checks the shelf and takes the copy in one message."
  def borrow(library, patron) do
    Agent.get_and_update(library, fn s ->
      if s.shelf > 0 and patron not in s.loans do
        {:ok, %{s | shelf: s.shelf - 1, loans: MapSet.put(s.loans, patron)}}
      else
        {{:error, :unavailable}, s}
      end
    end)
  end

  def return(library, patron) do
    Agent.get_and_update(library, fn s ->
      if patron in s.loans do
        {:ok, %{s | shelf: s.shelf + 1, loans: MapSet.delete(s.loans, patron)}}
      else
        {{:error, :not_borrowed}, s}
      end
    end)
  end
end
