defmodule Saul.Mixfile do
  use Mix.Project

  @description "Data validation and conformation library for Elixir."

  @repo_url "https://github.com/whatyouhide/saul"

  @version "0.1.0"

  def project() do
    [
      app: :saul,
      version: @version,
      elixir: "~> 1.4",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),

      # Hex
      package: package(),
      description: @description,

      # Docs
      name: "Saul",
      docs: [
        main: "Saul",
        source_ref: "v#{@version}",
        source_url: @repo_url,
      ],
    ]
  end

  def application() do
    [extra_applications: []]
  end

  defp package() do
    [
      maintainers: ["Andrea Leopardi"],
      licenses: ["ISC"],
      links: %{"GitHub" => @repo_url},
    ]
  end

  defp deps() do
    [{:ex_doc, "~> 0.15", only: :dev}]
  end
end
