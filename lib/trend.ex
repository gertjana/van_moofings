defmodule Trend do
  defprotocol Diff do
    def diff(this,that)
  end

  defimpl Diff, for: Integer do
    def diff(this, that), do: that-this
  end

  defimpl Diff, for: Date do
    def diff(this, that), do: Date.diff(that, this)
  end

  defstruct [:key, :value]

  # @spec trend([Trend], Date) :: float
  # def trend(moofings, new_date) do
  #   last = List.last(moofings)
  #   [h | t] = moofings
  #   acc = loop([],h, t)
  #   case acc do
  #     [] -> last.value
  #     _ ->
  #       avg = Enum.sum(acc) / Enum.count(acc)
  #       # days = diff_string_date(last.date, new_date)
  #       # avg * days + last.value
  #   end
  # end

  # defp loop(acc, _, []), do: acc

  # defp loop(acc, prev, [h | t]) do
  #   diff = diff_integer(prev.value, h.value) / diff_string_date(prev.date, h.date)
  #   loop([diff | acc], h, t)
  # end
end
