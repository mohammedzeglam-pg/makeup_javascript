defmodule MakeupJavascript.MixProject do
  use Mix.Project
  @version "0.1.0"
  @url "https://github.com/mohammedzeglam-pg/makeup_javascript"
  def project do
    [
      app: :makeup_javascript,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      name: :makeup_javascript,
      source_url: @url
    ]
  end

  def description do
    """
      Javascript lexer for the Makeup syntax highlighter.
    """
  end

  def package do
    [
      name: :makeup_javascript,
      licenses: ["BSD"],
      maintainers: ["Mohammed Zeglam <mohammedzeglam@gmail.com>"],
      links: %{"Github" => @url}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Makeup.Lexers.JavascriptLexer.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:makeup, "~> 1.0"},
      {:nimble_parsec, "~> 1.2.3 or ~> 1.3"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
