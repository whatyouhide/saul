defmodule Saul.Validator.Map do
  @moduledoc false

  alias Saul.Error

  defstruct [:keys, :required, :optional, :strict?]

  @spec new(%{optional(term) => {:required | :optional, Saul.validator(term)}}, Keyword.t) ::
        %__MODULE__{}
  def new(validators_map, options) when is_map(validators_map) and is_list(options) do
    {required, optional} =
      Enum.reduce(validators_map, {MapSet.new(), MapSet.new()}, fn
        {key, {:required, _validator}}, {required, optional} ->
          {MapSet.put(required, key), optional}
        {key, {:optional, _validator}}, {required, optional} ->
          {required, MapSet.put(optional, key)}
      end)

    %__MODULE__{
      keys: validators_map,
      required: required,
      optional: optional,
      strict?: Keyword.get(options, :strict, false),
    }
  end

  defimpl Saul.Validator do
    alias Saul.Error

    def validate(%Saul.Validator.Map{} = validator, term) do
      %{keys: keys, required: required, optional: optional, strict?: strict?} = validator

      with {:ok, map} <- Saul.validate(term, &is_map/1),
           map_keys = map |> Map.keys() |> MapSet.new(),
           :ok <- validate_presence(map_keys, required, optional, strict?) do
        validate_keys(map, keys)
      else
        {:error, %Error{} = error} ->
          {:error, %{error | validator: "map"}}
      end
    end

    defp validate_presence(map_keys, required, optional, strict?) do
      with :ok <- validate_required(map_keys, required),
           :ok <- if(strict?, do: validate_strictness(map_keys, required, optional), else: :ok),
           do: :ok
    end

    defp validate_required(map_keys, required) do
      missing_required = MapSet.difference(required, map_keys)

      if MapSet.size(missing_required) > 0 do
        reason = "missing required keys: #{inspect(MapSet.to_list(missing_required))}"
        {:error, %Error{reason: reason}}
      else
        :ok
      end
    end

    defp validate_strictness(map_keys, required, optional) do
      allowed = MapSet.union(required, optional)
      extra_keys = MapSet.difference(map_keys, allowed)

      if MapSet.size(extra_keys) > 0 do
        reason = "unknown keys in strict mode: #{inspect(MapSet.to_list(extra_keys))}"
        {:error, %Error{reason: reason}}
      else
        :ok
      end
    end

    defp validate_keys(map, key_validators) do
      Enum.reduce_while(map, {:ok, _transformed = %{}}, fn {key, value}, {:ok, acc} ->
        {_, validator} = Map.get(key_validators, key, {:optional, &{:ok, &1}})

        case Saul.validate(value, validator) do
          {:ok, transformed} ->
            {:cont, {:ok, Map.put(acc, key, transformed)}}
          {:error, %Error{} = error} ->
            {:halt, {:error, %Error{position: "at key #{inspect(key)}", reason: error}}}
        end
      end)
    end
  end
end
