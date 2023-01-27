defmodule PetrusAgentTest do
  use ExUnit.Case
  doctest PetrusAgent

  test "greets the world" do
    assert PetrusAgent.hello() == :world
  end
end
