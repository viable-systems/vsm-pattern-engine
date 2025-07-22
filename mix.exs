defmodule VsmPatternEngine.MixProject do
  use Mix.Project

  def project do
    [
      app: :vsm_pattern_engine,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "VSM Pattern Recognition and Anomaly Detection Engine",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {VsmPatternEngine.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:tesla, "~> 1.7"},
      {:mint, "~> 1.5"},
      {:finch, "~> 0.16"},
      {:statistics, "~> 0.6"},
      {:timex, "~> 3.7"},
      {:flow, "~> 1.2"},
      {:gen_stage, "~> 1.2"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      name: "vsm_pattern_engine",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/viable-systems/vsm-pattern-engine"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
