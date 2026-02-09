open Types

let info () = Detect.detect ()

let list_issues ?label ?milestone ?state () =
  let fi = info () in
  match fi.forge_type with
  | Gitea -> Gitea_api.list_issues fi ?label ?milestone ?state ()
  | Github -> Github_api.list_issues fi ?label ?milestone ?state ()

let get_issue number =
  let fi = info () in
  match fi.forge_type with
  | Gitea -> Gitea_api.get_issue fi number
  | Github -> Github_api.get_issue fi number

let create_issue ic =
  let fi = info () in
  match fi.forge_type with
  | Gitea -> Gitea_api.create_issue fi ic
  | Github -> Github_api.create_issue fi ic

let update_issue number iu =
  let fi = info () in
  match fi.forge_type with
  | Gitea -> Gitea_api.update_issue fi number iu
  | Github -> Github_api.update_issue fi number iu

let close_issue number =
  let fi = info () in
  match fi.forge_type with
  | Gitea -> Gitea_api.close_issue fi number
  | Github -> Github_api.close_issue fi number

let list_prs ?state () =
  let fi = info () in
  match fi.forge_type with
  | Gitea -> Gitea_api.list_prs fi ?state ()
  | Github -> Github_api.list_prs fi ?state ()

let get_pr number =
  let fi = info () in
  match fi.forge_type with
  | Gitea -> Gitea_api.get_pr fi number
  | Github -> Github_api.get_pr fi number

let get_pr_comments number =
  let fi = info () in
  match fi.forge_type with
  | Gitea -> Gitea_api.get_pr_comments fi number
  | Github -> Github_api.get_pr_comments fi number

let create_pr pc =
  let fi = info () in
  match fi.forge_type with
  | Gitea -> Gitea_api.create_pr fi pc
  | Github -> Github_api.create_pr fi pc

let list_milestones () =
  let fi = info () in
  match fi.forge_type with
  | Gitea -> Gitea_api.list_milestones fi
  | Github -> Github_api.list_milestones fi

let create_milestone title =
  let fi = info () in
  match fi.forge_type with
  | Gitea -> Gitea_api.create_milestone fi title
  | Github -> Github_api.create_milestone fi title

let list_labels () =
  let fi = info () in
  match fi.forge_type with
  | Gitea -> Gitea_api.list_labels fi
  | Github -> Github_api.list_labels fi

let find_label name =
  let fi = info () in
  match fi.forge_type with
  | Gitea -> Gitea_api.find_label fi name
  | Github -> Github_api.find_label fi name
