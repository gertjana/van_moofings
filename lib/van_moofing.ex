defmodule VanMoofing do
  use Number
  @store "~/.vanmoofing.json"
  @ets_store :van_moofings

  def start(_type, _args) do
		:ets.new(@ets_store, [:set, :public, :named_table])

    if !File.exists?(Path.expand(@store)), do: File.write(Path.expand(@store), "{}")

		with {:ok, body} <- File.read(Path.expand(@store)),
         {:ok, moofings} <- Poison.decode(body) do
           goal = moofings["goal"]
           data = moofings["data"]
           years = Map.keys(data)
           :ets.insert(@ets_store, {:goal, goal})
           Enum.each(years, fn year -> :ets.insert(@ets_store, {String.to_atom(year), Map.get(data, year)}) end)
           :ets.insert(@ets_store, {:years, years})
         end
    {:ok, self()}
  end

  # @spec get(String.t()) :: Nil | {String.t(), Integer}
  def get(date) do
    case list(year(date)) |> Enum.filter(fn {d, _km} -> d == date end) do
      [head, _] -> head
      _ -> nil
    end
  end

  @spec list(String.t()) :: [{String.t, Integer}]
  def list(year) do
    y = String.to_atom(year)
    :ets.lookup(@ets_store, y)[y]
      |> Enum.map(fn {date, value} -> {date, value} end)
      |> List.keysort(0)
  end

  @spec save(String.t(), String.t(), String.t()) :: :ok | {:error, atom}
  def save(date, value, year) do
    new_map = Enum.into(list(year), %{})
    data = :ets.lookup(@ets_store, :years)[:years]
               |> Enum.map(fn y when y == year -> {y, Map.put(new_map, date, value)}
                              y  -> {y, list(y) |> Enum.into(%{})} end)
               |> Enum.into(%{})
    goal = :ets.lookup(@ets_store, :goal)[:goal]
    moofings = %{"goal" => goal, "data" => data}
    {:ok, json} = Poison.encode(moofings, pretty: true)
    File.write(Path.expand(@store), json)
  end

  @spec add(String.t(), Integer) :: String.t()
  def add(date, km) do
    case get(date) do
      nil ->
        save(date, km, year(date))
        "added #{km} for #{date}"
      _ ->
        "Entry for #{date} already exists"
    end
  end

  @spec trend_eoy(String.t()) :: {float, integer, float, float,float, float}
  def trend_eoy(year) do
    trend(list(year), "#{year}-12-31")
  end

  @spec trend([{String.t(), Integer}], String.t) :: {float, integer, float, float, float, float}
  def trend(moofings, new_date) do
    goal = :ets.lookup(@ets_store, :goal)[:goal]
    {last_date, last_value} = List.last(moofings)
    [h | t] = moofings
    acc = loop([],h, t)
    case acc do
      [] -> 0
      _ ->
        avg = Enum.sum(acc) / Enum.count(acc)
        days = diff_string_date(last_date, new_date)
        avg_goal = (goal - last_value) / days
        {avg, days, Float.round(avg * days + last_value), Float.round(avg * days + last_value - elem(h, 1)), goal, avg_goal}
    end
  end

  defp loop(acc, _, []), do: acc
  defp loop(acc, nil, [head| tail]), do: loop(acc, head, tail)
  defp loop(acc, {prev_date, prev_value}, [{date, value} | tail]) do
    diff = diff_integer(prev_value, value) / diff_string_date(prev_date, date)
    loop([diff | acc], {date, value}, tail)
  end

  defp year(date), do: Date.from_iso8601!(date).year |> Integer.to_string

  defp diff_string_date(d1, d2), do: Date.diff(Date.from_iso8601!(d2), Date.from_iso8601!(d1))
  defp diff_integer(v1,v2), do: v2-v1
end

