open Types

let list ?state () =
  let prs = Forge.list_prs ?state () in
  if prs = [] then
    print_endline "No pull requests found."
  else
    List.iter
      (fun (p : pr) ->
         let labels =
           String.concat "," (List.map (fun l -> l.name) p.labels)
         in
         Printf.printf "#%-5d  %-40s  %-10s  %s → %s\n"
           p.number
           p.title
           labels
           p.head_branch
           p.base_branch)
      prs

let show number =
  let p = Forge.get_pr number in
  Printf.printf "PR #%d: %s\n" p.number p.title;
  Printf.printf "State:     %s\n" p.state;
  Printf.printf "Branch:    %s → %s\n" p.head_branch p.base_branch;
  Printf.printf "Labels:    %s\n"
    (match p.labels with
     | [] -> "(none)"
     | ls -> String.concat ", " (List.map (fun l -> l.name) ls));
  Printf.printf "Milestone: %s\n"
    (match p.milestone with Some m -> m.title | None -> "(none)");
  if p.body <> "" then begin
    print_newline ();
    print_endline p.body
  end

let comments number =
  let cs = Forge.get_pr_comments number in
  if cs = [] then
    Printf.printf "No review comments on PR #%d\n" number
  else begin
    Printf.printf "Review comments on PR #%d:\n\n" number;
    List.iter
      (fun (c : comment) ->
         let location =
           match c.path with
           | Some p -> " on " ^ p
           | None -> ""
         in
         Printf.printf "--- %s at %s%s ---\n" c.author c.created_at location;
         (match c.diff_hunk with
          | Some h -> Printf.printf "%s\n" h
          | None -> ());
         Printf.printf "%s\n\n" c.body)
      cs
  end

let create ~issue ?branch ?base ?title ?draft:_ () =
  let fi = Detect.detect () in
  let iss = Forge.get_issue issue in
  let head =
    match branch with
    | Some b -> b
    | None ->
      (* Get current branch *)
      let ic = Unix.open_process_args_in "git" [| "git"; "rev-parse"; "--abbrev-ref"; "HEAD" |] in
      let b = input_line ic in
      ignore (Unix.close_process_in ic);
      b
  in
  let base_branch =
    match base with
    | Some b -> b
    | None -> Detect.default_branch ()
  in
  let pr_title =
    match title with
    | Some t -> t
    | None -> Printf.sprintf "#%d %s" iss.number iss.title
  in
  let pr_body = Printf.sprintf "Closes #%d\n\n%s" iss.number iss.body in
  let p =
    match fi.forge_type with
    | Gitea ->
      Gitea_api.create_pr fi
        { pc_title = pr_title; pc_body = pr_body;
          pc_head = head; pc_base = base_branch }
    | Github ->
      Github_api.create_pr fi
        { pc_title = pr_title; pc_body = pr_body;
          pc_head = head; pc_base = base_branch }
  in
  Printf.printf "Created PR #%d: %s\n" p.number p.title;
  Printf.printf "Branch: %s → %s\n" p.head_branch p.base_branch
