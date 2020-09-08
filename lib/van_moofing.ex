defmodule VanMoofing do
  use Number

  @store "~/.vanmoofing.json"
  @ets_store :van_moofings
  @model %Model.Bikes{bikes: [%Model.Bike{data: [%Model.Measurement{}]}]}

  def start(_type, _args) do
		:ets.new(@ets_store, [:set, :public, :named_table])

    if !File.exists?(Path.expand(@store)), do: File.write(Path.expand(@store), "{}")

    case load_from_file(@store) do
      {:ok, moofings} -> :ets.insert(@ets_store, {:moofings, moofings})
      {:error, err} -> IO.puts inspect(err)
    end
    {:ok, self()}
  end

  @spec load_from_file(binary) :: {:error, atom} | {:ok, map}
  def load_from_file(file) do
    with {:ok, body} <- File.read(Path.expand(file)),
         {:ok, moofings} <- Poison.decode(body, as: @model) do
      {:ok, moofings}
    else
      err -> err
    end
  end

  @spec get_current_bike(%Model.Bikes{}) :: %Model.Bike{}
  def get_current_bike(moofings) do
    Lens.key(:bikes)
      |> Lens.all()
      |> Lens.filter(fn b -> b.current==true end)
      |> Lens.to_list(moofings)
      |> List.first()
  end

  @spec filter_measurements_per_year(String.t, %Model.Bikes{}) :: [%Model.Measurement{}]
  def filter_measurements_per_year(year, moofings) do
    get_current_bike(moofings).data
      |> Enum.filter(fn measurement -> measurement.date |> String.starts_with?(year) end)
  end

  @spec list(String.t) :: [{String.t, integer}]
  def list(year) do
    moofings = :ets.lookup(@ets_store, :moofings)[:moofings]
    filter_measurements_per_year(year, moofings)
      |> Enum.map(fn m -> {m.date, m.km} end)
  end

  @spec add_value([%Model.Measurement{}], binary, integer) :: [%Model.Measurement{}]
  def add_value(moofings, date, value) do
    Lens.key(:bikes)
      |> Lens.all()
      |> Lens.filter(fn b -> b.current==true end)
      |> Lens.key(:data)
      |> Lens.map(moofings, fn d -> [%Model.Measurement{date: date, km: value} | d] end)
  end

  @spec add(binary, integer) :: :ok | {:error, atom}
  def add(date, value) do
    moofings = :ets.lookup(@ets_store, :moofings)[:moofings]
    updated = add_value(moofings, date, value)
    save_to_file(updated)
  end

  defp save_to_file(moofings) do
    {:ok, json} = Poison.encode(moofings, pretty: true)
    File.write(Path.expand(@store), json)
  end

  def save_goal(goal) do
    moofings = :ets.lookup(@ets_store, :moofings)[:moofings]
    updated = Lens.key(:goal) |> Lens.map(moofings, fn _ -> goal end)
    save_to_file(updated)
  end

  def get_total_other_bikes(moofings) do
    Lens.key(:bikes)
      |> Lens.all()
      |> Lens.filter(fn b -> b.current==false end)
      |> Lens.key(:data)
      |> Lens.to_list(moofings)
      |> Enum.map(fn [h|_] -> h.km end)
      |> Enum.sum
    end


  @doc """
    Linear trend analysis by calculating the average of all deltas of the measurements in an year
    and then extrapolate for the last day of the year
  """
  @spec trend_eoy(String.t) :: {float, integer, float, float,float, float}
  def trend_eoy(year) do
    moofings = :ets.lookup(@ets_store, :moofings)[:moofings]
    offset = get_total_other_bikes(moofings)
    trend(list(year), "#{year}-12-31", moofings.goal, offset)
  end

  @spec trend([{String.t, integer}], String.t, integer, integer) :: {float, integer, float, float, float, float}
  defp trend(moofings, new_date, goal, offset) do
    {last_date, last_value} = List.last(moofings)
    [h | t] = moofings
    acc = linear_interpolate([],h, t)
    case acc do
      [] -> 0
      _ ->
        avg = Enum.sum(acc) / Enum.count(acc)
        days = diff_string_date(last_date, new_date)
        avg_goal = (goal - last_value) / days
        total = Float.round(avg * days + last_value)+offset
        this_year = Float.round(avg * days + last_value - elem(h, 1))
        {avg, days, total, this_year, goal, avg_goal}
    end
  end

  defp linear_interpolate(acc, _, []), do: acc
  defp linear_interpolate(acc, nil, [head| tail]), do: linear_interpolate(acc, head, tail)
  defp linear_interpolate(acc, {prev_date, prev_value}, [{date, value} | tail]) do
    diff = diff_integer(prev_value, value) / diff_string_date(prev_date, date)
    linear_interpolate([diff | acc], {date, value}, tail)
  end

  defp diff_string_date(d1, d2), do: Date.diff(Date.from_iso8601!(d2), Date.from_iso8601!(d1))
  defp diff_integer(v1,v2), do: v2-v1
end
