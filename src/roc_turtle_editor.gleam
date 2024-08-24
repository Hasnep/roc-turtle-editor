import filepath
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/int
import gleam/io
import gleam/string
import gleam/string_builder
import mist
import shellout
import simplifile
import temporary
import wisp.{type Request, type Response}
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  wisp.set_logger_level(wisp.InfoLevel)

  let secret_key_base = wisp.random_string(64)
  let assert Ok(_) =
    wisp_mist.handler(handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

fn handle_request(req: Request) -> Response {
  use _req <- middleware(req)
  case wisp.path_segments(req) {
    [] -> get_index_page(req)
    ["draw"] -> handle_draw_request(req)
    _ -> wisp.not_found()
  }
}

fn middleware(
  req: wisp.Request,
  handle_request: fn(Request) -> Response,
) -> Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  handle_request(req)
}

fn get_index_page(req: Request) -> Response {
  use <- wisp.require_method(req, Get)
  let assert Ok(index) = simplifile.read("static/index.html")
  wisp.html_response(string_builder.from_string(index), 200)
}

fn handle_draw_request(req: Request) -> Response {
  use <- wisp.require_method(req, Post)
  use body <- wisp.require_string_body(req)
  case run_script(body) {
    Ok(output) -> wisp.html_response(string_builder.from_string(output), 200)
    Error(err) ->
      wisp.html_response(string_builder.from_string(display_error(err)), 200)
  }
}

fn run_script(s: String) -> Result(String, RocTurtleEditorError) {
  let helper = fn(script: String) {
    // Create a temporary directory for the project
    use app_folder <- temporary.create(temporary.directory())
    // Create a file containing the user's script
    let user_lib_script_file_content = script
    // string.append("module [main]\n\n", script)
    let assert Ok(Nil) =
      simplifile.write(
        filepath.join(app_folder, "UserScript.roc"),
        user_lib_script_file_content,
      )

    // Create the app file
    let app_main_file_contents =
      "app [main] {cli: platform \"https://github.com/roc-lang/basic-cli/releases/download/0.15.0/SlwdbJ-3GR7uBWQo6zlmYWNYOxnvo8r6YABXD-45UOw.tar.br\", turtle: \"https://github.com/Hasnep/roc-turtle/releases/download/v0.1.0/FxIGHKCq1bbbJI9WicK2m7ibr3eH66QNdB0WZtjE17E.tar.br\" }\n\nimport cli.Stdout\nimport turtle.Turtle\nimport UserScript\n\nmain = Stdout.line (UserScript.main {} |> Turtle.toSvg { x: { from: -250, to: 250 }, y: { from: -250, to: 250 } })"
    let assert Ok(Nil) =
      simplifile.write(
        filepath.join(app_folder, "main.roc"),
        app_main_file_contents,
      )

    // Run the app
    run_roc_project(app_folder)
  }

  case helper(s) {
    Ok(Ok(output)) -> Ok(output)
    Ok(Error(error)) -> Error(error)
    Error(_) -> Error(TemporaryDirectoryCreationError)
  }
}

fn run_roc_project(project_path: String) -> Result(String, RocTurtleEditorError) {
  case build_roc_project(project_path) {
    Ok(built_binary_path) -> {
      wisp.log_info("Running Roc app at `" <> built_binary_path <> "`.")
      case run_command_with_timeout([built_binary_path], project_path, 5) {
        Ok(stdout) -> Ok(stdout)
        Error(#(_exit_code, stderr)) ->
          Error(RocProjectRunError(built_binary_path, stderr))
      }
    }
    Error(build_error_message) -> Error(build_error_message)
  }
}

fn build_roc_project(
  project_path: String,
) -> Result(String, RocTurtleEditorError) {
  let main_file_path = filepath.join(project_path, "main.roc")
  let output_file_path = filepath.join(project_path, "roc-turtle-app")
  wisp.log_info("Building Roc app at `" <> main_file_path <> "`.")
  let #(command, arguments) = #("roc", [
    "build",
    "--linker=legacy",
    "--optimize",
    "--output",
    output_file_path,
    main_file_path,
  ])
  let command_output =
    run_command_with_timeout([command, ..arguments], project_path, 10)
  case command_output {
    Ok(_stdout) -> {
      io.println(string.concat(["Built Roc app at ", output_file_path]))
      // Return the path to the built binary
      Ok(output_file_path)
    }
    Error(#(_exit_code, stderr)) ->
      Error(RocProjectBuildError(main_file_path, stderr))
  }
}

type RocTurtleEditorError {
  TemporaryDirectoryCreationError
  RocProjectBuildError(String, String)
  RocProjectRunError(String, String)
}

fn display_error(error: RocTurtleEditorError) -> String {
  case error {
    TemporaryDirectoryCreationError -> "Failed to create temporary directory."
    RocProjectBuildError(file_path, stderr) ->
      "Failed to build Roc app at " <> file_path <> " with message " <> stderr
    RocProjectRunError(built_binary_path, stderr) ->
      "Failed to run Roc app at "
      <> built_binary_path
      <> " with message "
      <> stderr
  }
}

fn run_command_with_timeout(
  command_and_arguments: List(String),
  working_directory: String,
  timeout: Int,
) {
  wisp.log_info(
    "Running command `"
    <> string.join(
      ["timeout", int.to_string(timeout), ..command_and_arguments],
      " ",
    )
    <> "`.",
  )
  shellout.command(
    "timeout",
    [int.to_string(timeout), ..command_and_arguments],
    in: working_directory,
    opt: [],
  )
}
