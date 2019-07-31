defmodule Macchiato.Parser do
  def parse(tokens) do
    parse(tokens, [], nil, 0)
  end

  def parse(tokens, acc, prev, nest) do
    case {prev, tokens} do

      {:Space, tokens} -> parse(tokens, acc, nil, nest)
      {nil, [:Space | tail]} -> parse(tail, acc, nil, nest)
      {some, [:Space | tail]} -> parse(tail, [some | acc], nil, nest)

      {nil, []} ->
        if nest === 0 do
          Enum.reverse(acc)
        else
          {:error, nil, :EOF}
        end

      # #
      {nil, [:Sharp | _]} -> {:error, nil, :Sharp}
      # foo##
      {[_ | :Sharp], [:Sharp | _]} -> {:error, acc, :Sharp}
      # foo#symbol
      {[some | :Sharp], [{:Symbol, symbol} | tail]} -> parse(tail, acc, [{:Symbol, symbol}, some], nest)
      {[_ | :Sharp], [{:String, str} | _]} -> {:error, :Sharp, {:String, str}}
      # foo#"bar"
      {[some | :Sharp], [some | _]} -> {:error, :Sharp, some}
      # foo#
      {some, [:Sharp | tail]} -> parse(tail, acc, [some | :Sharp], nest)

      {nil, [:LeftParen | tail]} -> 
        with {nested, rest} <- parse(tail, [], nil, nest+1) do
          parse(rest, acc, nested, nest)
        end
      {_, [:LeftParen | tail]} ->
        with {nested, rest} <- parse(tail, [], nil, nest+1) do
          parse(rest, [prev | acc], nested, nest)
        end
      {nil, [:RightParen | tail]} ->
        if nest === 0 do
          {:error, nil, :RightParen}
        else
          {Enum.reverse(acc), tail}
        end
      {some, [:RightParen | tail]} ->
        if nest === 0 do
          {:error, some, :RightParen}
        else
          {Enum.reverse([some | acc]), tail}
        end


      # :
      {nil, [:Colon | tail]} -> parse(tail, acc, :Colon, nest)
      # :symbol
      {:Colon, [{:Symbol, symbol} | tail]} -> parse(tail, acc, {:Keyword, symbol}, nest)
      # :foo:bar
      {{:Keyword, _}, [:Colon | _]} -> {:error, prev, :Colon}
      # symbol:
      {{:Symbol, _}, [:Colon | tail]} -> parse(tail, acc, [prev | :Colon], nest)
      # Access:
      {{:Access, _, _}, [:Colon | tail]} -> parse(tail, acc, [prev | :Colon], nest)
      # "foo":
      #{some, [:Colon | tail]} -> parse(tail, acc, [some | :Colon], nest)
      {some, [:Colon | _]} -> {:error, some, :Colon}
      # symbol1:symbol2
      {[some | :Colon], [{:Symbol, symbol} | tail]} -> parse(tail, acc, {:Access, some, {:Symbol, symbol}}, nest)
      # "foo"::
      {[_ | :Colon], [:Colon | _]} -> {:error, acc, :Colon}
      # symbol:)
      {[_ | :Colon], [some | _]} -> {:error, :Colon, some}
      # :"foo"
      {:Colon, some} -> {:error, :Colon, some}

      {nil, [some | tail]} -> parse(tail, acc, some, nest)
      {some1, [some2 | tail]} -> parse(tail, [some1 | acc], some2, nest)


      {some, []} -> parse([], [some | acc], nil, nest)
    end
  end
end
