defmodule Saul.Validator.Literal do
  @moduledoc false

  defstruct [:term]

  defimpl Saul.Validator do
    def validate(%{term: term}, term) do
      {:ok, term}
    end

    def validate(%{term: expected}, actual) do
      reason = "expected exact term #{inspect(expected)}"
      {:error, %Saul.Error{reason: reason, term: {:term, actual}}}
    end
  end
end
