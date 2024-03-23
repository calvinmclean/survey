import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/erlang

// no default means it is required
// help is only used for ask_help or if invalid input is provided

/// Configure a survey prompt to present to the user.
/// 
/// Question allows receiving freeform String responses
/// 
/// Confirmation presents the user with a [y/n] prompt to record a Bool response
pub type Survey {
  /// Question allows receiving freeform String responses
  ///   - `prompt`: printed prompt so the user knows expectations
  ///   - `help`: optional help message to display if input is invalid or using `ask_help`
  ///   - `default`: optional default to use if empty input is received. If this is None, then input is required
  ///   - `validate`: optional validation function to determine if input is acceptable
  ///   - `transform`: optional transformation function to modify input
  Question(
    prompt: String,
    help: Option(String),
    default: Option(String),
    validate: Option(fn(String) -> Bool),
    transform: Option(fn(String) -> String),
  )

  /// Confirmation presents the user with a [y/n] prompt to record a Bool response
  ///   - `prompt`: printed prompt so the user knows expectations
  ///   - `help`: optional help message to display if input is invalid or using `ask_help`
  ///   - `default`: optional default to use if empty input is received. If this is None, then input is required.
  ///     - `[y/n]`, `[Y/n]`, `[y/N]` are added to the prompt for default None, True, and False respectively
  ///   - `transform`: optional transformation function to modify input
  Confirmation(
    prompt: String,
    help: Option(String),
    default: Option(Bool),
    transform: Option(fn(Bool) -> Bool),
  )
}

/// Constructor for a Question that can make code more readable with labelled arguments
///
/// ## Example
///
/// ```gleam
/// survey.new_question(
///   prompt: "First Name:",
///   help: Some("Please enter your first name"),
///   default: None,
///   validate: None,
///   transform: None,
/// ),
/// ```
pub fn new_question(
  prompt prompt: String,
  help help: Option(String),
  default default: Option(String),
  validate validate: Option(fn(String) -> Bool),
  transform transform: Option(fn(String) -> String),
) -> Survey {
  Question(prompt, help, default, validate, transform)
}

/// Constructor for a Confirmation that can make code more readable with labelled arguments
///
/// ## Example
///
/// ```gleam
/// survey.new_confirmation(
///   prompt: "Are you a survey fan?:",
///   help: Some("It's a great library"),
///   default: Some(True),
///   transform: Some(fn(_: Bool) -> Bool { True }),
/// ),
/// ```
pub fn new_confirmation(
  prompt prompt: String,
  help help: Option(String),
  default default: Option(Bool),
  transform transform: Option(fn(Bool) -> Bool),
) -> Survey {
  Confirmation(prompt, help, default, transform)
}

/// Answer is used to have different result types for Questions and Confirmations. Also allows handling errors
pub type Answer {
  StringAnswer(String)
  BoolAnswer(Bool)
  AnswerError(AskError)
  NoAnswer
}

/// AskError are different errors that could occur when handling prompts
pub type AskError {
  // error from erlang.get_line
  Input
  // invalid type returned from command line input. this should not be possible
  InvalidType
  // failure of the user-provided 'validate' function
  Validation
}

/// GetLineFn is a function which accepts a prompt String and returns user input line.
/// It allows using `ask_fn` with custom input handling (useful for testing or other purposes)
type GetLineFn =
  fn(String) -> Result(String, AskError)

fn default_get_line(prompt: String) -> Result(String, AskError) {
  case erlang.get_line(prompt) {
    Ok(s) -> Ok(s)
    Error(_) -> Error(Input)
  }
}

/// ask will present the user with a prompt and handle the Answer
pub fn ask(q: Survey) -> Answer {
  ask_fn(q, default_get_line)
}

/// same as `ask`, but allows providing a custom input handler
pub fn ask_fn(q: Survey, get_line: GetLineFn) -> Answer {
  let input =
    case q {
      Question(_, _, _, _, _) -> q.prompt <> " "
      Confirmation(_, _, default, _) -> q.prompt <> confirm_prompt(default)
    }
    |> get_line

  case input {
    Ok(result) ->
      result
      |> string.trim
      |> handle_input(q)
    Error(_) -> AnswerError(Input)
  }
}

/// this is the same as `ask`, but it prints the help message before the prompt
pub fn ask_help(q: Survey) -> Answer {
  ask_help_fn(q, default_get_line)
}

/// same as `ask_help`, but allows providing a custom input handler
pub fn ask_help_fn(q: Survey, get_line: GetLineFn) -> Answer {
  case q.help {
    Some(help_msg) -> io.println(help_msg)
    None -> Nil
  }

  ask_fn(q, get_line)
}

/// ask_many allows presenting the user with many prompts sequentially
pub fn ask_many(qs: List(#(String, Survey))) -> List(#(String, Answer)) {
  ask_many_fn(qs, [])
}

/// same as `ask_many`, but allows providing a custom input handler
pub fn ask_many_fn(
  qs: List(#(String, Survey)),
  get_lines: List(GetLineFn),
) -> List(#(String, Answer)) {
  ask_many_loop(qs, ask, get_lines)
}

/// same as `ask_many`, but prints help message before each prompt
pub fn ask_many_help(qs: List(#(String, Survey))) -> List(#(String, Answer)) {
  ask_many_loop(qs, ask_help, [])
}

fn ask_many_loop(
  qs: List(#(String, Survey)),
  ask: fn(Survey) -> Answer,
  get_lines: List(GetLineFn),
) -> List(#(String, Answer)) {
  let f = fn(
    qs: List(#(String, Survey)),
    ask: fn(Survey) -> Answer,
    get_line: GetLineFn,
    get_lines: List(GetLineFn),
  ) -> List(#(String, Answer)) {
    case qs {
      [] -> []
      [#(key, q)] -> [#(key, ask_fn(q, get_line))]
      [#(key, q), ..tail] -> [
        #(key, ask_fn(q, get_line)),
        ..ask_many_loop(tail, ask, get_lines)
      ]
    }
  }

  case get_lines {
    [] -> f(qs, ask, default_get_line, [])
    [get_line, ..get_lines_tail] -> f(qs, ask, get_line, get_lines_tail)
  }
}

fn handle_input(input: String, q: Survey) -> Answer {
  case q {
    Question(_, _, _, validate, _) -> {
      let validate_fn = case validate {
        Some(val_fn) -> val_fn
        None -> fn(_: String) -> Bool { True }
      }

      case input {
        "" -> handle_default(q)
        _ ->
          case validate_fn(input) {
            True -> StringAnswer(input)
            False -> ask_help(q)
          }
      }
    }

    Confirmation(_, _, _, _) ->
      case input {
        "Y" | "y" -> BoolAnswer(True)
        "N" | "n" -> BoolAnswer(False)
        "" -> handle_default(q)
        _ -> ask_help(q)
      }
  }
  |> handle_transform(q)
}

// this does some tedious type checking in order to allow transform functions to work with
// Bool/String instead of having to use Answer. This also has to check the StringAnswer/BoolAnswer
// types even though it should be impossible to encounter the incorrec type... I think this is a good
// tradeoff because it makes it easier for users
// counterpoint: if transform accepts Answer, then it can be used to transform to different types
fn handle_transform(a: Answer, q: Survey) -> Answer {
  case q {
    Question(_, _, _, _, transform) ->
      case transform {
        None -> a
        Some(tr) ->
          case a {
            StringAnswer(s) -> StringAnswer(tr(s))
            _ -> AnswerError(InvalidType)
          }
      }

    Confirmation(_, _, _, transform) ->
      case transform {
        None -> a
        Some(tr) ->
          case a {
            BoolAnswer(s) -> BoolAnswer(tr(s))
            _ -> AnswerError(InvalidType)
          }
      }
  }
}

fn handle_default(q: Survey) -> Answer {
  case q {
    Question(_, _, default, _, _) ->
      case default {
        Some(def) -> StringAnswer(def)
        None -> ask_help(q)
      }
    Confirmation(_, _, default, _) ->
      case default {
        Some(def) -> BoolAnswer(def)
        None -> ask_help(q)
      }
  }
}

fn confirm_prompt(default: Option(Bool)) -> String {
  case default {
    option.Some(default_true) if default_true -> " [Y/n] "
    option.Some(_) -> " [y/N] "
    option.None -> " [y/n] "
  }
}
