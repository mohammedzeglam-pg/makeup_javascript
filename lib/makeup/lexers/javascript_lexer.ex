defmodule Makeup.Lexers.JavascriptLexer do
  @moduledoc """
  A `Makeup` lexer for Javascript language.
  """

  import NimbleParsec
  import Makeup.Lexer.Combinators
  import Makeup.Lexer.Groups
  import Makeup.Lexers.JavascriptLexer.Helper
  @behaviour Makeup.Lexer

  ###################################################################
  # Step #1: tokenize the input (into a list of tokens)
  ###################################################################
  # We will often compose combinators into larger combinators.
  # Sometimes, the smaller combinator is usefull on its own as a token, and sometimes it isn't.
  # We'll adopt the following "convention":
  #
  # 1. A combinator that ends with `_name` returns a string
  # 2. Other combinators will *usually* return a token
  #
  # Why this convention? Tokens can't be composed further, while raw strings can.
  # This way, we immediately know which of the combinators we can compose.
  # TODO: check we're following this convention

  whitespace = ascii_string([?\r, ?\s, ?\n, ?\f], min: 1) |> token(:whitespace)
  any_char = utf8_char([]) |> token(:error)

  # Numbers
  digits = ascii_string([?0..?9], min: 1)
  bin_digits = ascii_string([?0..?1], min: 1)
  hex_digits = ascii_string([?0..?9, ?a..?f, ?A..?F], min: 1)
  oct_digits = ascii_string([?0..?7], min: 1)

  # Digits in an integer may be separated by underscores
  number_bin_part = with_optional_separator(bin_digits, "_")
  number_oct_part = with_optional_separator(oct_digits, "_")
  number_hex_part = with_optional_separator(hex_digits, "_")
  integer = with_optional_separator(digits, "_")

  # Tokens for the lexer
  number_bin = string("0b") |> concat(number_bin_part) |> token(:number_bin)
  number_oct = string("0o") |> concat(number_oct_part) |> token(:number_oct)
  number_hex = string("0x") |> concat(number_hex_part) |> token(:number_hex)
  # Base 10
  number_integer = token(integer, :number_integer)

  # Floating point numbers
  float_scientific_notation_part =
    ascii_string([?e, ?E], 1)
    |> optional(string("-"))
    |> concat(integer)

  number_float =
    integer
    |> string(".")
    |> concat(integer)
    |> optional(float_scientific_notation_part)
    |> token(:number_float)

  variable_name =
    ascii_string([?a..?z, ?_], 1)
    |> optional(ascii_string([?a..?z, ?_, ?0..?9, ?A..?Z], min: 1))
    |> optional(ascii_string([??, ?!], 1))

  # Can also be a function name
  variable =
    variable_name
    |> lexeme()
    |> token(:name)

  define_name =
    ascii_string([?A..?Z], 1)
    |> optional(ascii_string([?a..?z, ?_, ?0..?9, ?A..?Z], min: 1))

  define = token(define_name, :name_constant)

  operator_name = word_from_list(~W(
      => + -  * / % ++ -- ** ~ ^ & && | ||
      =  += -= *= /= &= |= %= ^= **= &&= ||= ??= << >> >>>
      > < >= <= == != ! ? : ??
      ))

  operator = token(operator_name, :operator)

  normal_char =
    string("?")
    |> utf8_string([], 1)
    |> token(:string_char)

  escape_char =
    string("?\\")
    |> utf8_string([], 1)
    |> token(:string_char)

  directive =
    string("#")
    |> concat(variable_name)
    |> token(:keyword_pseudo)

  punctuation =
    word_from_list(
      ["\\\\", ":", ";", ",", "."],
      :punctuation
    )

  delimiters_punctuation =
    word_from_list(
      ~W( ( \) [ ] { }),
      :punctuation
    )

  comment = many_surrounded_by(parsec(:root_element), "/*", "*/")

  delimiter_pairs = [
    delimiters_punctuation,
    comment
  ]

  normal_atom_name =
    utf8_string([?A..?Z, ?a..?z, ?_], 1)
    |> optional(utf8_string([?A..?Z, ?a..?z, ?_, ?0..?9, ?@], min: 1))

  unicode_char_in_string =
    string("\\u")
    |> ascii_string([?0..?9, ?a..?f, ?A..?F], 4)
    |> token(:string_escape)

  escaped_char =
    string("\\")
    |> utf8_string([], 1)
    |> token(:string_escape)

  combinators_inside_string = [
    unicode_char_in_string,
    escaped_char
  ]

  string_keyword =
    choice([
      string_like("\"", "\"", combinators_inside_string, :string_symbol),
      string_like("'", "'", combinators_inside_string, :string_symbol)
    ])
    |> concat(token(string(":"), :punctuation))

  normal_keyword =
    choice([operator_name, normal_atom_name])
    |> token(:string_symbol)
    |> concat(token(string(":"), :punctuation))

  keyword =
    choice([
      normal_keyword,
      string_keyword
    ])
    |> concat(whitespace)

  double_quoted_string_interpol = string_like("\"", "\"", combinators_inside_string, :string)

  line = repeat(lookahead_not(ascii_char([?\n])) |> utf8_string([], 1))

  inline_comment =
    string("//")
    |> concat(line)
    |> token(:comment_single)

  multiline_comment = string_like("/*", "*/", combinators_inside_string, :comment_multiline)

  root_element_combinator =
    choice(
      [
        whitespace,
        # Comments
        multiline_comment,
        inline_comment,
        # Syntax sugar for keyword lists (must come before variables and strings)
        directive,
        keyword,
        # Strings
        double_quoted_string_interpol
      ] ++
        [
          # Chars
          escape_char,
          normal_char
        ] ++
        delimiter_pairs ++
        [
          # Operators
          operator,
          # Numbers
          number_bin,
          number_oct,
          number_hex,
          # Floats must come before integers
          number_float,
          number_integer,
          # Names
          variable,
          define,
          punctuation,
          # If we can't parse any of the above, we highlight the next character as an error
          # and proceed from there.
          # A lexer should always consume any string given as input.
          any_char
        ]
    )

  # By default, don't inline the lexers.
  # Inlining them increases performance by ~20%
  # at the cost of doubling the compilation times...
  @inline false

  @doc false
  def __as_js_language__({ttype, meta, value}) do
    {ttype, Map.put(meta, :language, :js), value}
  end

  # Semi-public API: these two functions can be used by someone who wants to
  # embed an Elixir lexer into another lexer, but other than that, they are not
  # meant to be used by end-users.

  # @impl Makeup.Lexer
  defparsec(
    :root_element,
    map(root_element_combinator, {__MODULE__, :__as_js_language__, []}),
    inline: @inline
  )

  # @impl Makeup.Lexer
  defparsec(
    :root,
    repeat(parsec(:root_element)),
    inline: @inline
  )

  ###################################################################
  # Step #2: postprocess the list of tokens
  ###################################################################
  @keyword ~W[
    await break case catch class const
    continue debugger default do else export
    extends false finally for function if
    import let new return super switch static this
    throw try true var while with 
  ]
  @operator_word ~W[instanceof in void typeof delete]
  @keyword_constant ~W[
    NaN null undefined true false
   ]
  @name_builtin_pseudo ~W[__filename __dirname]

  defp postprocess_helper([]), do: []

  defp postprocess_helper([
         {:name, attrs, text},
         {:punctuation, %{language: :js}, "("}
         | tokens
       ]) do
    [
      {:name_function, attrs, text},
      {:punctuation, %{language: :js}, "("}
      | postprocess_helper(tokens)
    ]
  end

  defp postprocess_helper([{:name, attrs, text} | tokens]) when text in @keyword,
    do: [{:keyword, attrs, text} | postprocess_helper(tokens)]

  defp postprocess_helper([{:name, attrs, text} | tokens]) when text in @keyword_constant,
    do: [{:keyword_constant, attrs, text} | postprocess_helper(tokens)]

  defp postprocess_helper([{:name, attrs, text} | tokens]) when text in @operator_word,
    do: [{:operator_word, attrs, text} | postprocess_helper(tokens)]

  defp postprocess_helper([{:name, attrs, text} | tokens]) when text in @name_builtin_pseudo,
    do: [{:name_builtin_pseudo, attrs, text} | postprocess_helper(tokens)]

  # Unused variables
  defp postprocess_helper([{:name, attrs, "_" <> _name = text} | tokens]),
    do: [{:comment, attrs, text} | postprocess_helper(tokens)]

  # Otherwise, don't do anything with the current token and go to the next token.
  defp postprocess_helper([token | tokens]), do: [token | postprocess_helper(tokens)]

  # Public API
  @impl Makeup.Lexer
  def postprocess(tokens, _opts \\ []), do: postprocess_helper(tokens)

  ###################################################################
  # Step #3: highlight matching delimiters
  ###################################################################

  @impl Makeup.Lexer
  defgroupmatcher(:match_groups,
    parentheses: [
      open: [[{:punctuation, %{language: :js}, "("}]],
      close: [[{:punctuation, %{language: :js}, ")"}]]
    ],
    array: [
      open: [[{:punctuation, %{language: :js}, "["}]],
      close: [[{:punctuation, %{language: :js}, "]"}]]
    ],
    brackets: [
      open: [[{:punctuation, %{language: :js}, "{"}]],
      close: [[{:punctuation, %{language: :js}, "}"}]]
    ]
  )

  defp remove_initial_newline([{ttype, meta, text} | tokens]) do
    case to_string(text) do
      "\n" -> tokens
      "\n" <> rest -> [{ttype, meta, rest} | tokens]
    end
  end

  # Finally, the public API for the lexer
  @impl Makeup.Lexer
  def lex(text, opts \\ []) do
    group_prefix = Keyword.get(opts, :group_prefix, random_prefix(10))
    {:ok, tokens, "", _, _, _} = root("\n" <> text)

    tokens
    |> remove_initial_newline()
    |> postprocess([])
    |> match_groups(group_prefix)
  end
end
