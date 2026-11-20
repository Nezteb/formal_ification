defmodule Library.MixProject do
  use Mix.Project

  def project do
    [
      app: :library,
      version: "0.1.0",
      elixir: "~> 1.20",
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix],
        flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs]
      ]
    ]
  end

  defp deps do
    [
      {:stream_data, "~> 1.4", only: [:dev, :test]},
      {:propcheck, "~> 1.5", only: [:dev, :test]},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
