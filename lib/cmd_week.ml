open Types

let current_week_label () =
  let t = Unix.gettimeofday () in
  let tm = Unix.gmtime t in
  (* ISO 8601 week number calculation *)
  let jan1 = { tm with Unix.tm_mday = 1; tm_mon = 0 } in
  let jan1_time, _ = Unix.mktime jan1 in
  let jan1_tm = Unix.gmtime jan1_time in
  let jan1_wday = if jan1_tm.tm_wday = 0 then 7 else jan1_tm.tm_wday in
  let day_of_year = tm.tm_yday + 1 in
  let week = (day_of_year + jan1_wday - 2) / 7 + 1 in
  let year = 1900 + tm.tm_year in
  Printf.sprintf "W%02d-%d" week year

let plan ?week () =
  let week_label = Option.value ~default:(current_week_label ()) week in
  Printf.printf "Week: %s\n\n" week_label;
  let issues = Forge.list_issues ~milestone:week_label () in
  if issues = [] then
    Printf.printf "No issues planned for %s\n" week_label
  else begin
    Printf.printf "Planned issues:\n\n";
    List.iter
      (fun (i : issue) ->
         let labels =
           String.concat ", " (List.map (fun l -> l.name) i.labels)
         in
         let status_icon =
           if List.exists (fun l -> l.name = "done") i.labels then "[x]"
           else if List.exists (fun l -> l.name = "in-progress") i.labels then "[~]"
           else "[ ]"
         in
         Printf.printf "  %s #%-4d  %s  (%s)\n"
           status_icon i.number i.title labels)
      issues
  end

let report ?week () =
  let week_label = Option.value ~default:(current_week_label ()) week in
  let issues = Forge.list_issues ~milestone:week_label () in
  let total = List.length issues in
  let done_count =
    List.length
      (List.filter
         (fun (i : issue) ->
            List.exists (fun l -> l.name = "done") i.labels
            || i.state = "closed")
         issues)
  in
  let in_progress =
    List.length
      (List.filter
         (fun (i : issue) ->
            List.exists (fun l -> l.name = "in-progress") i.labels)
         issues)
  in
  let review =
    List.length
      (List.filter
         (fun (i : issue) ->
            List.exists (fun l -> l.name = "review") i.labels)
         issues)
  in
  Printf.printf "# Status Report: %s\n\n" week_label;
  Printf.printf "Total: %d | Done: %d | In Progress: %d | In Review: %d | Remaining: %d\n\n"
    total done_count in_progress review (total - done_count - in_progress - review);
  if issues <> [] then begin
    Printf.printf "## Details\n\n";
    List.iter
      (fun (i : issue) ->
         let status =
           if i.state = "closed" then "DONE"
           else if List.exists (fun l -> l.name = "done") i.labels then "DONE"
           else if List.exists (fun l -> l.name = "review") i.labels then "REVIEW"
           else if List.exists (fun l -> l.name = "in-progress") i.labels then "IN PROGRESS"
           else if List.exists (fun l -> l.name = "planned") i.labels then "PLANNED"
           else "IDEA"
         in
         Printf.printf "- [%s] #%d %s\n" status i.number i.title)
      issues
  end

let create ?week ?(empty = false) ?issues:issue_numbers () =
  let week_label = Option.value ~default:(current_week_label ()) week in
  (* Check if milestone exists *)
  let milestones = Forge.list_milestones () in
  let ms =
    match List.find_opt (fun (m : Types.milestone) -> m.title = week_label) milestones with
    | Some m ->
      Printf.printf "Milestone %s already exists.\n" week_label;
      m
    | None ->
      let m = Forge.create_milestone week_label in
      Printf.printf "Created milestone %s\n" week_label;
      m
  in
  if empty then ()
  else
    match issue_numbers with
    | Some nums ->
      (* Assign specific issues *)
      let num_list = String.split_on_char ',' nums |> List.map String.trim
                     |> List.map int_of_string in
      List.iter
        (fun n ->
           let _ =
             Forge.update_issue n
               { iu_body = None; iu_labels = None;
                 iu_milestone = Some ms.id; iu_state = None }
           in
           Printf.printf "  Assigned #%d to %s\n" n week_label)
        num_list
    | None ->
      (* Interactive TUI multi-select *)
      let all_issues = Forge.list_issues ~state:"open" () in
      let unassigned =
        List.filter (fun (i : issue) -> i.milestone = None) all_issues
      in
      if unassigned = [] then
        Printf.printf "No unassigned open issues in backlog.\n"
      else begin
        (* Sort: planned first, then idea, then rest *)
        let priority (i : issue) =
          if List.exists (fun l -> l.name = "planned") i.labels then 0
          else if List.exists (fun l -> l.name = "idea") i.labels then 2
          else 1
        in
        let sorted =
          List.sort (fun a b -> compare (priority a) (priority b)) unassigned
        in
        let tui_items =
          List.map (fun (i : issue) ->
            let labels =
              String.concat "," (List.map (fun l -> l.name) i.labels)
            in
            { Tui_select.value = i.number;
              label = Printf.sprintf "#%-5d  %s" i.number i.title;
              description = labels })
            sorted
        in
        let title =
          Printf.sprintf "Creating milestone %s — select issues from backlog:" week_label
        in
        let selected_numbers = Tui_select.run_select ~title tui_items in
        if selected_numbers = [] then
          Printf.printf "No issues selected.\n"
        else begin
          Printf.printf "\nAssigning %d issues to %s:\n"
            (List.length selected_numbers) week_label;
          List.iter (fun n ->
            let _ =
              Forge.update_issue n
                { iu_body = None; iu_labels = None;
                  iu_milestone = Some ms.id; iu_state = None }
            in
            Printf.printf "  Assigned #%d to %s\n" n week_label
          ) selected_numbers
        end
      end
