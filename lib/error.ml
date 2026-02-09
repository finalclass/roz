exception Roz_error of string

let fail msg = raise (Roz_error msg)
let failf fmt = Printf.ksprintf fail fmt
