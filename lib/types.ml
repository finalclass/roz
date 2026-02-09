type forge_type = Gitea | Github

type forge_info = {
  forge_type : forge_type;
  host : string;
  owner : string;
  repo : string;
  remote_name : string;
  remote_url : string;
  token : string option;
}

type label = {
  id : int;
  name : string;
  color : string;
}

type milestone = {
  id : int;
  title : string;
}

type issue = {
  number : int;
  title : string;
  body : string;
  state : string;
  labels : label list;
  milestone : milestone option;
  assignees : string list;
}

type comment = {
  id : int;
  body : string;
  author : string;
  created_at : string;
  path : string option;
  diff_hunk : string option;
}

type pr = {
  number : int;
  title : string;
  body : string;
  state : string;
  head_branch : string;
  base_branch : string;
  labels : label list;
  milestone : milestone option;
}

type issue_create = {
  ic_title : string;
  ic_body : string;
  ic_labels : int list;
  ic_milestone : int option;
}

type issue_update = {
  iu_body : string option;
  iu_labels : int list option;
  iu_milestone : int option;
  iu_state : string option;
}

type pr_create = {
  pc_title : string;
  pc_body : string;
  pc_head : string;
  pc_base : string;
}

let forge_type_to_string = function
  | Gitea -> "Gitea"
  | Github -> "GitHub"
