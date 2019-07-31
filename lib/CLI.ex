defmodule Macchiato.CLI do
  def main(_args) do
    case IO.read(:stdio, :all) do
      {:error, reason} -> IO.puts reason
      data -> data |> Macchiato.process
    end
  end
end
