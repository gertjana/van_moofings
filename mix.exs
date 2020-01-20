defmodule VanMoofing.MixProject do
  use Mix.Project

  def project do
    [
      app: :van_moofing,
      escript: [main_module: VanMoofing.CLI],
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {VanMoofing, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_cli, "~> 0.1.0"},
      {:poison, "~> 3.1"},
      {:number, "~> 1.0.1"}
    ]
  end
end
