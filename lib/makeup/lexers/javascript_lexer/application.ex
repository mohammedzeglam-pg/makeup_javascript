defmodule Makeup.Lexers.JavascriptLexer.Application do
  @moduledoc false
  use Application

  alias Makeup.Lexers.JavascriptLexer
  alias Makeup.Registry

  def start(_type, _args) do
    Registry.register_lexer(JavascriptLexer,
      options: [],
      names: ["javascript", "js"],
      extensions: ["js", "mjs", "cjs"]
    )

    Supervisor.start_link([], strategy: :one_for_one)
  end
end
