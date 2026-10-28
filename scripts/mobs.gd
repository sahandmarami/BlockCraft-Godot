class_name MobMgr extends Node3D
## Mobs: zombie (hostile at night) + pig/cow/sheep. Gravity moves the WHOLE
## root body, so animals always fall completely (fixes the old head-only bug).

const KINDS := {
        "zombie": {"hp": 10, "speed": 2.2, "hostile": true, "scale": 1.0,
                "body": Color8(42, 96, 143), "legs": Color8(46, 60, 128), "head": "zombie"},
        "pig": {"hp": 8, "speed": 1.3, "hostile": false, "scale": 0.75,
                "body": Color8(238, 164, 164), "legs": Color8(224, 148, 148), "head": "pig"},
        "cow": {"hp": 10, "speed": 1.2, "hostile": false, "scale": 0.9,
                "body": Color8(107, 74, 51), "legs": Color8(84, 58, 40), "head": "cow"},
        "sheep": {"hp": 8, "speed": 1.2, "hostile": false, "scale": 0.85,
                "body": Color8(232, 230, 227), "legs": Color8(214, 190, 166), "head": "sheep"},
}

var world: VoxelWorld
var player: PlayerCtl
var mobs: Array = []
var spawn_t := 0.0
var _box_cache := {}


func _ready() -> void:
        for kind in KINDS:
                _box_cache[kind] = _make_box_mesh(kind)


func _make_box_mesh(kind: String) -> BoxMesh:
        var bm := BoxMesh.new()
        bm.size = Vector3.ONE  # scaled per part
        var m := StandardMaterial3D.new()
        m.albedo_color = KINDS[kind].body
        m.roughness = 1.0
        m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
        bm.material = m
        return bm


func _part_mesh(kind: String, is_head: bool, size: Vector3) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = size
        var m := StandardMaterial3D.new()
        m.roughness = 1.0
        m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
        if is_head:
                m.albedo_texture = Tex.head_tex(KINDS[kind].head)
                m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        else:
                m.albedo_color = KINDS[kind].body
        bm.material = m
        mi.mesh = bm
        return mi


func _make_mob(kind: String, pos: Vector3) -> Dictionary:
        var k: Dictionary = KINDS[kind]
        var root := Node3D.new()  # origin at feet center — the WHOLE body moves
        root.position = pos
        var s: float = k.scale
        var leg_h := 0.62
        var body_h := 0.66
        var head_s := 0.5
        var mats: Array = []
        var legs: Array = []

        # legs (pivot at hip so they swing)
        for i in 4:
                var piv := Node3D.new()
                var px := -0.13 if i % 2 == 0 else 0.13
                var pz := -0.16 if i < 2 else 0.16
                piv.position = Vector3(px, leg_h, pz)
                var leg := _part_mesh(kind, false, Vector3(0.18, leg_h, 0.18))
                leg.position = Vector3(0, -leg_h / 2.0, 0)
                piv.add_child(leg)
                root.add_child(piv)
                legs.append(piv)
                mats.append(leg.mesh.material)

        # body
        var body := _part_mesh(kind, false, Vector3(0.46, body_h, 0.28))
        body.position = Vector3(0, leg_h + body_h / 2.0, 0)
        root.add_child(body)
        mats.append(body.mesh.material)

        # head
        var head := _part_mesh(kind, true, Vector3(head_s, head_s, head_s))
        head.position = Vector3(0, leg_h + body_h + head_s / 2.0, 0.02)
        root.add_child(head)
        mats.append(head.mesh.material)

        add_child(root)
        return {
                "root": root, "kind": kind, "hp": k.hp, "vy": 0.0, "dir": randf() * TAU,
                "walk_t": randf_range(1.0, 3.0), "idle": false, "anim": randf() * 10.0,
                "mats": mats, "base": [], "legs": legs, "flash": 0.0, "atk_cd": 0.0,
                "dying": 0.0, "wander_cd": 0.0,
        }


func _mob_base_colors(m: Dictionary) -> void:
        if m.base.is_empty():
                for mat in m.mats:
                        m.base.append(mat.albedo_color if mat.albedo_texture == null else Color(1, 1, 1))


func spawn_pass() -> void:
        if player == null or player.dead:
                return
        # despawn far
        var keep: Array = []
        for m in mobs:
                if m.dying > 0.0 or m.root.position.distance_to(player.global_position) < 72.0:
                        keep.append(m)
                else:
                        m.root.queue_free()
        mobs = keep
        var night := world.is_night()
        var want_z := 5 if night else 0
        var want_a := 4 if not night else 2
        var z_count := 0
        var a_count := 0
        for m in mobs:
                if KINDS[m.kind].hostile:
                        z_count += 1
                else:
                        a_count += 1
        var tries := 8
        while (z_count < want_z or a_count < want_a) and tries > 0:
                tries -= 1
                var ang := randf() * TAU
                var dist := randf_range(18.0, 38.0)
                var wx := int(player.global_position.x + cos(ang) * dist)
                var wz := int(player.global_position.z + sin(ang) * dist)
                var top := world.column_top(wx, wz)
                if top < 4:
                        continue
                var ground_id := world.get_block(Vector3i(wx, top, wz))
                if ground_id != Blocks.GRASS and ground_id != Blocks.SAND and ground_id != Blocks.SNOW:
                        continue
                var kind := ""
                if z_count < want_z and night:
                        kind = "zombie"
                elif a_count < want_a:
                        kind = ["pig", "cow", "sheep"][randi() % 3]
                else:
                        continue
                var m2 := _make_mob(kind, Vector3(wx + 0.5, top + 1.1, wz + 0.5))
                _mob_base_colors(m2)
                mobs.append(m2)
                if KINDS[kind].hostile:
                        z_count += 1
                else:
                        a_count += 1


func _physics_process(delta: float) -> void:
        if world == null or player == null:
                return
        spawn_t += delta
        if spawn_t > 3.0:
                spawn_t = 0.0
                spawn_pass()
        var night := world.is_night()
        var removed := false
        for m in mobs:
                if m.dying > 0.0:
                        _die_anim(m, delta)
                        continue
                var root: Node3D = m.root
                var to_player := player.global_position - root.position
                var dist := to_player.length()
                if dist > 70.0:
                        continue
                var k: Dictionary = KINDS[m.kind]
                var speed: float = k.speed
                var moving := false
                # AI
                if k.hostile and night and dist < 26.0 and not player.dead:
                        m.dir = atan2(to_player.x, to_player.z)
                        moving = dist > 1.2
                        m.atk_cd = maxf(m.atk_cd - delta, 0.0)
                        if dist < 1.5 and m.atk_cd <= 0.0:
                                m.atk_cd = 1.0
                                player.take_damage(2)
                else:
                        m.walk_t -= delta
                        if m.walk_t <= 0.0:
                                m.idle = randf() < 0.45
                                m.walk_t = randf_range(1.5, 4.5)
                                m.dir = randf() * TAU
                        moving = not m.idle
                # horizontal move with wall/hop handling
                if moving:
                        var vx := sin(m.dir) * speed
                        var vz := cos(m.dir) * speed
                        var nx := root.position.x + vx * delta
                        var nz := root.position.z + vz * delta
                        var feet := Vector3i(int(floorf(nx)), int(floorf(root.position.y + 0.2)), int(floorf(nz)))
                        var head_c := Vector3i(feet.x, feet.y + 1, feet.z)
                        if world.get_block(feet) != Blocks.AIR:
                                if world.get_block(head_c) == Blocks.AIR and world.get_block(Vector3i(feet.x, int(floorf(root.position.y + 1.2)), feet.z)) == Blocks.AIR:
                                        m.vy = 7.2  # hop one block
                                else:
                                        m.dir += PI * (0.5 + randf() * 0.5)  # turn around
                        else:
                                root.position.x = nx
                                root.position.z = nz
                # gravity moves the whole root (fix: full-body fall)
                m.vy = maxf(m.vy - 26.0 * delta, -40.0)
                root.position.y += m.vy * delta
                var g := world.ground_y(root.position.x, root.position.z, root.position.y + 0.5)
                if root.position.y <= g:
                        root.position.y = g
                        m.vy = 0.0
                # orientation + leg swing
                var yaw := atan2(sin(m.dir), cos(m.dir))
                root.rotation.y = lerp_angle(root.rotation.y, yaw, 8.0 * delta)
                if moving:
                        m.anim += delta * 9.0
                        for i in 4:
                                m.legs[i].rotation.x = sin(m.anim + (0.0 if i % 2 == 0 else PI)) * 0.55
                else:
                        for i in 4:
                                m.legs[i].rotation.x = lerpf(m.legs[i].rotation.x, 0.0, 10.0 * delta)
                # hurt flash decay
                if m.flash > 0.0:
                        m.flash = maxf(m.flash - delta * 4.0, 0.0)
                        var t: float = m.flash
                        for i in m.mats.size():
                                var mat = m.mats[i]
                                var bc: Color = m.base[i]
                                mat.albedo_color = bc.lerp(Color(1, 0.25, 0.25), t) if mat.albedo_texture == null else Color(1, 1 - t * 0.7, 1 - t * 0.7)
        if removed:
                pass


func _die_anim(m: Dictionary, delta: float) -> void:
        m.dying += delta
        var root: Node3D = m.root
        root.rotation.z = minf(m.dying * 5.0, PI / 2.0)
        var a := 1.0 - maxf((m.dying - 0.5) * 1.6, 0.0)
        for i in m.mats.size():
                var mat = m.mats[i]
                mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                if mat.albedo_texture == null:
                        mat.albedo_color = Color(m.base[i], a)
                else:
                        mat.albedo_color = Color(1, 1, 1, a)
        if m.dying > 1.15:
                root.queue_free()
                mobs.erase(m)


func hit_in_front(from: Vector3, dir: Vector3) -> bool:
        var best = null
        var best_d := 3.2
        for m in mobs:
                if m.dying > 0.0:
                        continue
                var to: Vector3 = m.root.position + Vector3(0, 0.8, 0) - from
                var d := to.length()
                if d < best_d and to.normalized().dot(dir) > 0.55:
                        best_d = d
                        best = m
        if best == null:
                return false
        best.hp -= 4
        best.flash = 1.0
        best.vy = 4.5
        var kb: Vector3 = (best.root.position - from)
        kb.y = 0.0
        if kb.length() > 0.01:
                best.dir = atan2(kb.x, kb.z)
                best.root.position += kb.normalized() * 0.6
        Sfx.play("mob_hurt", randf_range(0.9, 1.1))
        if best.hp <= 0 and best.dying <= 0.0:
                best.dying = 0.001
        return true


func clear_all() -> void:
        for m in mobs:
                m.root.queue_free()
        mobs.clear()
