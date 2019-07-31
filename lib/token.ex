defmodule Macchiato.Token do
  def split(s) do
    split(s, [], "")
  end

  def split(s, tokens, acc) do
    {head, tail} = String.split_at(s, 1)
    case {head, acc} do
      {"(", ""} -> split(tail, ["(" | tokens], "")
      {"(", some} -> split(tail, ["(" | [some | tokens]], "")

      {")", ""} -> split(tail, [")" | tokens], "")
      {")", some} -> split(tail, [")" | [some | tokens]], "")

      {"\"", ""} -> case read_string(tail) do
        {str, rest} -> split(rest, [str | tokens], "")
      end
      {"\"", some} -> case read_string(tail) do
        {str, rest} -> split(rest, [str | [some | tokens]], "")
      end

      {"#", ""} -> split(tail, ["#" | tokens], "")
      {"#", some} -> split(tail, ["#" | [some | tokens]], "")

      {":", ""} -> split(tail, [":" | tokens], "")
      {":", some} -> split(tail, [":" | [some | tokens]], "")

      {" ", " "} -> split(tail, tokens, acc)
      {" ", ""} -> split(tail, tokens, " ")
      {" ", some} -> split(tail, [some | tokens], " ")

      {"\n", " "} -> split(tail, tokens, acc)
      {"\n", ""} -> split(tail, tokens, " ")
      {"\n", some} -> split(tail, [some | tokens], " ")

      {"", ""} -> Enum.reverse(tokens)
      {"", some} -> split(tail, [some | tokens], "")

      {some, " "} -> split(tail, [" " | tokens], some)
      {some, _} -> split(tail, tokens, acc <> some)
    end
  end

  def read_string(s) do
    read_string(s, 0)
  end

  def read_string(s, i) do
    char = String.at(s, i)
    case char do
      "\"" -> case String.split_at(s, i) do
        {str, tail} -> case String.split_at(tail, 1) do
          {"\"", rest} -> {{:String, str}, rest}
        end
      end
      "\\" -> read_string(s, i+2)
      _ -> read_string(s, i+1)
    end
  end

  def tokenize(word) do
    case word do
      "(" -> :LeftParen
      ")" -> :RightParen
      "#" -> :Sharp
      ":" -> :Colon
      " " -> :Space
      {:String, _} -> word
      _ -> identify(word)
    end
  end

  def tokenize_all(words) do
    Enum.map(words, fn word -> tokenize(word) end)
  end

  def identify(word) do
    if is_number_token(word) do
      {:Number, word}
    else case word do
      "t" -> "true"
      "nil" -> "null"
      _ -> {:Symbol, word}
    end
    end
  end

  def is_number_token(word) do
    String.match?(word, ~r/^[+-]?(([[:digit:]]+\.?[[:digit:]]*)|([[:digit:]]*\.?[[:digit:]]+))(e[+-]?[[:digit:]]+)?$/)
  end
end
