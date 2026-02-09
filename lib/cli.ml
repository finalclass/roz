open Cmdliner

(* roz info *)
let info_cmd =
  let doc = "Show repository forge information" in
  Cmd.v (Cmd.info "info" ~doc) Term.(const Cmd_info.run $ const ())

(* roz issue list *)
let issue_list_cmd =
  let label =
    let doc = "Filter by label" in
    Arg.(value & opt (some string) None & info [ "label"; "l" ] ~doc)
  in
  let milestone =
    let doc = "Filter by milestone" in
    Arg.(value & opt (some string) None & info [ "milestone"; "m" ] ~doc)
  in
  let state =
    let doc = "Filter by state (open, closed)" in
    Arg.(value & opt (some string) None & info [ "state"; "s" ] ~doc)
  in
  let run label milestone state = Cmd_issue.list ?label ?milestone ?state () in
  Cmd.v (Cmd.info "list" ~doc:"List issues")
    Term.(const run $ label $ milestone $ state)

(* roz issue show *)
let issue_show_cmd =
  let number =
    Arg.(required & pos 0 (some int) None & info [] ~docv:"NUMBER" ~doc:"Issue number")
  in
  Cmd.v (Cmd.info "show" ~doc:"Show issue details")
    Term.(const Cmd_issue.show $ number)

(* roz issue create *)
let issue_create_cmd =
  let title =
    Arg.(required & pos 0 (some string) None & info [] ~docv:"TITLE" ~doc:"Issue title")
  in
  let body =
    Arg.(value & opt (some string) None & info [ "body"; "b" ] ~doc:"Issue body")
  in
  let label =
    Arg.(value & opt (some string) None & info [ "label"; "l" ] ~doc:"Label name")
  in
  let milestone =
    Arg.(value & opt (some string) None & info [ "milestone"; "m" ] ~doc:"Milestone name")
  in
  let run title body label milestone =
    Cmd_issue.create title ?body ?label ?milestone ()
  in
  Cmd.v (Cmd.info "create" ~doc:"Create a new issue")
    Term.(const run $ title $ body $ label $ milestone)

(* roz issue update *)
let issue_update_cmd =
  let number =
    Arg.(required & pos 0 (some int) None & info [] ~docv:"NUMBER" ~doc:"Issue number")
  in
  let body =
    Arg.(value & opt (some string) None & info [ "body"; "b" ] ~doc:"New body text")
  in
  let body_file =
    Arg.(value & opt (some string) None & info [ "body-file" ] ~doc:"Read body from file")
  in
  let add_label =
    Arg.(value & opt (some string) None & info [ "add-label" ] ~doc:"Add label")
  in
  let remove_label =
    Arg.(value & opt (some string) None & info [ "remove-label" ] ~doc:"Remove label")
  in
  let milestone =
    Arg.(value & opt (some string) None & info [ "milestone"; "m" ] ~doc:"Set milestone")
  in
  let state =
    Arg.(value & opt (some string) None & info [ "state" ] ~doc:"Set state (open, closed)")
  in
  let run number body body_file add_label remove_label milestone state =
    Cmd_issue.update number ?body ?body_file ?add_label ?remove_label ?milestone ?state ()
  in
  Cmd.v (Cmd.info "update" ~doc:"Update an issue")
    Term.(const run $ number $ body $ body_file $ add_label $ remove_label $ milestone $ state)

(* roz issue close *)
let issue_close_cmd =
  let number =
    Arg.(required & pos 0 (some int) None & info [] ~docv:"NUMBER" ~doc:"Issue number")
  in
  Cmd.v (Cmd.info "close" ~doc:"Close an issue")
    Term.(const Cmd_issue.close $ number)

(* roz issue *)
let issue_cmd =
  let doc = "Manage issues" in
  Cmd.group (Cmd.info "issue" ~doc)
    [ issue_list_cmd; issue_show_cmd; issue_create_cmd;
      issue_update_cmd; issue_close_cmd ]

(* roz pr list *)
let pr_list_cmd =
  let state =
    Arg.(value & opt (some string) None & info [ "state"; "s" ] ~doc:"Filter by state")
  in
  let run state = Cmd_pr.list ?state () in
  Cmd.v (Cmd.info "list" ~doc:"List pull requests")
    Term.(const run $ state)

(* roz pr show *)
let pr_show_cmd =
  let number =
    Arg.(required & pos 0 (some int) None & info [] ~docv:"NUMBER" ~doc:"PR number")
  in
  Cmd.v (Cmd.info "show" ~doc:"Show PR details")
    Term.(const Cmd_pr.show $ number)

(* roz pr comments *)
let pr_comments_cmd =
  let number =
    Arg.(required & pos 0 (some int) None & info [] ~docv:"NUMBER" ~doc:"PR number")
  in
  Cmd.v (Cmd.info "comments" ~doc:"Show PR review comments")
    Term.(const Cmd_pr.comments $ number)

(* roz pr create *)
let pr_create_cmd =
  let issue =
    let doc = "Issue number to link" in
    Arg.(required & opt (some int) None & info [ "issue"; "i" ] ~doc)
  in
  let branch =
    Arg.(value & opt (some string) None & info [ "branch" ] ~doc:"Source branch")
  in
  let base =
    Arg.(value & opt (some string) None & info [ "base" ] ~doc:"Target branch")
  in
  let title =
    Arg.(value & opt (some string) None & info [ "title"; "t" ] ~doc:"PR title")
  in
  let draft =
    Arg.(value & flag & info [ "draft"; "d" ] ~doc:"Create as draft")
  in
  let run issue branch base title draft =
    Cmd_pr.create ~issue ?branch ?base ?title ~draft ()
  in
  Cmd.v (Cmd.info "create" ~doc:"Create a pull request")
    Term.(const run $ issue $ branch $ base $ title $ draft)

(* roz pr *)
let pr_cmd =
  let doc = "Manage pull requests" in
  Cmd.group (Cmd.info "pr" ~doc)
    [ pr_list_cmd; pr_show_cmd; pr_comments_cmd; pr_create_cmd ]

(* roz week plan *)
let week_plan_cmd =
  let week =
    Arg.(value & opt (some string) None & info [ "week"; "w" ] ~doc:"Week label (e.g. W07-2026)")
  in
  let run week = Cmd_week.plan ?week () in
  Cmd.v (Cmd.info "plan" ~doc:"Show current week's milestone")
    Term.(const run $ week)

(* roz week report *)
let week_report_cmd =
  let week =
    Arg.(value & opt (some string) None & info [ "week"; "w" ] ~doc:"Week label")
  in
  let run week = Cmd_week.report ?week () in
  Cmd.v (Cmd.info "report" ~doc:"Generate status report")
    Term.(const run $ week)

(* roz week (default — manage milestone) *)
let week_default_term =
  let week =
    Arg.(value & opt (some string) None & info [ "week"; "w" ] ~doc:"Week label (e.g. W07-2026)")
  in
  let empty =
    Arg.(value & flag & info [ "empty" ] ~doc:"Create empty milestone")
  in
  let issues =
    Arg.(value & opt (some string) None & info [ "issues" ] ~doc:"Comma-separated issue numbers")
  in
  let run week empty issues = Cmd_week.manage ?week ~empty ?issues () in
  Term.(const run $ week $ empty $ issues)

(* roz week *)
let week_cmd =
  let doc = "Manage weekly milestones" in
  Cmd.group ~default:week_default_term (Cmd.info "week" ~doc)
    [ week_plan_cmd; week_report_cmd ]

(* roz skill install *)
let skill_install_cmd =
  let global =
    Arg.(value & flag & info [ "global" ] ~doc:"Install to ~/.claude/skills/")
  in
  let run global = Cmd_skill.install ~global () in
  Cmd.v (Cmd.info "install" ~doc:"Install Claude Code skill")
    Term.(const run $ global)

(* roz skill *)
let skill_cmd =
  let doc = "Manage Claude Code skill" in
  Cmd.group (Cmd.info "skill" ~doc) [ skill_install_cmd ]

(* roz *)
let main_cmd =
  let doc = "Development workflow CLI for Gitea and GitHub" in
  let info = Cmd.info "roz" ~version:"0.1.0" ~doc in
  Cmd.group info
    [ info_cmd; issue_cmd; pr_cmd; week_cmd; skill_cmd ]

let run () = exit (Cmd.eval main_cmd)
