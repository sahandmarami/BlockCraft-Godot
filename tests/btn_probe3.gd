extends SceneTree
## Probe 3: what coordinate space does _unhandled_input see, and does the
## stretch transform apply? Simulates the real device path (parse_input_event).

var frames := 0
var probe: Node
var last_unhandled := Vector2.ZERO
var b: Button


func _initialize() -> void:
        b = Button.new()
        b.text = "T"
        b.position = Vector2(200, 140)
        b.size = Vector2(60, 40)
        root.add_child(b)
        probe = Node.new()
        probe.set_script(load("res://tests/unhandled_probe.gd"))
        root.add_child(probe)


func _process(_d: float) -> bool:
        frames += 1
        if frames == 3:
                print("CFG stretch=", ProjectSettings.get_setting("display/window/stretch/mode"),
                        " root_size=", root.size, " content_scale_size=", root.content_scale_size)
        if frames == 10:
                # tap at canvas point (220,155) which is inside the button
                var t := InputEventScreenTouch.new()
                t.index = 0
                t.pressed = true
                t.position = Vector2i(220, 155)
                Input.parse_input_event(t)
        if frames == 20:
                var t2 := InputEventScreenTouch.new()
                t2.index = 0
                t2.pressed = false
                t2.position = Vector2i(220, 155)
                Input.parse_input_event(t2)
        if frames == 30:
                var lu: Vector2 = root.get_meta("last_unhandled", Vector2(-1, -1))
                print("PROBE3 last_unhandled=", lu, " (sent canvas 220,155)")
                quit(0)
        return false
