extends SceneTree
## UI regression test through the REAL input pipeline (Input.parse_input_event +
## stretch transform — the exact path Android uses). Boots the app, taps the
## start button, waits for the world, drags to look, taps pause. Run:
##   godot --headless --path . -s res://tests/ui_sim.gd
## Requires overrides.cfg (640x360 window) for a device-like headless canvas.

var frames := 0
var main
var phase := "boot"
var fail := ""
var yaw0 := 0.0
var b_start: Button
var b_pause: Button


## canvas (design 1280x720) -> window coords, like the engine does for real input
func _to_window(canvas: Vector2) -> Vector2:
        var f: float = root.size.x / 1280.0
        return canvas * f


func _tap_canvas(canvas: Vector2, idx := 0) -> void:
        var p := _to_window(canvas)
        var t := InputEventScreenTouch.new()
        t.index = idx
        t.pressed = true
        t.position = p
        Input.parse_input_event(t)
        var t2 := InputEventScreenTouch.new()
        t2.index = idx
        t2.pressed = false
        t2.position = p
        Input.parse_input_event(t2)


func _find_btn(n: Node, text: String) -> Button:
        if n is Button and n.text == text:
                return n
        for c in n.get_children():
                var r := _find_btn(c, text)
                if r:
                        return r
        return null


func _initialize() -> void:
        print("UI-SIM root_size=", root.size, " scale_size=", root.content_scale_size)
        var ms: Node = load("res://scenes/main.tscn").instantiate()
        root.add_child(ms)
        main = ms


func _who_is_at(canvas_p: Vector2) -> void:
        var stack := [main]
        while stack.size() > 0:
                var n = stack.pop_back()
                if n is Control and n.is_visible_in_tree() and n.mouse_filter != Control.MOUSE_FILTER_IGNORE \
                                and n.get_global_rect().has_point(canvas_p):
                        print("  CONTROL-AT: ", n.get_class(), " ", n.get_parent().get_class(), " filter=", n.mouse_filter)
                for c in n.get_children():
                        stack.push_back(c)


func _process(_d: float) -> bool:
        frames += 1
        match phase:
                "boot":
                        if frames > 40:
                                fail = "menu not ready"
                                _finish(false)
                        elif main.menu != null and main.menu.is_inside_tree():
                                b_start = _find_btn(main, "شروع بازی جدید")
                                if b_start == null:
                                        fail = "start button not found"
                                        _finish(false)
                                        return false
                                phase = "tap_start"
                "tap_start":
                        print("UI-SIM start rect(canvas)=", b_start.get_global_rect())
                        _tap_canvas(b_start.get_global_rect().get_center())
                        phase = "wait_world"
                "wait_world":
                        if main.player != null and main.state == "playing":
                                print("UI-SIM entered game, pos=", main.player.global_position)
                                yaw0 = main.player.get_look().x
                                phase = "look_drag"
                        elif frames > 1500:
                                fail = "never entered game (state=%s)" % main.state
                                _finish(false)
                                return false
                "look_drag":
                        var canvas_p := Vector2(640, 310)
                        print("UI-SIM scanning controls at ", canvas_p)
                        _who_is_at(canvas_p)
                        var wp := _to_window(canvas_p)
                        var t := InputEventScreenTouch.new()
                        t.index = 5
                        t.pressed = true
                        t.position = wp
                        Input.parse_input_event(t)
                        phase = "drag_move"
                "drag_move":
                        if frames % 5 != 0:
                                return false
                        print("UI-SIM after press: look_touch=", main.hud.get("_look_touch"))
                        var wp := _to_window(Vector2(640, 310))
                        for i in 4:
                                var dr := InputEventScreenDrag.new()
                                dr.index = 5
                                dr.position = wp + Vector2(30.0 * (i + 1), 4.0 * (i + 1))
                                dr.relative = Vector2(30.0, 4.0)
                                Input.parse_input_event(dr)
                        phase = "check_look"
                "check_look":
                        if frames % 10 == 0:
                                var dyaw: float = absf(main.player.get_look().x - yaw0)
                                print("UI-SIM dyaw=", dyaw, " look_touch=", main.hud.get("_look_touch"))
                                if dyaw > 0.5:
                                        var t2 := InputEventScreenTouch.new()
                                        t2.index = 5
                                        t2.pressed = false
                                        t2.position = _to_window(Vector2(760, 326))
                                        Input.parse_input_event(t2)
                                        b_pause = _find_btn(main, "مکث")
                                        if b_pause == null:
                                                fail = "pause button not found"
                                                _finish(false)
                                                return false
                                        _tap_canvas(b_pause.get_global_rect().get_center(), 7)
                                        phase = "check_pause"
                                elif frames > 400:
                                        fail = "look drag did not change yaw"
                                        _finish(false)
                                        return false
                "check_pause":
                        if main.hud != null and main.hud.pause_panel.visible:
                                print("UI-SIM pause panel visible")
                                _finish(true)
                                return false
                        elif frames > 400:
                                fail = "pause panel did not open"
                                _finish(false)
                                return false
        return false


func _finish(ok: bool) -> void:
        if ok:
                print("UI-SIM-OK")
                quit(0)
        else:
                print("UI-SIM-FAIL: ", fail)
                quit(1)
