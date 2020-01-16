defmodule VanMoofing do
  @store "~/.vanmoofing.json"
  @ets_store :van_moofings

  def start(_type, _args) do
		:ets.new(@ets_store, [:set, :public, :named_table])

    if !File.exists?(Path.expand(@store)), do: File.write(Path.expand(@store), "{}")
		with {:ok, body} <- File.read(Path.expand(@store)),
         {:ok, moofings} <- Poison.decode(body) do
           years = Map.keys(moofings)
           Enum.each(years, fn year -> :ets.insert(@ets_store, {String.to_atom(year), Map.get(moofings, year)}) end)
           :ets.insert(@ets_store, {:years, years})
         end
    {:ok, self()}
  end

  # @spec get(String.t()) :: Nil | {String.t(), Integer}
  def get(date) do
    case list(year(date)) |> Enum.filter(fn {k, _v} -> k == date end) do
      [h, _t] -> h
      _ -> nil
    end
  end

  # @spec list_all :: [VanMoofing]
  # def list_all() do
  #   :ets.lookup(@ets_store, :moofings)[:moofings]
  #     |> Enum.sort(fn(x, y) -> x.date < y.date end)
  # end

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
    moofings = :ets.lookup(@ets_store, :years)[:years]
               |> Enum.map(fn y when y == year -> {y, Map.put(new_map, date, value)}
                              y  -> {y, list(y) |> Enum.into(%{})} end)
               |> Enum.into(%{})
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

  @spec trend_eoy(String.t()) :: float
  def trend_eoy(year) do
    trend(list(year), "#{year}-12-31")
  end

  @spec trend([{String.t(), Integer}], String.t) :: float
  def trend(moofings, new_date) do
    {last_date, _last_value} = List.last(moofings)
    [h | t] = moofings
    acc = loop([],h, t)
    case acc do
      [] -> 0
      _ ->
        avg = Enum.sum(acc) / Enum.count(acc)
        days = diff_string_date(last_date, new_date)
        IO.puts "With a average of #{avg} km a day and #{days} days till the end of the year...."
        avg * days
    end
  end

  defp loop(acc, _, []), do: acc
  defp loop(acc, nil, [h | t]), do: loop(acc, h, t)
  defp loop(acc, {prev_date, prev_value}, [{date, value} | t]) do
    diff = diff_integer(prev_value, value) / diff_string_date(prev_date, date)
    loop([diff | acc], {date, value}, t)
  end

  defp year(date), do: Date.from_iso8601!(date).year |> Integer.to_string

  defp diff_string_date(d1, d2), do: Date.diff(Date.from_iso8601!(d2), Date.from_iso8601!(d1))
  defp diff_integer(v1,v2), do: v2-v1
end
