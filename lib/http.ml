type meth = GET | POST | PUT | PATCH | DELETE

type response = {
  status : int;
  body : string;
}

let meth_to_string = function
  | GET -> "GET"
  | POST -> "POST"
  | PATCH -> "PATCH"
  | PUT -> "PUT"
  | DELETE -> "DELETE"

let request ?(headers = []) ?body meth url =
  let args =
    [ "curl"; "-s"; "-w"; "\n%{http_code}"; "-X"; meth_to_string meth ]
  in
  let args =
    List.fold_left
      (fun acc (k, v) -> acc @ [ "-H"; Printf.sprintf "%s: %s" k v ])
      args headers
  in
  let args =
    match body with
    | Some b -> args @ [ "-d"; b ]
    | None -> args
  in
  let args = args @ [ url ] in
  let argv = Array.of_list args in
  let ic = Unix.open_process_args_in "curl" argv in
  let output = In_channel.input_all ic in
  let status = Unix.close_process_in ic in
  (match status with
   | Unix.WEXITED 0 -> ()
   | _ -> Error.failf "curl failed for %s" url);
  let last_nl =
    try String.rindex output '\n' with Not_found -> -1
  in
  if last_nl < 0 then
    { status = (try int_of_string (String.trim output) with _ -> 0);
      body = "" }
  else
    let resp_body = String.sub output 0 last_nl in
    let status_str =
      String.sub output (last_nl + 1) (String.length output - last_nl - 1)
    in
    { status = (try int_of_string (String.trim status_str) with _ -> 0);
      body = resp_body }

let get ?(headers = []) url = request ~headers GET url
let post ?(headers = []) ~body url = request ~headers ~body POST url
let patch ?(headers = []) ~body url = request ~headers ~body PATCH url
let put ?(headers = []) ~body url = request ~headers ~body PUT url
let delete ?(headers = []) url = request ~headers DELETE url
