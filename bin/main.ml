let () =
  try Roz.Cli.run ()
  with Roz.Error.Roz_error msg ->
    Printf.eprintf "error: %s\n" msg;
    exit 1
