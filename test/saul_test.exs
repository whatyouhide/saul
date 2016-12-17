defmodule SaulTest do
  use ExUnit.Case

  doctest Saul

  alias Saul.Error

  def to_string_with_suffix(term, suffix) do
    {:ok, to_string(term) <> suffix}
  end

  describe "validate/2" do
    import Saul, only: [validate: 2]

    test "accepts 1-arity functions as validators" do
      assert validate(12, fn(term) -> {:ok, term} end) == {:ok, 12}
    end

    test "accepts 1-arity predicates as validators" do
      assert validate(12, &is_integer/1) == {:ok, 12}
      assert {:error, %Error{}} = validate(:foo, &is_binary/1)
    end

    test "fails when a validator doesn't return one of the allowed values" do
      message = "validator should return {:ok, term}, {:error, term}, or a boolean, got: :bad_return"
      assert_raise ArgumentError, message, fn ->
        Saul.validate(:something, fn(_term) -> :bad_return end)
      end
    end
  end

  describe "validate!/2" do
    import Saul, only: [validate: 2, validate!: 2]

    test "returns the transformed value directly if a validator succeeds" do
      assert validate!(:foo, &{:ok, &1}) == :foo
    end

    test "raises a Saul.Error when a validator fails" do
      assert_raise Error, "(val) oops", fn ->
        validate!(:foo, fn(_term) -> {:error, %Error{reason: "oops", validator: "val"}} end)
      end
    end
  end

  describe "transform/1" do
    import Saul, only: [validate: 2, transform: 1]

    test "wraps a function as a validator" do
      assert validate("123", transform(&String.to_integer/1)) == {:ok, 123}
      assert_raise ArgumentError, fn ->
        validate("not an integer", transform(&String.to_integer/1))
      end
    end
  end

  describe "lit/1" do
    import Saul, only: [validate: 2, lit: 1]

    test "succeeds when the input term is equal to the term given to lit/1" do
      assert validate(3, lit(3)) == {:ok, 3}

      assert {:error, %Error{} = error} = validate(:something_else, lit(:something))
      assert error.reason == "expected exact term :something"
      assert error.term == {:term, :something_else}
      assert error.validator == nil
    end
  end

  describe "named_validator/1" do
    import Saul, only: [validate: 2, named_validator: 2]

    test "helps produce better error messages" do
      validator = fn _term -> {:error, :bad_term} end
      named_validator = named_validator(validator, "some validator")
      assert {:error, %Error{} = error} = validate(:foo, named_validator)
      assert error.reason == ":bad_term"
      assert error.validator == "some validator"

      named_validator = named_validator(&is_atom/1, "is_atom guard")
      assert {:error, %Error{} = error} = validate("foo", named_validator)
      assert error.reason == "predicate failed"
      assert error.validator == "is_atom guard"
    end
  end

  describe "one_of/1" do
    import Saul, only: [validate: 2, one_of: 1]

    test "needs at least one validator in the given list" do
      assert_raise FunctionClauseError, fn -> one_of([]) end
    end

    test "when passed [validator], is the same of just running validator" do
      validator = &is_integer/1
      assert validate(300, one_of([validator])) == {:ok, 300}
      assert {:error, %Error{}} = validate("foo", one_of([validator]))
    end

    test "succeeds on the first validator that succeeds, with short circuiting" do
      ref = make_ref()
      side_effect_validator = fn(_term) ->
        Process.put({ref, :side_effect}, true)
        {:ok, :ok}
      end

      assert validate(22, one_of([&is_integer/1, side_effect_validator])) == {:ok, 22}
      refute Process.get({ref, :side_effect})
    end

    test "fails when all validators fail" do
      assert {:error, error} = validate(231, one_of([&is_atom/1, &is_binary/1]))
      assert error.validator == "one_of"
      assert error.reason ==
        "all validators failed: [(&:erlang.is_binary/1) predicate failed - failing term: 231, " <>
        "(&:erlang.is_atom/1) predicate failed - failing term: 231]"
    end
  end

  describe "all_of/1" do
    import Saul, only: [validate: 2, all_of: 1]

    test "needs at least one validator in the given list" do
      assert_raise FunctionClauseError, fn -> all_of([]) end
    end

    test "when passed [validator], is the same of just running validator" do
      validator = &is_integer/1
      assert validate(300, all_of([validator])) == {:ok, 300}
      assert {:error, %Error{}} = validate("foo", all_of([validator]))
    end

    test "fails on the first validator that fails (with short circuiting) and mentions its reason" do
      ref = make_ref()
      side_effect_validator = fn(_term) ->
        Process.put({ref, :side_effect}, true)
        {:ok, :ok}
      end

      assert {:error, error} = validate(22, all_of([&is_atom/1, side_effect_validator]))
      refute Process.get({ref, :side_effect})
      assert Exception.message(error) =~ "predicate failed"
    end

    test "succeeds when all validators succeed and returns the result of the last validator" do
      to_string = &{:ok, to_string(&1)}
      assert validate(:foo, all_of([&is_atom/1, to_string])) == {:ok, "foo"}
    end

    test "passes the result of each validator to the next validator" do
      to_string = &{:ok, to_string(&1)}
      assert validate(:foo, all_of([to_string, &is_binary/1])) == {:ok, "foo"}
    end
  end

  describe "enum_of/1" do
    import Saul, only: [validate: 2, enum_of: 1, enum_of: 2]

    test "ensures that all the elements in an enum satisfy the given validator" do
      assert validate([1, 2, 3], enum_of(&is_integer/1)) == {:ok, [1, 2, 3]}
      assert {:error, %Error{}} = validate([1, 2, :atom], enum_of(&is_integer/1))
    end

    test "always succeeds when given an empty enum" do
      assert validate([], enum_of(fn _ -> false end)) == {:ok, []}
      assert validate(%{}, enum_of(fn _ -> false end, into: %{})) == {:ok, %{}}
    end

    test "returns a collected value (according to :into) of the transformed values in the enum" do
      validator = fn({str, int}) -> {:ok, {String.to_integer(str), int}} end
      assert validate(%{"1" => 1, "2" => 2, "3" => 3}, enum_of(validator, into: %{})) ==
             {:ok, %{1 => 1, 2 => 2, 3 => 3}}
    end
  end

  describe "map_of/1" do
    import Saul, only: [validate: 2, map_of: 2]

    test "validates that the given term is a map" do
      assert {:error, %Error{} = error} = validate(:ok, map_of(fn _ -> true end, fn _ -> true end))
      assert Exception.message(error) =~ "predicate failed"
    end

    test "validates the type of keys and values in the map" do
      atom_to_string = Saul.all_of([&is_atom/1, &{:ok, Atom.to_string(&1)}])
      validator = map_of(atom_to_string, atom_to_string)

      assert validate(%{a: :a, b: :b}, validator) ==
             {:ok, %{"a" => "a", "b" => "b"}}

      assert {:error, %Error{} = error} = validate(%{"foo" => "bar"}, validator)
      assert Exception.message(error) =~ "invalid key"
    end
  end

  describe "map/2" do
    import Saul, only: [validate: 2, map: 1, map: 2]

    test "fails if the second argument (validators map) is not a map" do
      assert_raise FunctionClauseError, fn ->
        map([], :not_a_map)
      end
    end

    test "ensures that the given term is a map" do
      assert {:error, %Error{} = error} = validate(:ok, map([], %{foo: {:optional, &is_atom/1}}))
      assert error.reason =~ "predicate failed"
    end

    test "ensures that all the :required keys are present" do
      validator = map(%{
        foo: {:required, &is_boolean/1},
        bar: {:required, &is_atom/1},
      })

      assert {:ok, _} = validate(%{foo: true, bar: :this_is_bar}, validator)

      assert {:error, %Error{} = error} = validate(%{foo: true, missing: :bar}, validator)
      assert error.reason == "missing required keys: [:bar]"
    end

    test "returns a map with the transformed values for the right keys" do
      atom_to_string = Saul.all_of([&is_atom/1, &{:ok, Atom.to_string(&1)}])
      validator = map(%{
        foo: {:required, atom_to_string},
        bar: {:optional, atom_to_string},
      })

      assert validate(%{foo: :foo, bar: :bar}, validator) == {:ok, %{foo: "foo", bar: "bar"}}
    end

    test "returns unknown keys as is if :strict is false" do
      atom_to_string = Saul.all_of([&is_atom/1, &{:ok, Atom.to_string(&1)}])
      validator = map([strict: false], %{foo: {:required, atom_to_string}})

      assert validate(%{foo: :foo, bar: :bar}, validator) == {:ok, %{foo: "foo", bar: :bar}}
    end

    test "fails for unknown keys if :strict is true" do
      atom_to_string = Saul.all_of([&is_atom/1, &{:ok, Atom.to_string(&1)}])
      validator = map([strict: true], %{foo: {:required, atom_to_string}})

      assert {:error, error} = validate(%{foo: :foo, bar: :bar}, validator)
      assert error.reason == "unknown keys in strict mode: [:bar]"
    end
  end

  describe "tuple/1" do
    import Saul, only: [validate: 2, tuple: 1]

    test "ensures that the given term is a tuple" do
      assert {:error, error} = validate(:not_a_tuple, tuple({}))
      assert Exception.message(error) =~ "predicate failed"
    end

    test "ensures that the given tuple has the right number of elements" do
      assert {:error, error} = validate({1, 2, 3}, tuple({&is_integer/1, &is_integer/1}))
      assert Exception.message(error) =~ "expected tuple with 2 elements, got one with 3 elements"
    end

    test "returns a tuple with the transformed values" do
      atom_to_string = &{:ok, Atom.to_string(&1)}
      assert validate({:foo, :bar}, tuple({atom_to_string, atom_to_string})) ==
             {:ok, {"foo", "bar"}}
    end
  end

  describe "list_of/1" do
    import Saul, only: [validate: 2, list_of: 1]

    test "ensures that the given term is a list" do
      assert {:error, error} = validate(:ok, list_of(&is_atom/1))
      assert Exception.message(error) =~ "predicate failed"
    end

    test "ensures that all the elements in a list satisfy the given validator" do
      assert {:ok, _} = validate([1, 2, 3], list_of(&is_integer/1))
      assert {:error, %Error{}} = validate([1, 2, :atom], list_of(&is_integer/1))
    end

    test "always succeeds when given an empty list" do
      always_failing_validator = fn(_term) -> {:error, %Error{}} end
      assert {:ok, _} = validate([], list_of(always_failing_validator))
    end

    test "returns a list of the transformed values returned by the given validator" do
      str_to_int_validator = fn(str) -> {:ok, String.to_integer(str)} end
      assert validate(["1", "2", "3"], list_of(str_to_int_validator)) == {:ok, [1, 2, 3]}
    end
  end

  describe "member/1" do
    import Saul, only: [validate: 2, member: 1]

    test "checks for membership in the given enumerable" do
      assert validate(4, member([1, :foo, 4, %{}])) == {:ok, 4}
      assert validate(99, member(1..100)) == {:ok, 99}
      assert validate(:bar, member(MapSet.new([:foo, :bar, :baz]))) == {:ok, :bar}

      assert {:error, %Error{} = error} = validate(1, member(50..100))
      assert error.reason == "not a member of 50..100"
      assert error.term == {:term, 1}
    end
  end

  describe "integration tests" do
    test "map/1: goal payload validation" do
      formattable_score = Saul.all_of([&is_binary/1, fn(score) ->
        case String.split(score, "-", trim: true, parts: 2) do
          [left, right] ->
            {:ok, {left, right}}
          _other ->
            {:error, %Error{validator: "formattable_score", reason: "failed to split score: #{inspect(score)}"}}
        end
      end])

      validator = Saul.map([strict: true], %{
        "player_name" => {:required, &is_binary/1},
        "score" => {:required, formattable_score},
        "team_side" => {:required, Saul.member([1, 2])},
        "players" => {:optional, Saul.list_of(&is_binary/1)},
      })

      # map [strict: false], %{
      #   "player_name" => {:required, all_of([&is_binary/1, ...])},
      #   "players" => {:optional, list_of(&is_binary/1)},
      # }

      assert {:ok, validated} = Saul.validate(%{
        "player_name" => "Cristiano Ronaldo",
        "score" => "1-0",
        "players" => ["Cristiano Ronaldo", "Gianluigi Buffon"],
        "team_side" => 1,
      }, validator)
      assert validated["score"] == {"1", "0"}
    end
  end
end
