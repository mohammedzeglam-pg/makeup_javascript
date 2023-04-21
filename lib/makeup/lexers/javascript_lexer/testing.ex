defmodule Makeup.Lexers.JavascriptLexer.Testing do
  @moduledoc false
  alias Makeup.Lexers.JavascriptLexer

  alias Makeup.Lexer.Postprocess

  @sample_a """
  //---------------------------------------
  const iterativeFunction = function(arr, x) {

    let start=0, end=arr.length-1;
         while (start<=end){
        let mid=Math.floor((start + end)/2);

        if (arr[mid]===x) return true;

        else if (arr[mid] < x)
             start = mid + 1;
        else
             end = mid - 1;
    }

    return false;
  }
  """
  @sample_b """
  let a = 5_000_000;
  let b = 0xAaFf
  let c = 0o53124
  let d = 0b1010111
  """
  def lex_a(), do: @sample_a |> lex()
  def lex_b(), do: @sample_b |> lex()
  # This function has two purposes:
  # 1. Ensure deterministic lexer output (no random prefix)
  # 2. Convert the token values into binaries so that the output
  #    is more obvious on visual inspection
  #    (iolists are hard to parse by a human)
  def lex(text) do
    text
    |> JavascriptLexer.lex(group_prefix: "group")
    |> Postprocess.token_values_to_binaries()
    |> Enum.map(fn {ttype, meta, value} -> {ttype, Map.delete(meta, :language), value} end)
  end
end
