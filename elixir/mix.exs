defmodule Library.MixProject do
  use Mix.Project

  def project do
    [
      app: :library,
      version: "0.1.0",
      elixir: "~> 1.20",
      deps: [{:stream_data, "~> 1.0", only: [:dev, :test]}]
    ]
  end
end
