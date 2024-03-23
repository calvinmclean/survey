import gleeunit
import gleeunit/should
import survey
import gleam/option.{type Option, None, Some}

pub fn main() {
  // I cannot import None/Some without Option even if Option is unused so this prevents a warning
  let _: Option(Nil) = Some(Nil)

  gleeunit.main()
}

fn inject_input(input: String) -> survey.GetLineFn {
  fn(_: String) -> Result(String, survey.AskError) { Ok(input) }
}

fn inject_input_assert_prompt(
  input: String,
  expected_prompt: String,
) -> survey.GetLineFn {
  fn(prompt: String) -> Result(String, survey.AskError) {
    prompt
    |> should.equal(expected_prompt)

    Ok(input)
  }
}

pub fn constructor_fn_test() {
  survey.new_question(
    "First Name:",
    help: None,
    default: Some("Calvin"),
    validate: None,
    transform: None,
  )
  |> survey.ask_fn(inject_input_assert_prompt("", "First Name: "))
  |> should.equal(survey.StringAnswer("Calvin"))

  survey.new_confirmation(
    "Confirm?",
    help: None,
    default: None,
    transform: None,
  )
  |> survey.ask_fn(inject_input_assert_prompt("Y", "Confirm? [y/n] "))
  |> should.equal(survey.BoolAnswer(True))
}

pub fn confirm_default_false_test() {
  let q = survey.Confirmation("Confirm?", None, Some(False), None)

  survey.ask_fn(q, inject_input_assert_prompt("Y", "Confirm? [y/N] "))
  |> should.equal(survey.BoolAnswer(True))

  survey.ask_fn(q, inject_input("N"))
  |> should.equal(survey.BoolAnswer(False))

  survey.ask_fn(q, inject_input(""))
  |> should.equal(survey.BoolAnswer(False))
}

pub fn confirm_default_true_test() {
  let q = survey.Confirmation("Confirm?", None, Some(True), None)

  survey.ask_fn(q, inject_input_assert_prompt("Y", "Confirm? [Y/n] "))
  |> should.equal(survey.BoolAnswer(True))

  survey.ask_fn(q, inject_input("N"))
  |> should.equal(survey.BoolAnswer(False))

  survey.ask_fn(q, inject_input(""))
  |> should.equal(survey.BoolAnswer(True))
}

pub fn confirm_no_default_prompt_test() {
  let q = survey.Confirmation("Confirm?", None, None, None)

  survey.ask_fn(q, inject_input_assert_prompt("Y", "Confirm? [y/n] "))
  |> should.equal(survey.BoolAnswer(True))

  survey.ask_fn(q, inject_input("N"))
  |> should.equal(survey.BoolAnswer(False))

  survey.ask_fn(q, inject_input(""))
  |> should.equal(survey.AnswerError(survey.Input))
}

pub fn question_default_test() {
  let q = survey.Question("", None, Some("default"), None, None)

  survey.ask_fn(q, inject_input(""))
  |> should.equal(survey.StringAnswer("default"))

  survey.ask_fn(q, inject_input("not default"))
  |> should.equal(survey.StringAnswer("not default"))
}

pub fn confirm_transform_test() {
  let q =
    survey.Confirmation("", None, Some(False), Some(fn(b: Bool) -> Bool { !b }))

  survey.ask_fn(q, inject_input("Y"))
  |> should.equal(survey.BoolAnswer(False))
}

pub fn question_transform_test() {
  let q =
    survey.Question(
      "",
      None,
      Some("default"),
      None,
      Some(fn(s: String) -> String { s <> "_EXTRA" }),
    )

  survey.ask_fn(q, inject_input("INPUT"))
  |> should.equal(survey.StringAnswer("INPUT_EXTRA"))
}

pub fn question_validate_test() {
  let q =
    survey.Question(
      "",
      None,
      None,
      Some(fn(result: String) -> Bool {
        case result {
          "Good" -> True
          _ -> False
        }
      }),
      None,
    )

  survey.ask_fn(q, inject_input("Bad"))
  |> should.equal(survey.AnswerError(survey.Validation))

  survey.ask_fn(q, inject_input("Good"))
  |> should.equal(survey.StringAnswer("Good"))
}

pub fn ask_many_test() {
  let qs = [
    #(
      "first_name",
      survey.new_question(
        "First Name:",
        help: Some("Please enter your first name"),
        default: None,
        validate: None,
        transform: None,
      ),
    ),
    #(
      "last_name",
      survey.Question(
        "Last Name:",
        Some("Please enter your last name"),
        None,
        None,
        None,
      ),
    ),
  ]

  let results =
    survey.ask_many_fn(qs, [inject_input("Calvin"), inject_input("McLean")])

  results
  |> should.equal([
    #("first_name", survey.StringAnswer("Calvin")),
    #("last_name", survey.StringAnswer("McLean")),
  ])
}
