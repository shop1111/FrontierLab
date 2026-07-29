///|
fn main {
  let args = @sys.get_cli_args()
  let exit_code = try run_cli(args) catch {
    error => {
      let format = try option(args, "--format", "text") catch {
        _ => "text"
      } noraise {
        value => value
      }
      if format == "json" {
        println(json_error_envelope(command_name(args), "\{error}"))
      } else {
        println("error: \{error}")
      }
      1
    }
  } noraise {
    value => value
  }
  if exit_code != 0 {
    @sys.exit(exit_code)
  }
}
