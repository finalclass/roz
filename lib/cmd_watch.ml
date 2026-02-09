open Types

let state_dir () =
  let home = Sys.getenv "HOME" in
  let dir = Filename.concat home ".local/share/roz" in
  (try Unix.mkdir (Filename.concat home ".local/share") 0o755
   with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
  (try Unix.mkdir dir 0o755
   with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
  dir

let state_file () =
  Filename.concat (state_dir ()) "watch-state.json"

let load_state () =
  let path = state_file () in
  if Sys.file_exists path then
    try
      let json = Yojson.Safe.from_file path in
      let open Yojson.Safe.Util in
      json |> member "processed_comments" |> to_list
      |> List.map to_int
    with _ -> []
  else
    []

let save_state processed_ids =
  let json =
    `Assoc [
      ("processed_comments",
       `List (List.map (fun id -> `Int id) processed_ids))
    ]
  in
  Yojson.Safe.to_file (state_file ()) json

type active_pr = {
  pr_number : int;
  mutable pid : int option;
}

let active_prs : active_pr list ref = ref []

let is_pr_active pr_number =
  List.exists (fun a -> a.pr_number = pr_number && a.pid <> None) !active_prs

let mark_pr_active pr_number pid =
  active_prs := { pr_number; pid = Some pid } :: !active_prs

let mark_pr_done pr_number =
  active_prs := List.filter (fun a -> a.pr_number <> pr_number) !active_prs

let check_finished_processes () =
  active_prs := List.filter (fun a ->
    match a.pid with
    | None -> false
    | Some pid ->
      let result =
        try
          let (_, status) = Unix.waitpid [ Unix.WNOHANG ] pid in
          (match status with
           | Unix.WEXITED _ -> false
           | Unix.WSIGNALED _ -> false
           | Unix.WSTOPPED _ -> true)
        with Unix.Unix_error _ -> false
      in
      if not result then
        Printf.printf "[watch] Claude Code finished for PR #%d\n%!" a.pr_number;
      result
  ) !active_prs

let spawn_claude_for_pr fi (p : pr) (new_comments : comment list) =
  if is_pr_active p.number then begin
    Printf.printf "[watch] Skipping PR #%d - Claude Code already running\n%!" p.number;
    []
  end else begin
    let comments_text =
      List.map (fun (c : comment) ->
          let loc = match c.path with
            | Some path -> Printf.sprintf " on %s" path
            | None -> ""
          in
          Printf.sprintf "- %s%s: %s" c.author loc c.body
      ) new_comments
      |> String.concat "\n"
    in
    let prompt =
      Printf.sprintf
        "You are working on PR #%d \"%s\" in repo %s/%s.\n\
         Branch: %s\n\n\
         New review comments to address:\n\
         %s\n\n\
         Please:\n\
         1. Read each review comment carefully\n\
         2. Make the requested changes\n\
         3. Commit and push the fixes\n\
         Use `roz pr comments %d` to see full review context if needed."
        p.number p.title fi.owner fi.repo
        p.head_branch
        comments_text
        p.number
    in
    Printf.printf "[watch] Spawning Claude Code for PR #%d (%d new comments)\n%!"
      p.number (List.length new_comments);
    let argv = [| "claude"; "-p"; prompt; "--allowedTools"
                ; "Edit"; "Write"; "Bash"; "Read"; "Glob"; "Grep" |] in
    let pid =
      Unix.create_process "claude" argv Unix.stdin Unix.stdout Unix.stderr
    in
    mark_pr_active p.number pid;
    List.map (fun (c : comment) -> c.id) new_comments
  end

let poll_once fi ~dry_run =
  let processed = load_state () in
  let prs =
    match fi.forge_type with
    | Gitea -> Gitea_api.list_prs fi ~state:"open" ()
    | Github -> Github_api.list_prs fi ~state:"open" ()
  in
  Printf.printf "[watch] Checking %d open PRs...\n%!" (List.length prs);
  let newly_processed = ref [] in
  List.iter (fun (p : pr) ->
    let comments =
      match fi.forge_type with
      | Gitea -> Gitea_api.get_pr_comments fi p.number
      | Github -> Github_api.get_pr_comments fi p.number
    in
    let new_comments =
      List.filter (fun (c : comment) ->
        not (List.mem c.id processed || List.mem c.id !newly_processed)
      ) comments
    in
    if new_comments <> [] then begin
      if dry_run then begin
        Printf.printf "[watch] [dry-run] Would spawn Claude Code for PR #%d (%d new comments):\n"
          p.number (List.length new_comments);
        List.iter (fun (c : comment) ->
          let loc = match c.path with Some p -> " on " ^ p | None -> "" in
          Printf.printf "  - %s%s: %s\n" c.author loc
            (if String.length c.body > 80 then String.sub c.body 0 80 ^ "..."
             else c.body)
        ) new_comments
      end else begin
        let ids = spawn_claude_for_pr fi p new_comments in
        newly_processed := ids @ !newly_processed
      end
    end
  ) prs;
  if !newly_processed <> [] then
    save_state (processed @ !newly_processed)

let running = ref true

let run ?interval ?once ?dry_run () =
  let fi = Detect.detect () in
  (match fi.token with
   | None -> Error.fail "no API token configured - set token in ~/.config/roz/config.toml"
   | Some _ -> ());
  let interval = Option.value ~default:(Config.get_poll_interval (Config.load ())) interval in
  let once = Option.value ~default:false once in
  let dry_run = Option.value ~default:false dry_run in
  Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ ->
    Printf.printf "\n[watch] Shutting down...\n%!";
    running := false));
  Sys.set_signal Sys.sigterm (Sys.Signal_handle (fun _ ->
    Printf.printf "[watch] Shutting down...\n%!";
    running := false));
  Printf.printf "[watch] Watching %s/%s on %s (poll every %ds)\n%!"
    fi.owner fi.repo fi.host interval;
  if once then
    poll_once fi ~dry_run
  else begin
    while !running do
      (try
         check_finished_processes ();
         poll_once fi ~dry_run
       with exn ->
         Printf.eprintf "[watch] Error: %s\n%!" (Printexc.to_string exn));
      if !running then
        Unix.sleep interval
    done;
    Printf.printf "[watch] Stopped.\n%!"
  end
