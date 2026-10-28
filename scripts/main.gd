class_name Main extends Node
## App entry: main menu -> world loading -> gameplay. Day/night, saves, env.

const SAVE_PATH := "user://blockcraft_save.json"
const DAY_LEN := 480.0  # seconds per full cycle

var state := "menu"  # menu | loading | playing
var world: VoxelWorld
var player: PlayerCtl
var mobs: MobMgr
var hud: GameHud
var menu: MainMenu
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var save_data := {}

var rd := 2
var spawn_pos := Vector3(8.5, 40, 8.5)
var autosave_t := 0.0

var loading_layer: CanvasLayer
var load_bar: ProgressBar
var load_label: Label


func _ready() -> void:
        _build_env()
        menu = MainMenu.new()
        menu.main = self
        add_child(menu)


func _build_env() -> void:
        world_env = WorldEnvironment.new()
        var env := Environment.new()
        var sky_mat := ProceduralSkyMaterial.new()
        sky_mat.sun_angle_max = 30.0
        var sky := Sky.new()
        sky.sky_material = sky_mat
        env.background_mode = Environment.BG_SKY
        env.sky = sky
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(0.75, 0.8, 0.9)
        env.ambient_light_energy = 1.0
        env.fog_enabled = true
        env.fog_density = 0.009
        env.fog_light_color = Color(0.72, 0.82, 0.95)
        world_env.environment = env
        add_child(world_env)

        sun = DirectionalLight3D.new()
        sun.rotation_degrees = Vector3(-46, 32, 0)
        sun.light_energy = 1.1
        add_child(sun)


func _process(delta: float) -> void:
        if state == "playing" and world != null and player != null:
                if hud:
                        player.joy = hud.joy_vec
                world.player_pos = player.global_position
                world.stream_around(player.global_position)
                world.tod = fposmod(world.tod + delta / DAY_LEN, 1.0)
                _update_sky()
                autosave_t += delta
                if autosave_t > 25.0:
                        autosave_t = 0.0
                        save_game()


func _update_sky() -> void:
        var sf: float = world.sun_factor()
        var env := world_env.environment
        var sky_mat: ProceduralSkyMaterial = env.sky.sky_material
        var top_day := Color(0.28, 0.55, 0.92)
        var hor_day := Color(0.7, 0.84, 0.96)
        var top_night := Color(0.012, 0.02, 0.06)
        var hor_night := Color(0.05, 0.07, 0.13)
        var top := top_night.lerp(top_day, sf)
        var hor := hor_night.lerp(hor_day, sf)
        # sunset / sunrise tint
        var edge := 0.0
        if world.tod > 0.44 and world.tod < 0.62:
                edge = 1.0 - absf(world.tod - 0.53) / 0.09
        elif world.tod > 0.9 or world.tod < 0.05:
                edge = 1.0 - absf(world.tod - 0.975) / 0.075 if world.tod > 0.9 else 1.0 - absf(world.tod + 0.025) / 0.075
        edge = clampf(edge, 0.0, 1.0)
        hor = hor.lerp(Color(0.95, 0.55, 0.25), edge * 0.7)
        sky_mat.sky_top_color = top
        sky_mat.sky_horizon_color = hor
        sky_mat.ground_bottom_color = top.darkened(0.4)
        sky_mat.ground_horizon_color = hor
        env.fog_light_color = hor
        env.ambient_light_color = Color(0.2, 0.24, 0.34).lerp(Color(0.78, 0.82, 0.9), sf)
        env.ambient_light_energy = 0.6 + 0.5 * sf
        sun.light_energy = 0.06 + 1.05 * sf
        sun.light_color = Color(1.0, 0.92, 0.82).lerp(Color(1.0, 0.62, 0.36), edge * 0.8)
        sun.rotation_degrees = Vector3(-24.0 - 30.0 * sf, 30.0 + world.tod * 360.0, 0)


# ---------- save / load ----------

func save_game() -> void:
        if world == null or player == null:
                return
        var d := {
                "seed": world.seed_val,
                "tod": world.tod,
                "hp": player.hp,
                "rd": rd,
                "player": {
                        "x": player.global_position.x, "y": player.global_position.y, "z": player.global_position.z,
                        "yaw": player.get_look().x, "pitch": player.get_look().y,
                },
                "mods": {},
        }
        for k in world.mods:
                var m := {}
                for i in world.mods[k]:
                        m[str(i)] = world.mods[k][i]
                d.mods[k] = m
        var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
        if f:
                f.store_string(JSON.stringify(d))


func load_save() -> Dictionary:
        if FileAccess.file_exists(SAVE_PATH):
                var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
                if f:
                        var parsed = JSON.parse_string(f.get_as_text())
                        if parsed is Dictionary:
                                return parsed
        return {}


func has_save() -> bool:
        return FileAccess.file_exists(SAVE_PATH)


# ---------- flow ----------

func start_game(new_game: bool) -> void:
        if state == "loading":
                return
        menu.hide_menu()
        state = "loading"
        _build_loading_ui()
        var data := {}
        if not new_game:
                data = load_save()
        save_data = data
        # tear down previous session
        _clear_game()
        world = VoxelWorld.new()
        var sd := int(data.get("seed", randi() % 1000000))
        world.setup_noise(sd)
        rd = int(data.get("rd", rd))
        world.rd = rd
        if data.has("mods"):
                for k in data.mods:
                        var m := {}
                        for i in data.mods[k]:
                                m[int(i)] = int(data.mods[k][i])
                        world.mods[k] = m
        if data.has("tod"):
                world.tod = float(data.tod)
        add_child(world)

        var sx := 8
        var sz := 8
        var look := Vector2(0, 0)
        var saved_spawn := false
        if data.has("player"):
                spawn_pos = Vector3(float(data.player.x), float(data.player.y), float(data.player.z))
                look = Vector2(float(data.player.yaw), float(data.player.pitch))
                saved_spawn = true

        # pregen around spawn with progress bar
        var pcx := sx / world.CS
        var pcz := sz / world.CS
        var gen_list: Array = []
        var mesh_list: Array = []
        for dx in range(-rd - 1, rd + 2):
                for dz in range(-rd - 1, rd + 2):
                        gen_list.append(Vector2i(pcx + dx, pcz + dz))
                        if maxi(absi(dx), absi(dz)) <= rd:
                                mesh_list.append(Vector2i(pcx + dx, pcz + dz))
        var total := gen_list.size() + mesh_list.size()
        var done := 0
        for c in gen_list:
                world.gen_chunk(c.x, c.y)
                done += 1
                if done % 3 == 0:
                        load_bar.value = 100.0 * done / total
                        load_label.text = "در حال ساخت دنیا... %d%%" % int(100.0 * done / total)
                        await get_tree().process_frame
        for c in mesh_list:
                world.gen_chunk(c.x, c.y)
                world._mesh_one(c.x, c.y)
                done += 1
                if done % 3 == 0:
                        load_bar.value = 100.0 * done / total
                        load_label.text = "در حال ساخت دنیا... %d%%" % int(100.0 * done / total)
                        await get_tree().process_frame

        # spawn on real terrain surface (after chunks exist)
        if not saved_spawn:
                var best_spawn := Vector3(sx + 0.5, world.column_top(sx, sz) + 1.9, sz + 0.5)
                for r in range(0, 6):
                    var found := false
                    for dx in range(-r, r + 1):
                        for dz in range(-r, r + 1):
                            var tx := sx + dx * 3
                            var tz := sz + dz * 3
                            var top := world.column_top(tx, tz)
                            var gid: int = world.get_block(Vector3i(tx, top, tz))
                            if gid == Blocks.GRASS or gid == Blocks.SAND or gid == Blocks.SNOW:
                                best_spawn = Vector3(tx + 0.5, top + 1.9, tz + 0.5)
                                found = true
                                break
                        if found:
                            break
                    if found:
                        break
                spawn_pos = best_spawn

        # player
        player = PlayerCtl.new()
        player.world = world
        add_child(player)
        player.global_position = spawn_pos
        player.reset_look(look.x, look.y)
        if data.has("hp"):
                player.hp = int(data.hp)

        mobs = MobMgr.new()
        mobs.world = world
        mobs.player = player
        add_child(mobs)

        hud = GameHud.new()
        hud.main = self
        hud.player = player
        hud.world = world
        hud.mobs = mobs
        hud.sens = _last_sens
        add_child(hud)
        player.hp_changed.connect(func(h): hud.set_hp(h))
        player.died.connect(func():
                save_game()
                hud.show_death())
        hud.set_hp(player.hp)

        loading_layer.queue_free()
        loading_layer = null
        state = "playing"
        Sfx.play("click")


var _last_sens := 1.0


func note_sens(v: float) -> void:
        _last_sens = v


func respawn() -> void:
        if hud:
                hud.hide_death()
        if player:
                player.respawn(spawn_pos)


func back_to_menu() -> void:
        save_game()
        _clear_game()
        state = "menu"
        menu.refresh()
        menu.show_menu()


func _clear_game() -> void:
        if hud:
                hud.queue_free()
                hud = null
        if mobs:
                mobs.queue_free()
                mobs = null
        if player:
                player.queue_free()
                player = null
        if world:
                world.queue_free()
                world = null


func _build_loading_ui() -> void:
        loading_layer = CanvasLayer.new()
        add_child(loading_layer)
        var bg := ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = Color(0.03, 0.035, 0.07)
        loading_layer.add_child(bg)
        var v := VBoxContainer.new()
        v.set_anchors_preset(Control.PRESET_CENTER)
        v.offset_left = -260
        v.offset_top = -60
        v.offset_right = 260
        v.offset_bottom = 60
        v.add_theme_constant_override("separation", 24)
        loading_layer.add_child(v)
        load_label = Label.new()
        load_label.text = "در حال ساخت دنیا... 0%"
        load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        load_label.add_theme_font_override("font", load("res://assets/Vazirmatn-Bold.ttf"))
        load_label.add_theme_font_size_override("font_size", 30)
        v.add_child(load_label)
        load_bar = ProgressBar.new()
        load_bar.min_value = 0
        load_bar.max_value = 100
        load_bar.value = 0
        load_bar.show_percentage = false
        load_bar.custom_minimum_size = Vector2(520, 26)
        v.add_child(load_bar)
        var tip := Label.new()
        tip.text = "اولین بار ممکن است چند ثانیه طول بکشد — لطفاً صبر کنید"
        tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        tip.add_theme_font_override("font", load("res://assets/Vazirmatn-Regular.ttf"))
        tip.add_theme_font_size_override("font_size", 17)
        tip.add_theme_color_override("font_color", Color(0.62, 0.68, 0.62))
        v.add_child(tip)
