extends SceneTree
## Probe: does a standard Godot 4.7 Button react to raw InputEventScreenTouch?

var frames := 0
var b: Button
var touch_clicked := false
var mouse_clicked := false


func _initialize() -> void:
        b = Button.new()
        b.text = "T"
        b.position = Vector2(4, 4)
        b.size = Vector2(50, 40)
        root.add_child(b)
        b.gui_input.connect(func(ev): print("GUI-IN ", ev.get_class(), " pressed=", ev.get("pressed")))
        b.pressed.connect(_on_pressed)


func _mark(_x) -> void:
        pass


func _on_pressed() -> void:
        if _phase == 1:
                touch_clicked = true
        elif _phase == 2:
                mouse_clicked = true


var _phase := 0


func _process(_d: float) -> bool:
        frames += 1
        if frames == 2:
                print("DBG root_size=", root.size, " btn_rect=", b.get_global_rect(), " visible=", b.is_visible_in_tree())
        if frames == 5:
                _phase = 1
                var t := InputEventScreenTouch.new()
                t.index = 1
                t.pressed = true
                t.position = Vector2(25, 20)
                root.push_input(t, true)
        if frames == 10:
                var t2 := InputEventScreenTouch.new()
                t2.index = 1
                t2.pressed = false
                t2.position = Vector2(25, 20)
                root.push_input(t2, true)
        if frames == 20:
                _phase = 2
                var m := InputEventMouseButton.new()
                m.button_index = MOUSE_BUTTON_LEFT
                m.pressed = true
                m.position = Vector2(25, 20)
                m.global_position = Vector2(25, 20)
                root.push_input(m, true)
        if frames == 25:
                var m2 := InputEventMouseButton.new()
                m2.button_index = MOUSE_BUTTON_LEFT
                m2.pressed = false
                m2.position = Vector2(25, 20)
                m2.global_position = Vector2(25, 20)
                root.push_input(m2, true)
        if frames == 35:
                print("PROBE touch_clicked=", touch_clicked, " mouse_clicked=", mouse_clicked)
                quit(0)
        return false
