class_name GameHud extends CanvasLayer
## Persian RTL touch HUD: joystick, action buttons, hotbar, hearts, menus.

var main
var player: PlayerCtl
var world: VoxelWorld
var mobs: MobMgr

var font_reg: FontFile
var font_bold: FontFile

var joy_vec := Vector2.ZERO
var _joy_touch := -1
var _joy_center := Vector2(92, 92)
var _look_touch := -1

var root: Control
var knob: Panel
var hearts: Array = []
var slots: Array = []
var sel := 0
var pause_panel: Control
var death_panel: Control
var repeat_timer: Timer
var _repeat_fn: Callable
var sens := 1.0

const SLOT = 54


func _ready() -> void:
        font_reg = load("res://assets/Vazirmatn-Regular.ttf")
        font_bold = load("res://assets/Vazirmatn-Bold.ttf")

        root = Control.new()
        root.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(root)

        _build_joystick()
        _build_hotbar()
        _build_hearts()
        _build_buttons()
        _build_crosshair()
        _build_topbar()
        _build_pause()
        _build_death()

        repeat_timer = Timer.new()
        repeat_timer.wait_time = 0.26
        repeat_timer.one_shot = false
        repeat_timer.timeout.connect(_on_repeat)
        add_child(repeat_timer)


func _label(text: String, size: int) -> Label:
        var l := Label.new()
        l.text = text
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        l.add_theme_font_override("font", font_bold)
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
        l.add_theme_constant_override("shadow_offset_x", 2)
        l.add_theme_constant_override("shadow_offset_y", 2)
        l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return l


func _btn(text: String, size: float, font_size: int) -> Button:
        var b := Button.new()
        b.text = text
        b.custom_minimum_size = Vector2(size, size)
        b.focus_mode = Control.FOCUS_NONE
        b.add_theme_font_override("font", font_bold)
        b.add_theme_font_size_override("font_size", font_size)
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.08, 0.09, 0.12, 0.5)
        sb.set_corner_radius_all(int(size / 4.5))
        sb.border_width_bottom = 3
        sb.border_color = Color(0, 0, 0, 0.45)
        b.add_theme_stylebox_override("normal", sb)
        var sbp := sb.duplicate()
        sbp.bg_color = Color(0.85, 0.45, 0.1, 0.55)
        b.add_theme_stylebox_override("pressed", sbp)
        var sbh := sb.duplicate()
        sbh.bg_color = Color(0.15, 0.17, 0.22, 0.55)
        b.add_theme_stylebox_override("hover", sbh)
        return b


## Place a control by anchor point (ax, ay in 0/1) with top-left offsets.
func _place(c: Control, ax: float, ay: float, off: Vector2, size: Vector2) -> void:
        c.anchor_left = ax
        c.anchor_right = ax
        c.anchor_top = ay
        c.anchor_bottom = ay
        c.offset_left = off.x
        c.offset_top = off.y
        c.offset_right = off.x + size.x
        c.offset_bottom = off.y + size.y
        c.grow_horizontal = Control.GROW_DIRECTION_BOTH
        c.grow_vertical = Control.GROW_DIRECTION_BOTH


func _build_joystick() -> void:
        var joy := Panel.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(1, 1, 1, 0.10)
        sb.set_corner_radius_all(85)
        sb.set_border_width_all(3)
        sb.border_color = Color(1, 1, 1, 0.22)
        joy.add_theme_stylebox_override("panel", sb)
        _place(joy, 0.0, 1.0, Vector2(34, -218), Vector2(184, 184))
        joy.mouse_filter = Control.MOUSE_FILTER_STOP
        root.add_child(joy)

        knob = Panel.new()
        var skb := StyleBoxFlat.new()
        skb.bg_color = Color(1, 1, 1, 0.35)
        skb.set_corner_radius_all(38)
        knob.add_theme_stylebox_override("panel", skb)
        knob.size = Vector2(76, 76)
        knob.position = _joy_center - Vector2(38, 38)
        knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
        joy.add_child(knob)

        joy.gui_input.connect(_on_joy_input)


func _on_joy_input(ev: InputEvent) -> void:
        if ev is InputEventScreenTouch:
                if ev.pressed:
                        _joy_touch = ev.index
                        _update_joy(ev.position)
                elif ev.index == _joy_touch:
                        _joy_touch = -1
                        joy_vec = Vector2.ZERO
                        knob.position = _joy_center - Vector2(38, 38)
        elif ev is InputEventScreenDrag and ev.index == _joy_touch:
                _update_joy(ev.position)


func _update_joy(p: Vector2) -> void:
        var d := p - _joy_center
        if d.length() > 62.0:
                d = d.normalized() * 62.0
        joy_vec = d / 62.0
        knob.position = _joy_center + d - Vector2(38, 38)


func _build_hotbar() -> void:
        var bar := HBoxContainer.new()
        bar.add_theme_constant_override("separation", 6)
        bar.anchor_left = 0.5
        bar.anchor_right = 0.5
        bar.anchor_top = 1.0
        bar.anchor_bottom = 1.0
        bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
        bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
        bar.offset_bottom = -16
        bar.offset_top = -16 - SLOT
        bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(bar)
        for i in Blocks.HOTBAR.size():
                var slot := Panel.new()
                var sb := StyleBoxFlat.new()
                sb.bg_color = Color(0.05, 0.05, 0.08, 0.55)
                sb.set_corner_radius_all(10)
                sb.set_border_width_all(2)
                sb.border_color = Color(1, 1, 1, 0.25)
                slot.add_theme_stylebox_override("panel", sb)
                slot.custom_minimum_size = Vector2(SLOT, SLOT)
                slot.mouse_filter = Control.MOUSE_FILTER_STOP
                var icon := TextureRect.new()
                icon.texture = Tex.atlas_texture_for_tile(Blocks.ICON_TILE[Blocks.HOTBAR[i]])
                icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                icon.set_anchors_preset(Control.PRESET_FULL_RECT)
                icon.offset_left = 6
                icon.offset_top = 6
                icon.offset_right = -6
                icon.offset_bottom = -6
                icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
                slot.add_child(icon)
                slot.gui_input.connect(_on_slot_input.bind(i))
                bar.add_child(slot)
                slots.append(slot)
        select_slot(0)


func _on_slot_input(ev: InputEvent, i: int) -> void:
        if ev is InputEventScreenTouch and ev.pressed:
                select_slot(i)
                Sfx.play("click")


func select_slot(i: int) -> void:
        sel = i
        for j in slots.size():
                var ns := StyleBoxFlat.new()
                ns.set_corner_radius_all(10)
                if j == sel:
                        ns.set_border_width_all(3)
                        ns.border_color = Color(1.0, 0.85, 0.25)
                        ns.bg_color = Color(0.1, 0.1, 0.14, 0.75)
                else:
                        ns.set_border_width_all(2)
                        ns.border_color = Color(1, 1, 1, 0.25)
                        ns.bg_color = Color(0.05, 0.05, 0.08, 0.55)
                slots[j].add_theme_stylebox_override("panel", ns)


func _build_hearts() -> void:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 2)
        row.position = Vector2(18, 14)
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(row)
        for i in 10:
                var h := TextureRect.new()
                h.texture = Tex.heart(true)
                h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                h.custom_minimum_size = Vector2(26, 26)
                h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                h.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                h.mouse_filter = Control.MOUSE_FILTER_IGNORE
                row.add_child(h)
                hearts.append(h)


func set_hp(hp: int) -> void:
        for i in 10:
                if hp >= i * 2 + 2:
                        hearts[i].texture = Tex.heart(true)
                        hearts[i].self_modulate = Color(1, 1, 1, 1)
                elif hp == i * 2 + 1:
                        hearts[i].texture = Tex.heart(true)
                        hearts[i].self_modulate = Color(1, 1, 1, 0.45)
                else:
                        hearts[i].texture = Tex.heart(false)
                        hearts[i].self_modulate = Color(1, 1, 1, 1)


func _build_buttons() -> void:
        var b_jump := _btn("پرش", 88, 21)
        _place(b_jump, 1.0, 1.0, Vector2(-106, -106), Vector2(88, 88))
        b_jump.button_down.connect(_on_jump_down)
        root.add_child(b_jump)

        var b_break := _btn("شکستن", 84, 19)
        _place(b_break, 1.0, 1.0, Vector2(-206, -102), Vector2(84, 84))
        _hold_button(b_break, _act_break)
        root.add_child(b_break)

        var b_place := _btn("گذاشتن", 84, 19)
        _place(b_place, 1.0, 1.0, Vector2(-102, -206), Vector2(84, 84))
        _hold_button(b_place, _act_place)
        root.add_child(b_place)

        var b_atk := _btn("زدن", 84, 22)
        _place(b_atk, 1.0, 1.0, Vector2(-206, -206), Vector2(84, 84))
        _hold_button(b_atk, _act_attack)
        root.add_child(b_atk)


func _on_jump_down() -> void:
        if player:
                player.jump_req = true


func _act_break() -> void:
        if player:
                player.do_break()


func _act_place() -> void:
        if player:
                player.do_place(Blocks.HOTBAR[sel])


func _act_attack() -> void:
        if player and mobs:
                mobs.hit_in_front(player.eye_pos(), player.look_dir())


func _hold_button(b: Button, fn: Callable) -> void:
        b.button_down.connect(func():
                _repeat_fn = fn
                fn.call()
                repeat_timer.start())
        b.button_up.connect(func(): repeat_timer.stop())


func _on_repeat() -> void:
        if _repeat_fn.is_valid():
                _repeat_fn.call()


func _build_crosshair() -> void:
        var dot := Panel.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(1, 1, 1, 0.8)
        sb.set_corner_radius_all(3)
        sb.set_border_width_all(1)
        sb.border_color = Color(0, 0, 0, 0.5)
        dot.add_theme_stylebox_override("panel", sb)
        dot.anchor_left = 0.5
        dot.anchor_right = 0.5
        dot.anchor_top = 0.5
        dot.anchor_bottom = 0.5
        dot.offset_left = -3
        dot.offset_top = -3
        dot.offset_right = 3
        dot.offset_bottom = 3
        dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(dot)


func _build_topbar() -> void:
        var b_pause := _btn("مکث", 64, 20)
        _place(b_pause, 1.0, 0.0, Vector2(-80, 14), Vector2(64, 64))
        b_pause.pressed.connect(_open_pause)
        root.add_child(b_pause)


func _build_pause() -> void:
        pause_panel = _overlay()
        var panel := _center_panel(pause_panel, Vector2(440, 470))
        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 14)
        panel.add_child(v)

        v.add_child(_label("مکث", 40))

        var b_resume := _btn("ادامه بازی", 380, 24)
        b_resume.custom_minimum_size = Vector2(380, 56)
        b_resume.pressed.connect(_on_resume)
        v.add_child(b_resume)

        v.add_child(_label("صدا", 20))
        var s_vol := HSlider.new()
        s_vol.min_value = 0.0
        s_vol.max_value = 1.0
        s_vol.step = 0.05
        s_vol.value = Sfx.volume
        s_vol.custom_minimum_size = Vector2(380, 30)
        s_vol.value_changed.connect(_on_vol)
        v.add_child(s_vol)

        v.add_child(_label("حساسیت نگاه", 20))
        var s_sens := HSlider.new()
        s_sens.min_value = 0.4
        s_sens.max_value = 2.2
        s_sens.step = 0.1
        s_sens.value = sens
        s_sens.custom_minimum_size = Vector2(380, 30)
        s_sens.value_changed.connect(_on_sens)
        v.add_child(s_sens)

        var b_menu := _btn("ذخیره و بازگشت به منو", 380, 21)
        b_menu.custom_minimum_size = Vector2(380, 52)
        b_menu.pressed.connect(_on_back)
        v.add_child(b_menu)


func _on_resume() -> void:
        pause_panel.visible = false
        Sfx.play("click")


func _on_vol(val: float) -> void:
        Sfx.set_volume(val)


func _on_sens(val: float) -> void:
        sens = val
        if player:
                player.sens = val


func _on_back() -> void:
        pause_panel.visible = false
        main.back_to_menu()


func _open_pause() -> void:
        pause_panel.visible = true
        Sfx.play("click")


func _build_death() -> void:
        death_panel = _overlay()
        var bg: ColorRect = death_panel.get_child(0)
        bg.color = Color(0.45, 0.02, 0.02, 0.55)
        var panel := _center_panel(death_panel, Vector2(440, 280))
        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 18)
        panel.add_child(v)
        v.add_child(_label("مردی!", 46))
        var b := _btn("تولد دوباره", 380, 24)
        b.custom_minimum_size = Vector2(380, 56)
        b.pressed.connect(_on_respawn)
        v.add_child(b)


func _on_respawn() -> void:
        main.respawn()


func _overlay() -> Control:
        var ov := Control.new()
        ov.set_anchors_preset(Control.PRESET_FULL_RECT)
        ov.visible = false
        root.add_child(ov)
        var bg := ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = Color(0, 0, 0, 0.5)
        bg.mouse_filter = Control.MOUSE_FILTER_STOP
        ov.add_child(bg)
        return ov


func _center_panel(ov: Control, size: Vector2) -> PanelContainer:
        var pc := PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.09, 0.1, 0.14, 0.92)
        sb.set_corner_radius_all(18)
        sb.set_border_width_all(2)
        sb.border_color = Color(1, 1, 1, 0.15)
        sb.set_content_margin_all(24.0)
        pc.add_theme_stylebox_override("panel", sb)
        pc.anchor_left = 0.5
        pc.anchor_right = 0.5
        pc.anchor_top = 0.5
        pc.anchor_bottom = 0.5
        pc.offset_left = -size.x / 2.0
        pc.offset_top = -size.y / 2.0
        pc.offset_right = size.x / 2.0
        pc.offset_bottom = size.y / 2.0
        pc.custom_minimum_size = size
        ov.add_child(pc)
        return pc


func show_death() -> void:
        death_panel.visible = true


func hide_death() -> void:
        death_panel.visible = false


func _unhandled_input(ev: InputEvent) -> void:
        # look drag: any touch not consumed by HUD controls
        if ev is InputEventScreenTouch:
                if ev.pressed:
                        _look_touch = ev.index
                elif ev.index == _look_touch:
                        _look_touch = -1
        elif ev is InputEventScreenDrag and ev.index == _look_touch:
                if player:
                        player.apply_look(ev.relative.x, ev.relative.y)
