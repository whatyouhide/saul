# Saul

> Data validation and conformation library for Elixir.

![Cover image](http://i.imgur.com/9DXjXjA.jpg)

Saul is a data validation and conformation library. It tries to solve the problem of validating the shape and content of some data (most useful when such data come from an external source) and of conforming those data to arbitrary formats.

The goal of Saul is to provide a declarative and composable way to define data validation/conformation. The basic unit of validation is a **validator** which is either a function or a term that implements the `Saul.Validator` protocol. The return value of validator functions or implementations of `Saul.Validator.validate/2` has to be either `{:ok, transformed}` to signify a successful validation and conformation, `{:error, term}` to signify a failed validation with a given reason, or a boolean to signify just successful/failed validation with no conformation step. These return values have been chosen because of their widespread presence in Elirix and Erlang code: for example, allowing to return booleans means any predicate function (such as `String.valid?/1`) can be used as validator.

Validators can be a powerful abstraction because they're easy to *combine*: for example, the `Saul.one_of/1` combinator takes a list of validators and returns a validator that passes if one of the given validators pass. Saul provides both "basic" validators as well as validator combinators, as well as a single entry point to validate data (`Saul.validate/2`). See [the documentation][documentation] for detailed information on all the provided features.

## Installation

Add the `:saul` dependency to your `mix.exs` file:

```elixir
defp deps() do
  [{:saul, "~> 0.1"}]
end
```

If you're not using `:extra_applications` from Elixir 1.4 and above, also add `:saul` to your list of applications:

```elixir
defp application() do
  [applications: [:logger, :saul]]
end
```

Then, run `mix deps.get` in your shell to fetch the new dependency.

## Usage

Validators are just data structures that can be moved around. You can create arbitrarely complex ones:

```elixir
string_to_integer =
  fn string ->
    case Integer.parse(string) do
      {int, ""} -> {:ok, int}
      _other -> {:error, "not parsable as integer"}
    end
  end
  |> Saul.named_validator("string_to_integer")

stringy_integer = Saul.all_of([
  &is_binary/1,
  string_to_integer,
])
```

Now you can use them to validate data:

```elixir
iex> Saul.validate!("123", stringy_integer)
123
iex> Saul.validate!("nope", stringy_integer)
** (Saul.Error) (string_to_integer) not parsable as integer - failing term: "nope"
```

## Contributing

Clone the repository and run `$ mix test`. To generate docs, run `$ mix docs`.

## License

Saul is released under the ISC license, see the [LICENSE](LICENSE) file.


[documentation]: https://hexdocs.pm/saul
