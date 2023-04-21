defmodule JavascriptLexerTokinizerTestSnippet do
  use ExUnit.Case
  import Makeup.Lexers.JavascriptLexer.Testing, only: [lex: 1]

  test "?\\f is recognized as whitespace character" do
    assert lex("\f") == [{:whitespace, %{}, "\f"}]
  end

  test "newlines" do
    assert lex("1+\n2") == [
             {:number_integer, %{}, "1"},
             {:operator, %{}, "+"},
             {:whitespace, %{}, "\n"},
             {:number_integer, %{}, "2"}
           ]

    assert lex("1+\r\n2") == [
             {:number_integer, %{}, "1"},
             {:operator, %{}, "+"},
             {:whitespace, %{}, "\r\n"},
             {:number_integer, %{}, "2"}
           ]
  end

  test "unused variables" do
    assert lex("_123") == [{:comment, %{}, "_123"}]
    assert lex("_a") == [{:comment, %{}, "_a"}]
    assert lex("_unused") == [{:comment, %{}, "_unused"}]
  end

  # TODO: write more tests
end
