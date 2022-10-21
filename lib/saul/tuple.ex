defmodule Saul.Tuple do
  @moduledoc false

  alias Saul.Error

  def tuple(validators) when is_tuple(validators) do
    Saul.all_of([&is_tuple/1, &validate_tuple(&1, validators)])
  end

  defp validate_tuple(tuple, validators) when tuple_size(tuple) == tuple_size(validators) do
    list_tuple = Tuple.to_list(tuple)
    list_validators = Tuple.to_list(validators)

    validate_pairs(list_tuple, list_validators, [])
  end

  defp validate_tuple(tuple, validators) do
    reason =
      "expected tuple with #{tuple_size(validators)} elements, " <>
      "got one with #{tuple_size(tuple)} elements"
    {:error, %Error{validator: "tuple", reason: reason}}
  end

  defp validate_pairs([elem | rest], [validator | validators], acc) do
    case Saul.validate(elem, validator) do
      {:ok, transformed} ->
        validate_pairs(rest, validators, [transformed | acc])
      {:error, error} ->
        {:error, %Error{validator: "tuple", position: {:index, length(acc)}, reason: error}}
    end
  end

  defp validate_pairs([], [], acc) do
    {:ok, (acc |> Enum.reverse() |> List.to_tuple())}
  end
end
