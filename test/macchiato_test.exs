defmodule MacchiatoTest do
  use ExUnit.Case
  doctest Macchiato

  test "greets the world" do
    assert Macchiato.hello() == :world
  end
end
