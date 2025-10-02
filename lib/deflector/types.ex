defmodule Deflector.Types do
  @moduledoc """
  Core domain types and specs for resilience primitives.
  """

  @type state :: :closed | :open | :half_open
  @type result :: :ok | {:error, term()}
  @type name :: atom() | {:via, module(), term()} | pid()
  @type window_size :: pos_integer()
  @type failure_threshold :: float()
  @type reset_timeout :: non_neg_integer()
end