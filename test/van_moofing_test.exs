defmodule VanMoofingTest do
  use ExUnit.Case
  doctest VanMoofing

  @store "./test/test.json"
\
  setup_all do
    {:ok, moofings} = VanMoofing.load_from_file(@store)
    {:ok, moofings: moofings}
  end

  test "loads and parser moofings json", state do
    assert is_map(state[:moofings])
  end

  test "current bike", state do
    current_bike = VanMoofing.get_current_bike(state[:moofings])
    assert current_bike.current == true
    assert current_bike.name == "coronita"
  end

  test "list values for current bike", _state do
    assert true
  end

  test "add a value for current bike", state do
    date = "2020-09-07"
    value = 320
    updated = VanMoofing.add_value(state[:moofings], date, value)
    size = length(VanMoofing.get_current_bike(updated).data)
    assert size == 3
    measurement = VanMoofing.get_current_bike(updated).data |> List.first
    assert date == measurement.date
    assert value == measurement.km
  end

  test "calculate trend", _state do
    assert true
  end

  test "calculate total for other bikes", state do
    total = VanMoofing.get_total_other_bikes(state[:moofings])
    assert 9603 == total
  end

end
