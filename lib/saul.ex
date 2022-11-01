defmodule Saul do
  @moduledoc """
  Contains the core of the functionality provided by Saul.

  Saul is a data validation and conformation library. It tries to solve the
  problem of validating the shape and content of some data (most useful when
  such data come from an external source) and of conforming those data to
  arbitrary formats.

  Saul is based on the concept of **validators**: a validator is something that
  knows how to validate a term and transform it to something else if
  necessary. A good example of a validator could be something that validates
  that a term is a string representation of an integer and that converts such
  string to the represented integer.

  Validators are a powerful abstraction as they can be easily *combined*: for
  example, the `Saul.one_of/1` function takes a list of validators and returns a
  validator that passes if one of the given validators pass. Saul provides both
  "basic" validators as well as validator combinators.

  ## Validators

  A validator can be:

    * a function that takes one argument
    * a term that implements the `Saul.Validator` protocol

  The return value of function validators or implementations of
  `Saul.Validator.validate/2` has to be one of the following:

    * `{:ok, transformed}` - it means validation succeeded (the input term is
      considered valid) and `transformed` is the conformed value for the input
      term.

    * `{:error, reason}` - it means validation failed (the input term is
      invalid). `reason` can be any term: if it is not a `Saul.Error` struct,
      `validate/2` will take care of wrapping it into a `Saul.Error`.

    * `:error` - it means validation failed. It is the same as `{:error, reason}`,
      except the reason only mentions that a "predicate failed".

    * `true` - it means validation succeeded. It is the same as `{:ok,
      transformed}`, but it can be used when the transformed value is the same
      as the input value. This is useful for "predicate" validators (functions
      that take one argument and return a boolean).

    * `false` - it means validation failed. It is the same as `:error`.

  Returning a boolean value is supported so that existing predicate functions
  can be used as validators without modification. Examples of such functions are
  type guards (`is_binary/1` or `is_list/1`), functions like `String.valid?/1`,
  and many others.

  ## Validating

  The only entry point for validation is `validate/2`. It hides all the
  complexity of the possible return values of validators (described in the
  "Validators" section) and always returns `{:ok, transformed}` (where
  `transformed` can be the same term as the term being validated) or `{:error,
  %Saul.Error{}}`. See the documentation for `validate/2` for more detailed
  documentation.
  """

  @typedoc """
  The type defining a validator.

  See the module documentation for more information on what are validators.
  """
  @type validator(transformed_type) ::
        (term -> {:ok, transformed_type} | {:error, term})
        | (term -> boolean)
        | Saul.Validator.t

  @doc """
  Validates the given `term` through the given `validator`.

  If the validator successfully matches `term`, then the return value of this
  function is `{:ok, transformed}` where `transformed` is the result of the
  transformation applied by the validator. If the validator returns `{:error,
  reason}`, the return value of this function is `{:error, %Saul.Error{}}`.

  Note that the given validator can return any type of `reason` when returning
  an `:error` tuple: `validate/2` will take care of wrapping it into a
  `%Saul.Error{}`. This is done so that users can work with a consistent
  interface but at the same time they can use already existing functions as
  validators (since `{:ok, term} | {:error, term}` is quite a common API in
  Erlang/Elixir).

  ## Examples

      iex> to_string = &{:ok, to_string(&1)}
      iex> Saul.validate(:foo, to_string)
      {:ok, "foo"}
      iex> Saul.validate("hello", to_string)
      {:ok, "hello"}

      iex> failer = fn(_) -> {:error, :bad} end
      iex> {:error, %Saul.Error{} = error} = Saul.validate(3.14, failer)
      iex> error.reason
      ":bad"

  """
  @spec validate(term, validator(value)) ::
        {:ok, value} | {:error, Saul.Error.t} | no_return when value: term
  def validate(term, validator) do
    result =
      case validator do
        fun when is_function(fun, 1) -> validator.(term)
        _ -> Saul.Validator.validate(validator, term)
      end

    case result do
      {:ok, _transformed} = result ->
        result
      true ->
        {:ok, term}
      {:error, %Saul.Error{}} = result ->
        result
      {:error, reason} ->
        {:error, %Saul.Error{validator: validator, reason: inspect(reason), term: {:term, term}}}
      failed when failed in [false, :error] ->
        {:error, %Saul.Error{validator: validator, reason: "predicate failed", term: {:term, term}}}
      other ->
        raise ArgumentError, "validator should return {:ok, term}, {:error, term}, " <>
                             "or a boolean, got: #{inspect(other)}"
    end
  end

  @doc """
  Validates the given `term` through the given `validator`, raising in case of errors.

  This function works like `validate/2`, but it returns the transformed term
  directly in case validation succeeds or raises a `Saul.Error` exception in
  case validation fails.

  ## Examples

      iex> Saul.validate!("foo", &is_binary/1)
      "foo"
      iex> Saul.validate!("foo", &is_atom/1)
      ** (Saul.Error) (&:erlang.is_atom/1) predicate failed - failing term: "foo"

  """
  @spec validate!(term, validator(value)) :: value | no_return when value: any
  def validate!(term, validator) do
    case validate(term, validator) do
      {:ok, transformed} ->
        transformed
      {:error, %Saul.Error{} = error} ->
        raise(error)
    end
  end

  ## Validators

  @doc """
  Returns a validator that performs the same validation as `validator` but has
  the name `name`.

  This function is useful in order to have better errors when validation
  fails. In such cases, the name of each of the failing validators is printed
  alongside the error. If your validator is an anonymous function `f`, such name
  will be `inspect(f)`, so it won't be very useful when trying to understand
  errors. Naming a validator is also useful when your validator is an isolated
  logical unit (such as a validator that validates that a term is an integer,
  positive, and converts it to its Roman representation).

  ## Examples

      iex> failer = Saul.named_validator(fn(_) -> {:error, :oops} end, "validator that always fails")
      iex> Saul.validate!(:foo, failer)
      ** (Saul.Error) (validator that always fails) :oops - failing term: :foo

  """
  @spec named_validator(validator(value), String.t) :: validator(value) when value: any
  def named_validator(validator, name) do
    %Saul.Validator.NamedValidator{name: name, validator: validator}
  end

  @doc """
  Returns a validator that always passes and applies the given transformation
  `fun`.

  This function is useful when a validator is only applying a transformation,
  and not performing any validation. Using this function is only beneficial
  inside more complex validators, such as `all_of/1`, where `fun` needs to have
  the shape of a validator. For other cases, you can just apply `fun` directly
  to the input term.

  ## Examples

  For example, if you validated that a term is a binary in some way, but want to
  transform it to a charlist during validation, you could wrap
  `String.to_charlist/1` inside `transform/1`:

      iex> term = "this is a string"
      iex> Saul.validate!(term, Saul.transform(&String.to_charlist/1))
      'this is a string'

  """
  @spec transform((input -> output)) :: (input -> {:ok, output}) when input: var, output: var
  def transform(fun) when is_function(fun, 1) do
    &{:ok, fun.(&1)}
  end

  @doc """
  Returns a validator that checks that the input term is equal to `term`.

  This is a basic validator that allows to check for literal terms (hence its
  name, "lit"). If the input term is equal to `term`, then it is returned
  unchanged.

  ## Examples

      iex> three = Saul.lit(3)
      iex> Saul.validate(3, three)
      {:ok, 3}
      iex> {:error, error} = Saul.validate(4, three)
      iex> error.reason
      "expected exact term 3"

  """
  @spec lit(value) :: validator(value) when value: term
  def lit(term) do
    %Saul.Validator.Literal{term: term}
  end

  @doc """
  Returns a validator that matches when all the given `validators` match.

  `validators` has to be a *non-empty* list of validators.

  The validation stops and fails as soon as one of the `validators` fails, or
  succeeds and returns the value returned by the last validator if all
  validators succeed. When a validator succeeds, the transformed value it
  returns is passed as the input to the next validator in the list: this allows
  to simulate a "pipeline" of transformations that halts as soon as something
  doesn't match (similar to a small subset of what you could achieve with the
  `with` Elixir special form).

  ## Examples

      iex> validator = Saul.all_of([&{:ok, to_string(&1)}, &is_binary/1])
      iex> Saul.validate(:hello, validator)
      {:ok, "hello"}

      iex> validator = Saul.all_of([&is_binary/1, &{:ok, &1}])
      iex> Saul.validate!(:hello, validator)
      ** (Saul.Error) (&:erlang.is_binary/1) predicate failed - failing term: :hello

  """
  @spec all_of(nonempty_list(validator(term))) :: validator(term)
  def all_of([_ | _] = validators) do
    %Saul.Validator.AllOf{validators: validators}
  end

  @doc """

  Returns a validator that matches if one of the given `validators` match.

  `validators` has to be a *non-empty* list of validators.

  The validation stops and succeeds as soon as one of the `validators`
  succeeds. The value returned by the succeeding validator is the value returned
  by this validator as well. If all validators fail, an error that shows all the
  failures is returned.

  ## Examples

      iex> validator = Saul.one_of([&is_binary/1, &is_atom/1])
      iex> Saul.validate(:foo, validator)
      {:ok, :foo}

  """
  @spec one_of(nonempty_list(validator(term))) :: validator(term)
  def one_of([_ | _] = validators) do
    %Saul.Validator.OneOf{validators: validators}
  end

  @doc """
  Returns a validator that matches an enumerable where all elements match
  `validator`.

  The return value of this validator is a value constructed by collecting the
  values in the given enumerable transformed according to `validator` into the
  collectable specified by the `:into` option. This validator can be considered
  analogous to the `for` special form (with the `:into` option as well), but
  with error handling. If any of the elements in the given enumerable fails
  `validator`, this validator fails.

  ## Options

    * `:into` - (`t:Collectable.t/0`) the collectable where the transformed values
      should end up in. Defaults to `[]`.

  ## Examples

      iex> validator = Saul.enum_of(&{:ok, {inspect(&1), &1}}, into: %{})
      iex> Saul.validate(%{foo: :bar}, validator)
      {:ok, %{"{:foo, :bar}" => {:foo, :bar}}}
      iex> Saul.validate([1, 2, 3], validator)
      {:ok, %{"1" => 1, "2" => 2, "3" => 3}}

  """
  @spec enum_of(Saul.validator(term), Keyword.t) :: Saul.validator(Collectable.t)
  def enum_of(validator, options \\ []) when is_list(options) do
    Saul.Enum.enum_of(validator, options)
  end

  @doc """
  Returns a validator that validates a map with the shape specified by
  `validators_map`.

  `validators_map` must be a map with values as keys and two-element tuples
  `{required_or_optional, validator}` as values. The input map will be validated
  like this:

    * each key is checked against the validator at the corresponding key in
      `validators_map`

    * `{:required, validator}` validators mean that their corresponding key is
      required in the map; if it's not present in the input map, this
      validator fails

    * `{:optional, validator}` validators mean that their corresponding key
      can be not present in the map, and it's only validated with `validator`
      in case it's present

  The map returned by this validator has unchanged keys and values that are the
  result of the validator for each key.

  ## Options

    * `:strict` (boolean) - if this option is `true`, then this validator fails
      if the input map has keys that are not in `validators_map`. Defaults to
      `false`.

  ## Examples

      iex> validator = Saul.map([strict: false], %{
      ...>   to_string: {:required, &{:ok, to_string(&1)}},
      ...>   is_atom: {:optional, &is_atom/1},
      ...> })
      iex> Saul.validate(%{to_string: :foo, is_atom: :bar}, validator)
      {:ok, %{to_string: "foo", is_atom: :bar}}
      iex> Saul.validate(%{to_string: :foo}, validator)
      {:ok, %{to_string: "foo"}}

  """
  @spec map(Keyword.t , %{optional(term) => {:required | :optional, validator(term)}}) ::
        validator(map)
  def map(options \\ [], validators_map) when is_list(options) and is_map(validators_map) do
    Saul.Validator.Map.new(validators_map, options)
  end

  @doc """
  Returns a validator that validates a tuples with elements that match the
  validator at their corresponding position in `validators`.

  The return value of this validator is a tuple with the same number of elements
  as `validators` (and the input tuple) where elements are the result of the
  validator in their corresponding position in `validators`.

  ## Examples

      iex> atom_to_string = Saul.transform(&Atom.to_string/1)
      iex> Saul.validate({:foo, :bar}, Saul.tuple({atom_to_string, atom_to_string}))
      {:ok, {"foo", "bar"}}

  """
  @spec tuple(tuple) :: validator(tuple)
  def tuple(validators) when is_tuple(validators) do
    Saul.Tuple.tuple(validators)
  end

  @doc """
  Returns a validator that validates a map with keys that match `key_validator`
  and values that match `value_validator`.

  The return value of this validator is a map where keys are the result of
  `key_validator` for each key and values are the result of `value_validator`
  for the corresponding key. If any key or value fail, this validator fails.

  Note that if `key_validator` ends up transforming two keys into the same term,
  then they will collapse under just one key-value pair in the transformed map
  and there is no guarantee on which value will prevail.

  ## Examples

      iex> integer_to_string = Saul.all_of([&is_integer/1, &{:ok, Integer.to_string(&1)}])
      iex> validator = Saul.map_of(integer_to_string, &is_atom/1)
      iex> Saul.validate(%{1 => :ok, 2 => :not_so_ok}, validator)
      {:ok, %{"1" => :ok, "2" => :not_so_ok}}

  """
  @spec map_of(validator(key), validator(value)) :: validator(%{optional(key) => value})
        when key: any, value: any
  def map_of(key_validator, map_validator) do
    Saul.Map.map_of(key_validator, map_validator)
  end

  @doc """
  Returns a validator that validates a list where all elements match `validator`.

  The return value of this validator is a list where each element is the return
  value of `validator` for the corresponding element in the input
  list. Basically this is analogous to `Enum.map/2` but with error handling. If
  any of the elements in the list fail `validator`, this validator fails.

  ## Examples

      iex> integer_to_string = Saul.all_of([&is_integer/1, &{:ok, Integer.to_string(&1)}])
      iex> Saul.validate([1, 2, 3], Saul.list_of(integer_to_string))
      {:ok, ["1", "2", "3"]}

  """
  @spec list_of(validator(value)) :: validator([value]) when value: any
  def list_of(validator) do
    [&is_list/1, enum_of(validator, into: [])]
    |> all_of()
    |> named_validator("list_of")
  end

  @doc """
  Returns a validator that checks if the input term is a member of `enumerable`.

  The return value of this validator is the input term, unmodified.
  `Enum.member?/2` is used to check if the input term is a member of
  `enumerable`.

  ## Examples

      iex> Saul.validate(:bar, Saul.member([:foo, :bar, :baz]))
      {:ok, :bar}
      iex> Saul.validate(50, Saul.member(1..100))
      {:ok, 50}

  """
  @spec member(Enumerable.t) :: validator(term)
  def member(enumerable) do
    %Saul.Validator.Member{enumerable: enumerable}
  end
end
