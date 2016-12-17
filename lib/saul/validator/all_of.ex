defmodule Saul.Validator.AllOf do
  @moduledoc false

  defstruct [:validators]

  defimpl Saul.Validator do
    def validate(%{validators: validators}, term) do
      do_validate(validators, term)
    end

    defp do_validate([validator], term) do
      with {:ok, _transformed} = ok_result <- Saul.validate(term, validator),
           do: ok_result
    end

    defp do_validate([validator | rest], term) do
      with {:ok, transformed} <- Saul.validate(term, validator),
           do: do_validate(rest, transformed)
    end
  end
end
