defmodule VanMoofing.CLI do
  use ExCLI.DSL, escript: true
  @moduledoc """
  Documentation for Van Moofing.
  """

  name "VanMoofing"
  description "Record km cycled on a van Moof"

  command :add do
    aliases [:a]
    description "[km] Adds the current total nr of kilometers value"

    argument :km, type: :integer, help: "Current Km's as shown in the Van Moof App"

    run context do
      VanMoofing.add(get_date(), context[:km])
    end
  end

  command :add_after do
    aliases [:aa]
    description "[date] [km] Adds the current total nr of kilometers value at the specified date"

    argument :date, type: :string, help: "The particular date a certain amounts of Km are cycles"
    argument :km, type: :integer, help: "Current Km's as shown in the Van Moof App"

    run context do
      VanMoofing.add(context[:date], context[:km])
    end
  end

  # command :list_all do
  #   aliases [:la]
  #   description("List all stored values")
  #   run _context do
  #     VanMoofing.list_all()
  #       |> Enum.each(fn vm -> pr(vm) end)
  #   end
  # end

  command :list do
    aliases [:l]
    description("[year] List all stored values for the specified year")

    argument :year, type: :integer, help: "[year] The year to list"
    run context do
      IO.puts "Date      \tKm's cycled"
      year = context[:year] |> Integer.to_string
      VanMoofing.list(year) |> Enum.each(fn vm -> pr(vm) end)
    end
  end

  command :trend do
    aliases [:t]

    argument :year, type: :string, help: "[year] how much have km will be cycled at the end of the year"
    description "[year] Predicts the neumber of Kilometers cycled in a year"
    run context do
      year = context[:year]
      {avg, days, total, this_year} = VanMoofing.trend_eoy(year)
      IO.puts "With a average of #{Number.Delimit.number_to_delimited(avg)} km a day and #{days} days till the end of the year, "
      IO.puts "you will probably cycle : #{this_year} km in #{year} for a grand total of #{total} km"
    end
  end

  command :export do
    aliases [:e]

    argument :year, type: :string, help: "[year] how much have km will be cycled at the end of the year"
    description "[year] exports the list of kilometers cycled in a year"
    run context do
      year = context[:year]
      IO.puts "\"date\", \"km\", \"trend\""
      VanMoofing.list(year)
        |> Enum.each(fn {k, v} -> IO.puts("\"#{k}\", #{v}, #{v}") end)
      {_, _, total, _} = VanMoofing.trend_eoy(year)
      IO.puts("\"#{year}-12-31\", , #{total}")
    end

  end

  defp get_date(), do: Date.utc_today |> Date.to_iso8601

  defp pr(moofing) do
    with {k,v} <- moofing, do: IO.puts "#{k}\t#{v} km"
  end
end
