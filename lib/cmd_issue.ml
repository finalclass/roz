open Types

let pad_right s n =
  let len = String.length s in
  if len >= n then s else s ^ String.make (n - len) ' '

let list ?label ?milestone ?state () =
  let issues = Forge.list_issues ?label ?milestone ?state () in
  if issues = [] then
    print_endline "No issues found."
  else
    List.iter
      (fun (i : issue) ->
         let labels =
           String.concat "," (List.map (fun l -> l.name) i.labels)
         in
         let ms =
           match i.milestone with
           | Some m -> m.title
           | None -> ""
         in
         Printf.printf "#%-5d  %-40s  %-12s  %s\n"
           i.number
           (pad_right i.title 40)
           labels
           ms)
      issues

let show number =
  let i = Forge.get_issue number in
  Printf.printf "Issue #%d: %s\n" i.number i.title;
  Printf.printf "State:     %s\n" i.state;
  Printf.printf "Labels:    %s\n"
    (match i.labels with
     | [] -> "(none)"
     | ls -> String.concat ", " (List.map (fun l -> l.name) ls));
  Printf.printf "Milestone: %s\n"
    (match i.milestone with Some m -> m.title | None -> "(none)");
  Printf.printf "Assignees: %s\n"
    (match i.assignees with [] -> "(none)" | a -> String.concat ", " a);
  if i.body <> "" then begin
    print_newline ();
    print_endline i.body
  end

let create title ?body ?label ?milestone () =
  let ic_labels =
    match label with
    | Some name ->
      (match Forge.find_label name with
       | Some l -> [ l.id ]
       | None -> Error.failf "label not found: %s" name)
    | None -> []
  in
  let ic_milestone =
    match milestone with
    | Some name ->
      let milestones = Forge.list_milestones () in
      (match List.find_opt (fun (m : Types.milestone) -> m.title = name) milestones with
       | Some m -> Some m.id
       | None -> Error.failf "milestone not found: %s" name)
    | None -> None
  in
  let issue =
    Forge.create_issue
      { ic_title = title;
        ic_body = Option.value ~default:"" body;
        ic_labels;
        ic_milestone }
  in
  Printf.printf "Created issue #%d: %s\n" issue.number issue.title

let update number ?body ?body_file ?add_label ?remove_label ?milestone ?state () =
  let body =
    match body_file with
    | Some path -> Some (In_channel.with_open_text path In_channel.input_all)
    | None -> body
  in
  let iu_labels =
    let fi = Detect.detect () in
    let current = Forge.get_issue number in
    let current_ids = List.map (fun (l : Types.label) -> l.id) current.labels in
    let add_ids =
      match add_label with
      | Some name ->
        (match fi.forge_type with
         | Gitea ->
           (match Gitea_api.find_label fi name with
            | Some l -> [ l.id ]
            | None -> Error.failf "label not found: %s" name)
         | Github ->
           (match Github_api.find_label fi name with
            | Some l -> [ l.id ]
            | None -> Error.failf "label not found: %s" name))
      | None -> []
    in
    let remove_ids =
      match remove_label with
      | Some name ->
        current.labels
        |> List.filter (fun (l : Types.label) -> l.name = name)
        |> List.map (fun (l : Types.label) -> l.id)
      | None -> []
    in
    let new_ids =
      (current_ids @ add_ids)
      |> List.filter (fun id -> not (List.mem id remove_ids))
      |> List.sort_uniq compare
    in
    if add_label <> None || remove_label <> None then Some new_ids
    else None
  in
  let iu_milestone =
    match milestone with
    | Some name ->
      let milestones = Forge.list_milestones () in
      (match List.find_opt (fun (m : Types.milestone) -> m.title = name) milestones with
       | Some m -> Some m.id
       | None -> Error.failf "milestone not found: %s" name)
    | None -> None
  in
  let issue =
    Forge.update_issue number
      { iu_body = body; iu_labels; iu_milestone; iu_state = state }
  in
  Printf.printf "Updated issue #%d: %s\n" issue.number issue.title

let close number =
  Forge.close_issue number;
  Printf.printf "Closed issue #%d\n" number
