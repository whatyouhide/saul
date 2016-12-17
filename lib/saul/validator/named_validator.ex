defmodule Saul.Validator.NamedValidator do
  @moduledoc false

  defstruct [:validator, :name]

  defimpl Saul.Validator do
    def validate(%{validator: validator, name: name}, term) do
      with {:error, error} <- Saul.validate(term, validator),
           do: {:error, %Saul.Error{error | validator: name}}
    end
  end
end
