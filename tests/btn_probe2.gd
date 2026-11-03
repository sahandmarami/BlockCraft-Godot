extends SceneTree
## Probe 2: simulate the REAL Android input path via Input.parse_input_event
## (applies emulate_* flags like the OS layer does). Counts button clicks.
## Run with project.godot emulate_mouse_from_touch=true to check double-fire.

var frames := 0
var b: Button
var clicks := 0
var downs := 0


func _initialize() -> void:
        b = Button.new()
        b.text = "T"
        b.position = Vector2(4, 4)
        b.size = Vector2(50, 40)
        root.add_child(b)
        b.pressed.connect(func(): clicks += 1)
        b.button_down.connect(func(): downs += 1)
        # remove stretch transform so window coords == canvas coords in headless
        root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
        root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
        print("CFG emulate_mouse_from_touch=", ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"))


func _process(_d: float) -> bool:
        frames += 1
        if frames == 5:
                var t := InputEventScreenTouch.new()
                t.index = 0
                t.pressed = true
                t.position = Vector2i(25, 20)
                Input.parse_input_event(t)
        if frames == 10:
                var t2 := InputEventScreenTouch.new()
                t2.index = 0
                t2.pressed = false
                t2.position = Vector2i(25, 20)
                Input.parse_input_event(t2)
        if frames == 30:
                print("PROBE2 clicks=", clicks, " downs=", downs, " (1/1 = no double-fire, 2/2 = DOUBLE)")
                quit(0)
        return false
