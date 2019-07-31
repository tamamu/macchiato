defmodule Macchiato do
  @moduledoc """
  Documentation for Macchiato.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Macchiato.hello()
      :world

  """
  def hello do
    src = ~S/
      (defn hello (selector)
        (let ((elem (document:query-selector selector)))
          (set! elem:style:left 100#px)))
            /
    process(src)
  end

  def process(src) do
    exprs = src |> Macchiato.Token.split |> Macchiato.Token.tokenize_all |> Macchiato.Parser.parse
    Enum.map(exprs, fn expr -> expr |> Macchiato.Codegen.codegen |> IO.puts end)
  end
end
