# survey

[![Package Version](https://img.shields.io/hexpm/v/survey)](https://hex.pm/packages/survey)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/survey/)

A library to easily create rich and interactive prompts in the terminal.

Inpired by [`AlecAivazis/survey`](https://github.com/AlecAivazis/survey)

Use `survey.Question` for `String` input and `survey.Confirmation` for `Bool` input.

```sh
gleam add survey
```
```gleam
import survey
import gleam/option.{type Option, None, Some}

pub fn main() {
  let assert [
    #("first_name", survey.StringAnswer(first_name)),
    #("last_name", survey.StringAnswer(last_name)),
    #("survey_fan", survey.BoolAnswer(survey_fan)),
  ] =
    [
      #(
        "first_name",
        survey.new_question(
          prompt: "First Name:",
          help: Some("Please enter your first name"),
          default: None,
          validate: None,
          transform: None,
        ),
      ),
      #(
        "last_name",
        survey.new_question(
          prompt: "Last Name:",
          help: Some("Please enter your last name"),
          default: None,
          validate: None,
          transform: None,
        ),
      ),
      #(
        "survey_fan",
        survey.new_confirmation(
          prompt: "Are you a survey fan?:",
          help: Some("It's a great library"),
          default: Some(True),
          transform: Some(fn(_: Bool) -> Bool { True }),
        ),
      ),
    ]
    |> survey.ask_many(help: False)

  case survey_fan {
    True -> io.println("Hello, " <> first_name <> " " <> last_name <> "!")
    False -> io.println("I don't believe you")
  }
}
```

```sh
⟩ gleam run
   Compiled in 0.02s
    Running survey.main
First Name: Survey
Last Name: User
Are you a survey fan?: [Y/n] 
Hello, Survey User!
```

Further documentation can be found at <https://hexdocs.pm/survey>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```
