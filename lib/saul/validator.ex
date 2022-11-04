defprotocol Saul.Validator do
  @moduledoc """
  A protocol for transforming terms into validators.

  This protocol allows to transform the terms that implement it into validators.

  For example, say we have a `DateRange` struct in our application already
  defined like this:

      defmodule DateRange do
        defstruct [:start, :end]

        def in_range?(date, date_range) do
          after?(date, date_range.start) and before?(date, date_range.end)
        end
      end

  We could turn this structure into a validator by implementing the
  `Saul.Validator` protocol for it. We could say that a `DateRange` validator
  accepts its input if it is a date in the given range, and fails otherwise. The
  implementation of this could look like the following:

      defimpl Saul.Validator, for: DateRange do
        def validate(date_range, term) do
          if DateRange.in_range?(term, date_range) do
            {:ok, date_range}
          else
            {:error, "date not in range"}
          end
        end
      end

  Note that here we used the `{:ok, _} | {:error, _}` return type for
  `validate/2` in order to give errors a nice error message: we could have
  implemented this validator as just `DateRange.in_range(term, date_range)`, but
  then the error would have said only something like :predicate_failed.
  """

  @doc """
  Validates the given `term` according to `validator`.

  See the module documentation for `Saul` and the documentation for
  `Saul.validate/2` for more information on the possible return values.
  """
  @spec validate(term, term) :: {:ok, term} | {:error, term} | boolean
  def validate(validator, term)
end
