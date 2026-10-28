class_name MainMenu extends Node3D
## Main menu: floating 3D blocks panorama + Persian UI.

var main: Main
var cam: Camera3D
var ui: CanvasLayer
var layer_root: Control
var cubes: Array = []
var settings_panel: Control
var about_panel: Control
var b_continue: Button
var font_bold: FontFile
var font_reg: FontFile


func _ready() -> void:
	font_bold = load("res://assets/Vazirmatn-Bold.ttf")
	font_reg = load("res://assets/Vazirmatn-Regular.ttf")
	cam = Camera3D.new()
	cam.fov = 65.0
	add_child(cam)
	cam.position = Vector3(0, 0.4, 7.2)
	cam.current = true

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var tiles := [0, 3, 9, 4, 5, 11]
	for i in 14:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * rng.randf_range(0.55, 1.3)
		var m := StandardMaterial3D.new()
		var t: int = tiles[i % tiles.size()]
		m.albedo_texture = Tex.atlas()
		m.uv1_scale = Vector3(0.125, 0.125, 1.0)
		m.uv1_offset = Vector3((t % 8) / 8.0, (t / 8) / 8.0, 0.0)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.roughness = 1.0
		bm.material = m
		mi.mesh = bm
		mi.position = Vector3(rng.randf_range(-5.2, 5.2), rng.randf_range(-3.4, 3.6), rng.randf_range(-4.0, 1.5))
		mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		add_child(mi)
		cubes.append(mi)

	_build_ui()


func _process(delta: float) -> void:
	for i in cubes.size():
		var c: MeshInstance3D = cubes[i]
		c.rotation.y += delta * (0.25 + 0.03 * i)
		c.rotation.x += delta * 0.07
		c.position.y += sin(Time.get_ticks_msec() / 1000.0 + i * 1.7) * delta * 0.12


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


func _btn(text: String, w := 380.0, h := 64.0, fs := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", fs)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.32, 0.13, 0.82)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.2)
	b.add_theme_stylebox_override("normal", sb)
	var sbp := sb.duplicate()
	sbp.bg_color = Color(0.2, 0.5, 0.2, 0.92)
	b.add_theme_stylebox_override("pressed", sbp)
	var sbh := sb.duplicate()
	sbh.bg_color = Color(0.17, 0.4, 0.17, 0.9)
	b.add_theme_stylebox_override("hover", sbh)
	var sbd := sb.duplicate()
	sbd.bg_color = Color(0.1, 0.1, 0.12, 0.5)
	b.add_theme_stylebox_override("disabled", sbd)
	return b


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	layer_root = Control.new()
	layer_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(layer_root)

	var bg := TextureRect.new()
	bg.texture = Tex.gradient_tex()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_root.add_child(bg)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -220
	v.offset_right = 220
	v.offset_top = -250
	v.offset_bottom = 260
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	layer_root.add_child(v)

	var title := _label("بلوک کرافت", 74)
	v.add_child(title)
	var sub := _label("دنیای بلوکی خودت را بساز", 22)
	sub.add_theme_color_override("font_color", Color(0.8, 0.86, 0.8))
	v.add_child(sub)

	v.add_child(_spacer(10))

	var b_new := _btn("شروع بازی جدید")
	b_new.pressed.connect(func(): main.start_game(true))
	v.add_child(b_new)

	b_continue = _btn("ادامه بازی")
	b_continue.pressed.connect(func(): main.start_game(false))
	v.add_child(b_continue)

	var b_set := _btn("تنظیمات")
	b_set.pressed.connect(func():
		settings_panel.visible = true
		Sfx.play("click"))
	v.add_child(b_set)

	var b_about := _btn("درباره بازی")
	b_about.pressed.connect(func(): about_panel.visible = true)
	v.add_child(b_about)

	var foot := _label("نسخه 2.0 — موتور Godot", 16)
	foot.add_theme_color_override("font_color", Color(0.55, 0.6, 0.55))
	v.add_child(foot)

	_build_settings()
	_build_about()
	refresh()


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _build_settings() -> void:
	settings_panel = _panel(Vector2(460, 360))
	var v: VBoxContainer = settings_panel.get_child(0)
	v.add_child(_label("تنظیمات", 36))
	v.add_child(_label("فاصله دید (سبک‌تر = سریع‌تر)", 20))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	for pair in [[2, "نزدیک"], [3, "متوسط"], [4, "دور"]]:
		var b := _btn(pair[1], 120.0, 50.0, 20)
		b.pressed.connect(func():
			main.rd = pair[0]
			Sfx.play("click"))
		h.add_child(b)
	v.add_child(h)
	var b_close := _btn("بستن", 380.0, 54.0, 22)
	b_close.pressed.connect(func(): settings_panel.visible = false)
	v.add_child(b_close)


func _build_about() -> void:
	about_panel = _panel(Vector2(520, 320))
	var v: VBoxContainer = about_panel.get_child(0)
	var t := _label("درباره", 34)
	v.add_child(t)
	var txt := Label.new()
	txt.text = "بلوک کرافت — بازی دنیای بلوکی ساخته‌شده با موتور Godot 4\nساخته شده برای ساند جان — نسخه 2.0"
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.add_theme_font_override("font", font_reg)
	txt.add_theme_font_size_override("font_size", 20)
	v.add_child(txt)
	var b_close := _btn("بستن", 380.0, 54.0, 22)
	b_close.pressed.connect(func(): about_panel.visible = false)
	v.add_child(b_close)


func _panel(size: Vector2) -> PanelContainer:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.visible = false
	layer_root.add_child(ov)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.55)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.add_child(bg)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.1, 0.94)
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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(v)
	return pc


func refresh() -> void:
	if b_continue:
		b_continue.disabled = not main.has_save()


func show_menu() -> void:
	visible = true
	cam.current = true
	refresh()


func hide_menu() -> void:
	visible = false
