open Types

let base_url info =
  Printf.sprintf "https://%s/api/v1" info.host

let auth_headers info =
  match info.token with
  | Some t -> [ ("Authorization", "token " ^ t);
                ("Content-Type", "application/json") ]
  | None -> [ ("Content-Type", "application/json") ]

let parse_label json =
  let open Yojson.Safe.Util in
  { id = json |> member "id" |> to_int;
    name = json |> member "name" |> to_string;
    color = json |> member "color" |> to_string_option |> Option.value ~default:"" }

let parse_milestone json =
  let open Yojson.Safe.Util in
  { id = json |> member "id" |> to_int;
    title = json |> member "title" |> to_string }

let parse_issue json =
  let open Yojson.Safe.Util in
  { number = json |> member "number" |> to_int;
    title = json |> member "title" |> to_string;
    body = json |> member "body" |> to_string_option |> Option.value ~default:"";
    state = json |> member "state" |> to_string;
    labels = json |> member "labels" |> to_list |> List.map parse_label;
    milestone =
      (let m = json |> member "milestone" in
       if m = `Null then None else Some (parse_milestone m));
    assignees =
      json |> member "assignees" |> to_list
      |> List.map (fun u -> u |> member "login" |> to_string) }

let parse_comment json =
  let open Yojson.Safe.Util in
  { id = json |> member "id" |> to_int;
    body = json |> member "body" |> to_string;
    author =
      json |> member "user" |> member "login" |> to_string;
    created_at = json |> member "created_at" |> to_string;
    path = json |> member "path" |> to_string_option;
    diff_hunk = json |> member "diff_hunk" |> to_string_option }

let parse_pr json =
  let open Yojson.Safe.Util in
  { number = json |> member "number" |> to_int;
    title = json |> member "title" |> to_string;
    body = json |> member "body" |> to_string_option |> Option.value ~default:"";
    state = json |> member "state" |> to_string;
    head_branch =
      json |> member "head" |> member "label" |> to_string;
    base_branch =
      json |> member "base" |> member "label" |> to_string;
    labels = json |> member "labels" |> to_list |> List.map parse_label;
    milestone =
      (let m = json |> member "milestone" in
       if m = `Null then None else Some (parse_milestone m)) }

let api_get info path =
  let url = base_url info ^ path in
  let resp = Http.get ~headers:(auth_headers info) url in
  if resp.status >= 400 then
    Error.failf "Gitea API error %d: %s" resp.status resp.body;
  resp.body

let api_post info path body =
  let url = base_url info ^ path in
  let resp = Http.post ~headers:(auth_headers info) ~body url in
  if resp.status >= 400 then
    Error.failf "Gitea API error %d: %s" resp.status resp.body;
  resp.body

let api_patch info path body =
  let url = base_url info ^ path in
  let resp = Http.patch ~headers:(auth_headers info) ~body url in
  if resp.status >= 400 then
    Error.failf "Gitea API error %d: %s" resp.status resp.body;
  resp.body

let api_delete info path =
  let url = base_url info ^ path in
  let resp = Http.delete ~headers:(auth_headers info) url in
  if resp.status >= 400 then
    Error.failf "Gitea API error %d: %s" resp.status resp.body;
  resp.body

let repo_path info =
  Printf.sprintf "/repos/%s/%s" info.owner info.repo

(* Issues *)

let list_issues info ?label ?milestone ?state () =
  let params = ref [] in
  Option.iter (fun l -> params := ("labels", l) :: !params) label;
  Option.iter (fun m -> params := ("milestones", m) :: !params) milestone;
  Option.iter (fun s -> params := ("state", s) :: !params) state;
  let query =
    match !params with
    | [] -> ""
    | ps ->
      "?" ^ String.concat "&"
        (List.map (fun (k, v) -> k ^ "=" ^ v) ps)
  in
  let body = api_get info (repo_path info ^ "/issues" ^ query) in
  Yojson.Safe.from_string body |> Yojson.Safe.Util.to_list
  |> List.map parse_issue

let get_issue info number =
  let body =
    api_get info
      (Printf.sprintf "%s/issues/%d" (repo_path info) number)
  in
  Yojson.Safe.from_string body |> parse_issue

let create_issue info (ic : issue_create) =
  let json =
    `Assoc
      ([ ("title", `String ic.ic_title);
         ("body", `String ic.ic_body) ]
       @ (if ic.ic_labels <> [] then
            [ ("labels", `List (List.map (fun id -> `Int id) ic.ic_labels)) ]
          else [])
       @ (match ic.ic_milestone with
          | Some m -> [ ("milestone", `Int m) ]
          | None -> []))
  in
  let body =
    api_post info (repo_path info ^ "/issues")
      (Yojson.Safe.to_string json)
  in
  Yojson.Safe.from_string body |> parse_issue

let update_issue info number (iu : issue_update) =
  let fields = ref [] in
  Option.iter (fun b -> fields := ("body", `String b) :: !fields) iu.iu_body;
  Option.iter (fun s -> fields := ("state", `String s) :: !fields) iu.iu_state;
  Option.iter (fun m -> fields := ("milestone", `Int m) :: !fields) iu.iu_milestone;
  let json = `Assoc !fields in
  let body =
    api_patch info
      (Printf.sprintf "%s/issues/%d" (repo_path info) number)
      (Yojson.Safe.to_string json)
  in
  Yojson.Safe.from_string body |> parse_issue

let set_issue_labels info number label_ids =
  let json =
    `Assoc [ ("labels", `List (List.map (fun id -> `Int id) label_ids)) ]
  in
  let _ =
    Http.request ~headers:(auth_headers info)
      ~body:(Yojson.Safe.to_string json)
      Http.PUT
      (base_url info
       ^ Printf.sprintf "%s/issues/%d/labels" (repo_path info) number)
  in
  ()

let close_issue info number =
  ignore (update_issue info number { iu_body = None; iu_labels = None;
                                     iu_milestone = None;
                                     iu_state = Some "closed" })

(* PRs *)

let list_prs info ?state () =
  let query =
    match state with
    | Some s -> "?state=" ^ s
    | None -> ""
  in
  let body = api_get info (repo_path info ^ "/pulls" ^ query) in
  Yojson.Safe.from_string body |> Yojson.Safe.Util.to_list
  |> List.map parse_pr

let get_pr info number =
  let body =
    api_get info
      (Printf.sprintf "%s/pulls/%d" (repo_path info) number)
  in
  Yojson.Safe.from_string body |> parse_pr

let get_pr_comments info number =
  let body =
    api_get info
      (Printf.sprintf "%s/pulls/%d/reviews" (repo_path info) number)
  in
  let reviews =
    Yojson.Safe.from_string body |> Yojson.Safe.Util.to_list
  in
  List.concat_map
    (fun review ->
       let open Yojson.Safe.Util in
       let review_id = review |> member "id" |> to_int in
       let comments_body =
         api_get info
           (Printf.sprintf "%s/pulls/%d/reviews/%d/comments"
              (repo_path info) number review_id)
       in
       Yojson.Safe.from_string comments_body
       |> Yojson.Safe.Util.to_list
       |> List.map parse_comment)
    reviews

let create_pr info (pc : pr_create) =
  let json =
    `Assoc
      [ ("title", `String pc.pc_title);
        ("body", `String pc.pc_body);
        ("head", `String pc.pc_head);
        ("base", `String pc.pc_base) ]
  in
  let body =
    api_post info (repo_path info ^ "/pulls")
      (Yojson.Safe.to_string json)
  in
  Yojson.Safe.from_string body |> parse_pr

(* Milestones *)

let list_milestones info =
  let body = api_get info (repo_path info ^ "/milestones") in
  Yojson.Safe.from_string body |> Yojson.Safe.Util.to_list
  |> List.map parse_milestone

let create_milestone info title =
  let json = `Assoc [ ("title", `String title) ] in
  let body =
    api_post info (repo_path info ^ "/milestones")
      (Yojson.Safe.to_string json)
  in
  Yojson.Safe.from_string body |> parse_milestone

(* Labels *)

let list_labels info =
  let body = api_get info (repo_path info ^ "/labels") in
  Yojson.Safe.from_string body |> Yojson.Safe.Util.to_list
  |> List.map parse_label

let find_label info name =
  let labels = list_labels info in
  List.find_opt (fun l -> l.name = name) labels
