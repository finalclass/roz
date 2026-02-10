let strip_dot_git s =
  if String.ends_with ~suffix:".git" s then
    String.sub s 0 (String.length s - 4)
  else
    s

let parse_url url =
  let url = String.trim url in
  if String.starts_with ~prefix:"https://" url
     || String.starts_with ~prefix:"http://" url
  then
    let proto_len =
      if String.starts_with ~prefix:"https://" url then 8 else 7
    in
    let without_proto =
      String.sub url proto_len (String.length url - proto_len)
    in
    let parts = String.split_on_char '/' without_proto in
    match parts with
    | host :: owner :: rest when rest <> [] ->
      let repo = strip_dot_git (String.concat "/" rest) in
      Some (host, owner, repo)
    | _ -> None
  else if String.starts_with ~prefix:"git@" url then
    let without_prefix =
      String.sub url 4 (String.length url - 4)
    in
    (match String.split_on_char ':' without_prefix with
     | [ host; path ] ->
       (match String.split_on_char '/' path with
        | [ owner; repo ] ->
          Some (host, owner, strip_dot_git repo)
        | _ -> None)
     | _ -> None)
  else
    None

let has_config_section toml path =
  match Otoml.find_result toml Otoml.get_table path with
  | Ok _ -> true
  | Error _ -> false

let detect_forge_type config host =
  match config with
  | Some toml ->
    let is_gitea = has_config_section toml [ "forge"; "gitea"; host ] in
    let is_github = has_config_section toml [ "forge"; "github"; host ] in
    if is_gitea then Types.Gitea
    else if is_github then Types.Github
    else if host = "github.com" then Types.Github
    else Types.Gitea
  | None ->
    if host = "github.com" then Types.Github else Types.Gitea

let get_remote_url ?(remote = "origin") () =
  let argv = [| "git"; "remote"; "get-url"; remote |] in
  let ic = Unix.open_process_args_in "git" argv in
  let url =
    try Some (input_line ic) with End_of_file -> None
  in
  let _ = Unix.close_process_in ic in
  url

let ref_exists ref_name =
  let argv = [| "git"; "rev-parse"; "--verify"; "--quiet"; ref_name |] in
  let ic = Unix.open_process_args_in "git" argv in
  let _ = try ignore (input_line ic) with End_of_file -> () in
  match Unix.close_process_in ic with
  | Unix.WEXITED 0 -> true
  | _ -> false

let default_branch ?(remote = "origin") () =
  (* Try symbolic-ref first *)
  let argv = [| "git"; "symbolic-ref"; Printf.sprintf "refs/remotes/%s/HEAD" remote |] in
  let ic = Unix.open_process_args_in "git" argv in
  let line = try Some (String.trim (input_line ic)) with End_of_file -> None in
  let _ = Unix.close_process_in ic in
  match line with
  | Some ref_str ->
    let prefix = Printf.sprintf "refs/remotes/%s/" remote in
    if String.starts_with ~prefix ref_str then
      String.sub ref_str (String.length prefix) (String.length ref_str - String.length prefix)
    else if ref_exists (remote ^ "/main") then "main"
    else "master"
  | None ->
    if ref_exists (remote ^ "/main") then "main"
    else "master"

let detect () =
  let config = Config.load () in
  match get_remote_url () with
  | None ->
    Error.failf "could not read git remote 'origin'"
  | Some url ->
    (match parse_url url with
     | None ->
       Error.failf "could not parse remote URL: %s" url
     | Some (host, owner, repo) ->
       let forge_type = detect_forge_type config host in
       let token = Config.get_token config forge_type host in
       { Types.forge_type; host; owner; repo;
         remote_name = "origin"; remote_url = url; token })
