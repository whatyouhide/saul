defmodule Saul.Validator.Member do
  @moduledoc false

  defstruct [:enumerable]

  defimpl Saul.Validator do
    def validate(%{enumerable: enumerable}, term) do
      if Enum.member?(enumerable, term) do
        {:ok, term}
      else
        reason = "not a member of #{inspect(enumerable)}"
        {:error, %Saul.Error{validator: "member", reason: reason, term: {:term, term}}}
      end
    end
  end
end
