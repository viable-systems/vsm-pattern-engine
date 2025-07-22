defmodule VsmPatternEngineTest do
  use ExUnit.Case
  doctest VsmPatternEngine

  test "greets the world" do
    assert VsmPatternEngine.hello() == :world
  end
end
