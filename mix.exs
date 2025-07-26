defmodule Led.MixProject do
  use Mix.Project

  def project do
    [
      app: :led,
      version: "0.1.0",
      description:
        "Blink LEDs or relays via GPIO with ease. Features artful gimmicks for creative setups.",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # ExDocs
      source_url: "https://github.com/alexisruccius/led",
      homepage_url: "https://github.com/alexisruccius/led",
      docs: docs(),
      # Hex
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_gpio, "~> 2.1"},
      {:circuits_sim, "~> 0.1.2"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  # ExDocs
  defp docs do
    [
      # The main page in the docs
      main: "LED",
      logo: "assets/LED-logo.jpg",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  # Hex package
  defp package do
    [
      maintainers: ["Alexis Ruccius"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/alexisruccius/led"}
    ]
  end
end
