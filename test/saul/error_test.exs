defmodule Saul.ErrorTest do
  use ExUnit.Case, async: true

  alias Saul.Error

  test "Exception.message/1" do
    import Exception, only: [message: 1]

    error = %Error{validator: "map", position: nil, reason: "invalid keys: :a, :b"}
    assert message(error) == "(map) invalid keys: :a, :b"

    error = %Error{
      validator: "map",
      position: {:key, :foo},
      reason: %Error{
        validator: "map",
        position: nil,
        reason: "invalid keys: :a, :b",
      },
    }
    assert message(error) == "(map) at key :foo -> (map) invalid keys: :a, :b"
  end
end
