open Mosaic

type 'a item = {
  value : 'a;
  label : string;
  description : string;
}

type mode =
  | Select
  | Detail of int

type 'a model = {
  items : 'a item array;
  cursor : int;
  selected : bool array;
  scroll_offset : int;
  visible_height : int;
  confirmed : bool;
  title : string;
  mode : mode;
  on_button : bool;
  detail_fn : ('a -> string) option;
  confirm_label : string;
  detail_scroll : int;
  detail_lines : string list;
}

type msg =
  | Move_up
  | Move_down
  | Toggle
  | Toggle_all
  | Open_detail
  | Back
  | Confirm
  | Cancel

let init ~title ~visible_height ~confirm_label ?detail_fn items =
  let items = Array.of_list items in
  let selected = Array.make (Array.length items) false in
  ({ items; cursor = 0; selected; scroll_offset = 0;
     visible_height; confirmed = false; title;
     mode = Select; on_button = false;
     detail_fn; confirm_label;
     detail_scroll = 0; detail_lines = [] }, Cmd.none)

let selected_count model =
  Array.fold_left (fun acc s -> if s then acc + 1 else acc) 0 model.selected

let clamp_scroll model =
  let n = Array.length model.items in
  let max_off = max 0 (n - model.visible_height) in
  let off =
    if model.cursor < model.scroll_offset then model.cursor
    else if model.cursor >= model.scroll_offset + model.visible_height then
      model.cursor - model.visible_height + 1
    else model.scroll_offset
  in
  { model with scroll_offset = min off max_off }

let update msg model =
  match model.mode with
  | Detail _ ->
    (match msg with
     | Back -> ({ model with mode = Select; detail_scroll = 0; detail_lines = [] }, Cmd.none)
     | Move_up ->
       let s = max 0 (model.detail_scroll - 1) in
       ({ model with detail_scroll = s }, Cmd.none)
     | Move_down ->
       let max_scroll = max 0 (List.length model.detail_lines - model.visible_height) in
       let s = min max_scroll (model.detail_scroll + 1) in
       ({ model with detail_scroll = s }, Cmd.none)
     | Cancel -> ({ model with confirmed = false }, Cmd.quit)
     | _ -> (model, Cmd.none))
  | Select ->
    (match msg with
     | Move_up ->
       if model.on_button then
         ({ model with on_button = false }, Cmd.none)
       else
         let cursor = max 0 (model.cursor - 1) in
         (clamp_scroll { model with cursor }, Cmd.none)
     | Move_down ->
       if model.on_button then
         (model, Cmd.none)
       else if model.cursor >= Array.length model.items - 1 then
         ({ model with on_button = true }, Cmd.none)
       else
         let cursor = model.cursor + 1 in
         (clamp_scroll { model with cursor }, Cmd.none)
     | Toggle when not model.on_button ->
       model.selected.(model.cursor) <- not model.selected.(model.cursor);
       (model, Cmd.none)
     | Toggle_all ->
       let all_selected = Array.for_all Fun.id model.selected in
       Array.fill model.selected 0 (Array.length model.selected) (not all_selected);
       (model, Cmd.none)
     | Open_detail when not model.on_button && model.detail_fn <> None ->
       let lines =
         match model.detail_fn with
         | Some fn ->
           let detail_text = fn model.items.(model.cursor).value in
           String.split_on_char '\n' detail_text
         | None -> []
       in
       ({ model with mode = Detail model.cursor; detail_scroll = 0; detail_lines = lines }, Cmd.none)
     | Confirm when model.on_button ->
       ({ model with confirmed = true }, Cmd.quit)
     | Open_detail when model.on_button ->
       ({ model with confirmed = true }, Cmd.quit)
     | Cancel ->
       ({ model with confirmed = false }, Cmd.quit)
     | _ -> (model, Cmd.none))

let hint_style = Ansi.Style.make ~fg:(Ansi.Color.grayscale ~level:14) ()
let title_style = Ansi.Style.make ~bold:true ()
let accent = Ansi.Color.cyan
let green = Ansi.Color.green
let dim_style = Ansi.Style.make ~fg:(Ansi.Color.grayscale ~level:10) ()

let view_select model =
  let n = Array.length model.items in
  let end_i = min n (model.scroll_offset + model.visible_height) in
  let rows =
    List.init (end_i - model.scroll_offset) (fun rel ->
        let i = model.scroll_offset + rel in
        let is_cur = i = model.cursor && not model.on_button in
        let is_sel = model.selected.(i) in
        let check = if is_sel then "[x] " else "[ ] " in
        let arrow = if is_cur then "> " else "  " in
        let item = model.items.(i) in
        let label = Printf.sprintf "%s%s%-40s  %s" arrow check item.label item.description in
        let style =
          if is_cur then
            Ansi.Style.make ~fg:Ansi.Color.black ~bg:accent ~bold:is_sel ()
          else if is_sel then
            Ansi.Style.make ~fg:green ~bold:true ()
          else
            Ansi.Style.make ~fg:Ansi.Color.white ()
        in
        text ~key:(string_of_int i) ~style label)
  in
  let sel_count = selected_count model in
  let button_label =
    Printf.sprintf "  %s [%s] (%d selected)"
      (if model.on_button then ">" else " ")
      model.confirm_label
      sel_count
  in
  let button_style =
    if model.on_button then
      Ansi.Style.make ~fg:Ansi.Color.black ~bg:green ~bold:true ()
    else if sel_count > 0 then
      Ansi.Style.make ~fg:green ~bold:true ()
    else
      dim_style
  in
  let hint_text =
    if model.on_button then
      "  ↑ back to list  enter confirm  q cancel"
    else
      "  ↑↓ navigate  ␣ toggle  a toggle all  enter preview  q cancel"
  in
  box ~flex_direction:Column
    ~size:{ width = pct 100; height = pct 100 }
    [ box ~padding:(padding 1)
        [ text ~style:title_style model.title ];
      box ~flex_direction:Column ~padding:(padding 1) rows;
      box ~padding:(padding 1)
        [ text ~style:button_style button_label ];
      box ~padding:(padding 1)
        [ text ~style:hint_style hint_text ]
    ]

let view_detail model idx =
  let item = model.items.(idx) in
  let lines = model.detail_lines in
  let total = List.length lines in
  let end_i = min total (model.detail_scroll + model.visible_height) in
  let visible_lines =
    lines
    |> List.filteri (fun i _ -> i >= model.detail_scroll && i < end_i)
  in
  let detail_rows =
    List.mapi (fun i line -> text ~key:(string_of_int (model.detail_scroll + i)) line) visible_lines
  in
  let scroll_hint =
    if total > model.visible_height then
      Printf.sprintf " (%d/%d)" (model.detail_scroll + 1) total
    else ""
  in
  ignore scroll_hint;
  let hint =
    if total > model.visible_height then
      Printf.sprintf "  ↑↓ scroll%s  backspace back to list  q cancel" scroll_hint
    else
      "  backspace back to list  q cancel"
  in
  box ~flex_direction:Column
    ~size:{ width = pct 100; height = pct 100 }
    [ box ~padding:(padding 1)
        [ text ~style:title_style item.label ];
      box ~flex_direction:Column ~padding:(padding 1) ~flex_grow:1. detail_rows;
      box ~padding:(padding 1)
        [ text ~style:hint_style hint ]
    ]

let view model =
  match model.mode with
  | Select -> view_select model
  | Detail idx -> view_detail model idx

let subscriptions model =
  match model.mode with
  | Detail _ ->
    Sub.on_key (fun ev ->
        match (Mosaic_ui.Event.Key.data ev).key with
        | Up -> Some Move_up
        | Down -> Some Move_down
        | Char c when Uchar.equal c (Uchar.of_char 'k') -> Some Move_up
        | Char c when Uchar.equal c (Uchar.of_char 'j') -> Some Move_down
        | Backspace -> Some Back
        | Escape -> Some Back
        | Char c when Uchar.equal c (Uchar.of_char 'q') -> Some Cancel
        | _ -> None)
  | Select ->
    Sub.on_key (fun ev ->
        match (Mosaic_ui.Event.Key.data ev).key with
        | Up -> Some Move_up
        | Down -> Some Move_down
        | Char c when Uchar.equal c (Uchar.of_char 'k') -> Some Move_up
        | Char c when Uchar.equal c (Uchar.of_char 'j') -> Some Move_down
        | Char c when Uchar.equal c (Uchar.of_char ' ') -> Some Toggle
        | Char c when Uchar.equal c (Uchar.of_char 'a') -> Some Toggle_all
        | Enter -> Some Open_detail
        | Char c when Uchar.equal c (Uchar.of_char 'q') -> Some Cancel
        | Escape -> Some Cancel
        | _ -> None)

let get_selected model =
  if not model.confirmed then []
  else
    Array.to_list model.items
    |> List.mapi (fun i item -> (i, item))
    |> List.filter_map (fun (i, item) ->
         if model.selected.(i) then Some item.value else None)

let run_select ~title ?(confirm_label = "Zatwierdź") ?detail_fn items =
  let visible_height = min 15 (List.length items) in
  let model = ref (fst (init ~title ~visible_height ~confirm_label ?detail_fn items)) in
  Mosaic.run
    { init = (fun () -> init ~title ~visible_height ~confirm_label ?detail_fn items);
      update = (fun msg m -> let m', cmd = update msg m in model := m'; (m', cmd));
      view;
      subscriptions };
  get_selected !model
