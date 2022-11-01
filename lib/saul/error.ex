defmodule Saul.Error do
  @moduledoc """
  A struct representing a validation error.

  When validation fails, `Saul.validate/2` always returns a `Saul.Error` struct
  (even if the used validator doesn't return such a struct, see the
  documentation for `Saul` for more information). This struct is a valid Elixir
  exception.

  A returned `Saul.Error` struct is usually not inspected directly, as it is a
  nested data structure that contains a tree of the errors returned by all the
  nested validations of the validator passed to `Saul.validate/2`.

  `Saul.Error` structs are mostly meant to be used to generate comprehensible
  string messages. To do that, since `Saul.Error` is an Elixir exception, use
  `Exception.message/1`.

  For example, a common use case is logging the error when some incoming
  parameters fail validation:

      case Saul.validate(params, my_params_validator) do
        {:ok, validated} ->
          # the life of my application goes on here
        {:error, %Saul.Error{} = error} ->
          Logger.error(Exception.message(error))
      end

  Note that since it is an Elixir exception, a `Saul.Error` struct can easily be
  raised (for example with `Kernel.raise/1`).
  """

  defexception [:validator, :position, :reason, :term]

  @type t :: %__MODULE__{
    validator: Saul.validator(any()) | nil,
    position: String.t() | {:index, pos_integer()} | {:key, term()},
    reason: t() | String.t(),
    term: {:term, term()} | nil
  }

  def message(%__MODULE__{} = error) do
    %{validator: validator, position: position, reason: reason, term: term} = error

    reason =
      case reason do
        %__MODULE__{} ->
          message(reason)
        reason when is_binary(reason) ->
          reason
      end

    IO.iodata_to_binary([
      if(validator, do: ["(", validator_to_string(validator), ") "], else: []),
      if(position, do: [position_to_string(position), " -> "], else: []),
      reason,
      case(term, do: ({:term, term} -> [" - failing term: ", inspect(term)]; _ -> []))
    ])
  end

  defp position_to_string(position) when is_binary(position), do: position
  defp position_to_string({:index, index}) when is_integer(index), do: "at position #{index}"
  defp position_to_string({:key, key}), do: "at key #{inspect(key)}"

  defp validator_to_string(validator) when is_binary(validator), do: validator
  defp validator_to_string(validator), do: inspect(validator)
end
