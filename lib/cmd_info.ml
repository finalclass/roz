let run () =
  let fi = Detect.detect () in
  Printf.printf "Forge:     %s\n" (Types.forge_type_to_string fi.forge_type);
  Printf.printf "Host:      %s\n" fi.host;
  Printf.printf "Owner:     %s\n" fi.owner;
  Printf.printf "Repo:      %s\n" fi.repo;
  Printf.printf "Remote:    %s (%s)\n" fi.remote_name fi.remote_url;
  Printf.printf "Token:     %s\n"
    (match fi.token with Some _ -> "(configured)" | None -> "(not set)")
