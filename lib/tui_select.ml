open Mosaic

type 'a item = {
  value : 'a;
  label : string;
  description : string;
}

type 'a model = {
  items : 'a item array;
  cursor : int;
  selected : bool array;
  scroll_offset : int;
  visible_height : int;
  confirmed : bool;
  title : string;
}

type msg =
  | Move_up
  | Move_down
  | Toggle
  | Toggle_all
  | Confirm
  | Cancel

let init ~title ~visible_height items =
  let items = Array.of_list items in
  let selected = Array.make (Array.length items) false in
  ({ items; cursor = 0; selected; scroll_offset = 0;
     visible_height; confirmed = false; title }, Cmd.none)

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
  match msg with
  | Move_up ->
    let cursor = max 0 (model.cursor - 1) in
    (clamp_scroll { model with cursor }, Cmd.none)
  | Move_down ->
    let cursor = min (Array.length model.items - 1) (model.cursor + 1) in
    (clamp_scroll { model with cursor }, Cmd.none)
  | Toggle ->
    model.selected.(model.cursor) <- not model.selected.(model.cursor);
    (model, Cmd.none)
  | Toggle_all ->
    let all_selected = Array.for_all Fun.id model.selected in
    Array.fill model.selected 0 (Array.length model.selected) (not all_selected);
    (model, Cmd.none)
  | Confirm ->
    ({ model with confirmed = true }, Cmd.quit)
  | Cancel ->
    ({ model with confirmed = false }, Cmd.quit)

let hint_style = Ansi.Style.make ~fg:(Ansi.Color.grayscale ~level:14) ()
let title_style = Ansi.Style.make ~bold:true ()
let accent = Ansi.Color.cyan
let green = Ansi.Color.green

let view model =
  let n = Array.length model.items in
  let end_i = min n (model.scroll_offset + model.visible_height) in
  let rows =
    List.init (end_i - model.scroll_offset) (fun rel ->
        let i = model.scroll_offset + rel in
        let is_cur = i = model.cursor in
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
  box ~flex_direction:Column
    ~size:{ width = pct 100; height = pct 100 }
    [ box ~padding:(padding 1)
        [ text ~style:title_style model.title ];
      box ~flex_direction:Column ~padding:(padding 1) rows;
      box ~padding:(padding 1)
        [ text ~style:hint_style
            (Printf.sprintf
               "  ↑↓ navigate  ␣ toggle  a toggle all  enter confirm  q cancel    (%d selected)"
               (selected_count model)) ]
    ]

let subscriptions _model =
  Sub.on_key (fun ev ->
      match (Mosaic_ui.Event.Key.data ev).key with
      | Up -> Some Move_up
      | Down -> Some Move_down
      | Char c when Uchar.equal c (Uchar.of_char 'k') -> Some Move_up
      | Char c when Uchar.equal c (Uchar.of_char 'j') -> Some Move_down
      | Char c when Uchar.equal c (Uchar.of_char ' ') -> Some Toggle
      | Char c when Uchar.equal c (Uchar.of_char 'a') -> Some Toggle_all
      | Enter -> Some Confirm
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

let run_select ~title items =
  let visible_height = min 15 (List.length items) in
  let model = ref (fst (init ~title ~visible_height items)) in
  Mosaic.run
    { init = (fun () -> init ~title ~visible_height items);
      update = (fun msg m -> let m', cmd = update msg m in model := m'; (m', cmd));
      view;
      subscriptions };
  get_selected !model
