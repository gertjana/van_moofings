defmodule VanMoofing.CLI do
  use ExCLI.DSL, escript: true
  @moduledoc """
  Documentation for Van Moofing.
  """

  name "VanMoofing"
  description "Record km cycled on a bike that keeps a record of the cycled kilometers"

  command :export do
    aliases [:e]

    argument :year, type: :string, help: "[year] how much have km will be cycled at the end of the year"

    description "Alias: e\t\targs: [year]\t\tExports the list of kilometers cycled in a year in csv format"

    run context do
      year = context[:year]
      IO.puts "\"date\", \"km\", \"trend\""
      VanMoofing.list(year)
        |> Enum.each(fn {k, v} -> IO.puts("\"#{k}\", #{v}, #{v}") end)
      {_, _, total, _, _, _} = VanMoofing.trend_eoy(year)
      IO.puts("\"#{year}-12-31\", , #{total}")
    end
  end

  command :trend do
    aliases [:t]

    argument :year, type: :string, help: "[year] how much have km will be cycled at the end of the year"

    description "Alias: t\t\targs: [year]\t\tPredicts the number of kilometers cycled in a year"

    run context do
      year = context[:year]
      {avg, days, total, this_year, goal, avg_goal} = VanMoofing.trend_eoy(year)
      IO.puts "With a average of #{Number.Delimit.number_to_delimited(avg)} km a day and #{days} days till the end of the year, "
      IO.puts "you will probably cycle : #{this_year} km in #{year} for a grand total of #{total} km"
      case {total, goal} do
        {t, g} when t >= g -> IO.puts "You will reach your #{goal} km goal! Well done!"
        _ -> IO.puts "To reach your goal of #{goal} km you'll need to cycle an averagee of #{Number.Delimit.number_to_delimited(avg_goal)} km a day"\
      end
    end
  end

  command :list do
    aliases [:l]

    description("Alias: l\t\targs: [year]\t\tList all stored values for the specified year")

    argument :year, type: :integer, help: "[year] The year to list"

    run context do
      IO.puts "Date      \tKm's cycled"
      year = context[:year] |> Integer.to_string
      VanMoofing.list(year) |> Enum.each(fn vm -> pr(vm) end)
    end
  end

  command :add_after do
    aliases [:aa]
    description "Alias: aa\targs: [date] [km]\tAdds the current total nr of kilometers value at the specified date"

    argument :date, type: :string, help: "The particular date a certain amounts of Km are cycled"
    argument :km, type: :integer, help: "Current Km's as shown in the bike/app"

    run context do
      VanMoofing.add(context[:date], context[:km])
    end
  end

  command :add do
    aliases [:a]
    description "Alias: a\t\targs: [km] \t\tAdds the current total nr of kilometers value"

    argument :km, type: :integer, help: "Current Km's as shown in the bike/app"

    run context do
      VanMoofing.add(get_date(), context[:km])
    end
  end

  command :goal do
    aliases [:g]
    description "Alias: g\t\targs: [goal] \t\tSets a goal, only applies to the current year"

    argument :goal, type: :integer, help: "The goal you want to reach at the end of the year"

    run context do
      VanMoofing.save_goal(context[:goal])
    end
  end


  defp get_date(), do: Date.utc_today |> Date.to_iso8601

  defp pr(moofing) do
    with {k,v} <- moofing, do: IO.puts "#{k}\t#{v} km"
  end
end
