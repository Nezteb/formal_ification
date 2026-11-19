defmodule Library do
  @moduledoc """
  One book with a fixed number of copies, the same model as `tla/Library.tla`.
  The state is the number of copies on the shelf.
  """

  def start_link(copies), do: Agent.start_link(fn -> copies end)

  @doc """
  The buggy borrow. It looks at the shelf, then takes a copy in a second
  message. Another patron can take the last copy in between.
  """
  def borrow_buggy(library) do
    if Agent.get(library, & &1) > 0 do
      Agent.update(library, &(&1 - 1))
      :ok
    else
      {:error, :none_left}
    end
  end

  @doc "The fixed borrow. It checks the shelf and takes a copy in one message."
  def borrow(library) do
    Agent.get_and_update(library, fn
      0 -> {{:error, :none_left}, 0}
      shelf -> {:ok, shelf - 1}
    end)
  end

  def give_back(library), do: Agent.update(library, &(&1 + 1))
end
