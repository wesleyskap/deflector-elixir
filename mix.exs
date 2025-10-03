defmodule Deflector.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :deflector,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Resilient circuit breaker, process bulkhead and rate limiter engine for Elixir.",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Deflector.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/wesleyskap/deflector-elixir"}
    ]
  end
end