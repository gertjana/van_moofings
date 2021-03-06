defmodule VanMoofing do
  @moduledoc false
  use Number

  @store "~/.vanmoofing.json"
  @ets_store :van_moofings
  @model %Model.Bikes{bikes: [%Model.Bike{data: [%Model.Measurement{}]}]}

  def start(_type, _args) do
    :ets.new(@ets_store, [:set, :protected, :named_table])

    if !File.exists?(Path.expand(@store)), do: File.write(Path.expand(@store), "{}")

    case load_from_file(@store) do
      {:ok, moofings} -> :ets.insert(@ets_store, {:moofings, moofings})
      {:error, err} -> IO.puts inspect(err)
    end
    {:ok, self()}
  end

  @spec load_from_file(String.t()) :: {:error, atom} | {:ok, Model.Bikes.t()}
  def load_from_file(file) do
    with {:ok, body} <- File.read(Path.expand(file)),
         {:ok, moofings} <- Poison.decode(body, as: @model) do
      {:ok, moofings}
    else
      err -> err
    end
  end

  defp save_to_file(moofings) do
    {:ok, json} = Poison.encode(moofings, pretty: true)
    File.write(Path.expand(@store), json)
  end

  @spec get_current_bike(Model.Bikes.t()) :: Model.Bike.t()
  def get_current_bike(moofings) do
    Lens.key(:bikes)
      |> Lens.all()
      |> Lens.filter(fn b -> b.current == true end)
      |> Lens.to_list(moofings)
      |> List.first()
  end

  @spec get_current_bike_name(Model.Bikes.t()) :: String.t
  def get_current_bike_name(moofings) do
    get_current_bike(moofings).name
  end

  @spec filter_measurements_per_year(String.t(), Model.Bikes.t()) :: [Model.Measurement.t()]
  def filter_measurements_per_year(year, moofings) do
    get_current_bike(moofings).data
      |> Enum.filter(fn measurement -> measurement.date |> String.starts_with?(year) end)
  end

  @spec list(binary) :: {binary, [{binary, integer}]}
  def list(year) do
    moofings = :ets.lookup(@ets_store, :moofings)[:moofings]
    current_bike_name = get_current_bike_name(moofings)
    measurements = filter_measurements_per_year(year, moofings)
      |> Enum.map(fn m -> {m.date, m.km} end)
    IO.puts inspect(measurements)
    {current_bike_name, measurements}
  end

  @spec add_value(Model.Bikes.t(), String.t(), integer) :: Model.Bikes.t()
  def add_value(moofings, date, value) do
    Lens.key(:bikes)
      |> Lens.all()
      |> Lens.filter(fn b -> b.current == true end)
      |> Lens.key(:data)
      |> Lens.front()
      |> Lens.put(moofings, %Model.Measurement{date: date, km: value})
  end

  @spec add(String.t(), integer) :: :ok | {:error, atom}
  def add(date, value) do
    moofings = :ets.lookup(@ets_store, :moofings)[:moofings]
    add_value(moofings, date, value)
      |> save_to_file
  end

  @spec save_goal(integer) :: :ok | {:error, atom}
  def save_goal(goal) do
    moofings = :ets.lookup(@ets_store, :moofings)[:moofings]
    Lens.key(:goal)
      |> Lens.put(moofings, goal)
      |> save_to_file
  end

  @spec get_total_other_bikes(Model.Bikes.t()) :: integer
  def get_total_other_bikes(moofings) do
    Lens.key(:bikes)
      |> Lens.all()
      |> Lens.filter(fn b -> b.current == false end)
      |> Lens.key(:data)
      |> Lens.to_list(moofings)
      |> Enum.map(fn [h|_] -> h.km end)
      |> Enum.sum
  end

  defp bike_exists?(moofings, bike_name) do
    Lens.key(:bikes)
      |> Lens.all
      |> Lens.filter(fn b -> b.name == bike_name end)
      |> Lens.to_list(moofings)
      |> length() > 0
  end

  @spec set_current_bike(String.t()) :: :ok | {:error, atom}
  def set_current_bike(bike_name) do
    moofings = :ets.lookup(@ets_store, :moofings)[:moofings]
    if bike_exists?(moofings, bike_name) do
      moofings
    else
      add_new_bike(moofings, bike_name)
    end
      |> update_current_bike(bike_name)
      |> save_to_file
  end

  @spec add_new_bike(%Model.Bikes{}, String.t) :: %Model.Bikes{}
  def add_new_bike(moofings, bike_name) do
    Lens.key(:bikes)
      |> Lens.front
      |> Lens.put(moofings, %Model.Bike{name: bike_name, data: []})
  end

  @spec update_current_bike(%Model.Bikes{}, String.t) :: %Model.Bikes{}
  def update_current_bike(moofings, bike_name) do
    Lens.key(:bikes)
      |> Lens.all()
      |> Lens.map(moofings, fn bike -> %{bike | current: (bike.name == bike_name)} end)
  end

  def list_all do
    moofings = :ets.lookup(@ets_store, :moofings)[:moofings]
    Lens.key(:bikes)
      |> Lens.all()
      |> Lens.multiple([Lens.key(:name), Lens.key(:data), Lens.key(:current)])
      |> Lens.to_list(moofings)
      |> Enum.chunk_every(3)
      |> Map.new(fn [b, [h|_], c] -> {b, {h.km, c}} end)
  end

  def export_all do
    moofings = :ets.lookup(@ets_store, :moofings)[:moofings]
    Lens.key(:bikes)
      |> Lens.all()
      |> Lens.multiple([Lens.key(:name), Lens.key(:data), Lens.key(:current)])
      |> Lens.to_list(moofings)
      |> Enum.chunk_every(3)
  end

  @doc """
    Linear trend analysis by calculating the average of all deltas of the measurements in an year
    and then extrapolate for the last day of the year
  """
  @spec trend_eoy(String.t()) :: {number, integer, number, number, number, number, binary}
  def trend_eoy(year) do
    moofings = :ets.lookup(@ets_store, :moofings)[:moofings]
    offset = get_total_other_bikes(moofings)
    {current_bike_name, kms} = list(year)
    trend(kms, "#{year}-12-31", moofings.goal, offset, current_bike_name)
  end

  @spec trend([{binary, integer}], binary, integer, integer, binary)
          :: {number, integer, number, number, number, number, binary}
  defp trend(moofings, new_date, goal, offset, current_bike_name) do
    {last_date, last_value} = List.first(moofings)
    [h | t] = moofings
    deltas = linear_interpolate([], h, t)
    case deltas do
      [] -> {0, 0, 0, 0, 0, 0, current_bike_name}
      _ ->
        avg = Enum.sum(deltas) / Enum.count(deltas)
        days = diff_string_date(last_date, new_date)
        avg_goal = (goal - offset - last_value) / days
        total = Float.round(avg * days + last_value) + offset
        this_year = Float.round(avg * days + last_value - elem(h, 1))
        {avg, days, total, this_year, goal, avg_goal, current_bike_name}
    end
  end

  defp linear_interpolate(acc, _, []), do: acc
  defp linear_interpolate(acc, {prev_date, prev_value}, [{date, value} | tail]) do
    diff = diff_integer(prev_value, value) / diff_string_date(prev_date, date)
    linear_interpolate([diff | acc], {date, value}, tail)
  end

  defp diff_string_date(d1, d2), do: Date.diff(Date.from_iso8601!(d2), Date.from_iso8601!(d1))
  defp diff_integer(v1, v2), do: v2 - v1
end
