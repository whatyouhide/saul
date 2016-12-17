defmodule Saul.Enum do
  @moduledoc false

  alias Saul.Error

  @spec enum_of(Saul.validator(term), Keyword.t) :: Saul.validator(Collectable.t)
  def enum_of(validator, options) do
    &validate_enum_of(&1, validator, options)
  end

  defp validate_enum_of(enum, validator, options) do
    {acc, collectable_cont} =
      options
      |> Keyword.get(:into, [])
      |> Collectable.into()

    try do
      Enum.reduce(enum, {acc, 0}, fn item, {acc, index} ->
        case Saul.validate(item, validator) do
          {:ok, transformed} ->
            {collectable_cont.(acc, {:cont, transformed}), index + 1}
          {:error, %Error{} = error} ->
            throw(%Error{position: "at position #{index}", reason: error})
        end
      end)
    catch
      %Error{} = error ->
        {:error, %{error | validator: "enum_of"}}
    else
      {transformed, _index} ->
        {:ok, collectable_cont.(transformed, :done)}
    end
  end
end
