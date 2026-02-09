let config_dir () =
  let home = Sys.getenv "HOME" in
  Filename.concat home ".config/roz"

let config_path () =
  Filename.concat (config_dir ()) "config.toml"

let load () =
  let path = config_path () in
  if Sys.file_exists path then
    Some (Otoml.Parser.from_file path)
  else
    None

let get_token config forge_type host =
  let forge_key =
    match forge_type with
    | Types.Gitea -> "gitea"
    | Types.Github -> "github"
  in
  match config with
  | Some toml ->
    (try Some (Otoml.find_result toml Otoml.get_string [ "forge"; forge_key; host; "token" ]
               |> Result.get_ok)
     with _ -> None)
  | None -> None

let get_poll_interval config =
  match config with
  | Some toml ->
    (try Otoml.find_result toml Otoml.get_integer [ "default"; "poll_interval" ]
         |> Result.get_ok
     with _ -> 30)
  | None -> 30
