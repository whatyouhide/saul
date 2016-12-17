defmodule Saul.Validator.OneOf do
  @moduledoc false

  defstruct [:validators]

  defimpl Saul.Validator do
    def validate(%{validators: validators}, term) do
      do_validate(validators, term, _errors = [])
    end

    defp do_validate([validator | rest], term, errors) do
      with {:error, error} <- Saul.validate(term, validator),
           do: do_validate(rest, term, [error | errors])
    end

    defp do_validate([], _term, errors) do
      errors =
        errors
        |> Enum.map(&Exception.message/1)
        |> Enum.intersperse(", ")
      reason = IO.iodata_to_binary(["all validators failed: [", errors, "]"])
      {:error, %Saul.Error{validator: "one_of", reason: reason}}
    end
  end
end
