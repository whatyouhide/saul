defmodule Saul.Map do
  @moduledoc false

  alias Saul.Error

  @spec map_of(Saul.validator(key), Saul.validator(value)) ::
        Saul.validator(%{optional(key) => value}) when key: any, value: any
  def map_of(key_validator, value_validator) do
    map_validator = Saul.enum_of(&pair_validator(&1, key_validator, value_validator), into: %{})

    fn term ->
      with {:ok, _map} <- Saul.validate(term, &is_map/1),
           {:error, %Error{reason: reason}} <- Saul.validate(term, map_validator) do
        {:error, reason}
      end
    end
  end

  defp pair_validator({key, value}, key_validator, value_validator) do
    case Saul.validate(key, key_validator) do
      {:ok, transformed_key} ->
        case Saul.validate(value, value_validator) do
          {:ok, transformed_value} ->
            {:ok, {transformed_key, transformed_value}}
          {:error, %Error{} = error} ->
            {:error, %Error{position: {:key, key}, reason: error}}
        end
      {:error, %Error{} = error} ->
        {:error, %Error{reason: "invalid key: #{Exception.message(error)}", term: {:term, key}}}
    end
  end
end
