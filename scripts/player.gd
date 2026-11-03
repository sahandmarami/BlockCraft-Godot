class_name PlayerCtl extends Node3D
## First-person player with manual voxel AABB physics (no physics engine needed).

signal died
signal hp_changed(hp: int)
signal inv_changed
signal picked_up(text: String)

const HALF := Vector3(0.3, 0.9, 0.3)  # AABB half extents
const GRAV := 26.0
const JUMP_V := 8.6
const SPEED := 4.6
const REACH := 6.0
const STACK := 64
const SLOTS := 9

var world: VoxelWorld
var yaw_node: Node3D
var pitch_node: Node3D
var cam: Camera3D
var outline: MeshInstance3D

var vel := Vector3.ZERO
var hp := 20
var grounded := false
var prev_vy := 0.0
var joy := Vector2.ZERO  # set by HUD (-1..1), y = forward (up = forward)
var jump_req := false
var sens := 1.0
var hurt_cd := 0.0
var regen_t := 0.0
var no_dmg_t := 999.0
var look_touch := -1
var dead := false

# Minecraft-like inventory: counts per block id + hotbar slot order
var inv := {}                       # id -> count
var hotbar: Array = []              # 9 entries: block id or 0 (empty)
var hotbar_sel := 0


func _ready() -> void:
        yaw_node = Node3D.new()
        add_child(yaw_node)
        pitch_node = Node3D.new()
        yaw_node.add_child(pitch_node)
        cam = Camera3D.new()
        cam.fov = 74.0
        cam.near = 0.08
        cam.far = 300.0
        cam.current = true
        pitch_node.add_child(cam)
        pitch_node.position = Vector3(0, 0.72, 0)  # eye height above AABB center

        # block outline
        outline = MeshInstance3D.new()
        var im := ImmediateMesh.new()
        var b := 0.002
        var c0 := Vector3(-0.5 - b, -0.5 - b, -0.5 - b)
        var c1 := Vector3(0.5 + b, 0.5 + b, 0.5 + b)
        var pts := [
                [c0, Vector3(c1.x, c0.y, c0.z)], [c0, Vector3(c0.x, c1.y, c0.z)], [c0, Vector3(c0.x, c0.y, c1.z)],
                [c1, Vector3(c0.x, c1.y, c1.z)], [c1, Vector3(c1.x, c0.y, c1.z)], [c1, Vector3(c1.x, c1.y, c0.z)],
                [Vector3(c1.x, c0.y, c0.z), Vector3(c1.x, c1.y, c0.z)], [Vector3(c1.x, c0.y, c0.z), Vector3(c1.x, c0.y, c1.z)],
                [Vector3(c0.x, c1.y, c0.z), Vector3(c1.x, c1.y, c0.z)], [Vector3(c0.x, c1.y, c0.z), Vector3(c0.x, c1.y, c1.z)],
                [Vector3(c0.x, c0.y, c1.z), Vector3(c1.x, c0.y, c1.z)], [Vector3(c0.x, c0.y, c1.z), Vector3(c1.x, c0.y, c1.z)],
                [Vector3(c1.x, c1.y, c1.z), Vector3(c1.x, c1.y, c0.z)], [Vector3(c1.x, c1.y, c1.z), Vector3(c0.x, c1.y, c1.z)],
        ]
        for seg in pts:
                im.surface_begin(Mesh.PRIMITIVE_LINES)
                im.surface_add_vertex(seg[0])
                im.surface_add_vertex(seg[1])
                im.surface_end()
        outline.mesh = im
        var om := StandardMaterial3D.new()
        om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        om.albedo_color = Color(0, 0, 0, 0.85)
        om.no_depth_test = true
        om.vertex_color_use_as_albedo = false
        outline.material_override = om
        outline.visible = false
        add_child(outline)

        # starter kit so the player can build right away
        hotbar.resize(SLOTS)
        for i in SLOTS:
                hotbar[i] = 0
        give(Blocks.DIRT, 32)
        give(Blocks.PLANKS, 32)
        give(Blocks.LOG, 16)
        inv_changed.emit()


func eye_pos() -> Vector3:
        return global_position + Vector3(0, 0.72, 0)


func look_dir() -> Vector3:
        return -pitch_node.global_transform.basis.z


# ---------------- inventory (Minecraft-like) ----------------

## Add a drop; returns true if stored.
func give(id: int, n: int = 1) -> bool:
        if id == Blocks.AIR or n <= 0:
                return false
        inv[id] = int(inv.get(id, 0)) + n
        if not hotbar.has(id):
                for i in SLOTS:
                        if hotbar[i] == 0:
                                hotbar[i] = id
                                break
        inv_changed.emit()
        return true


## Consume one block of id when placing. Returns true if consumed.
func consume(id: int) -> bool:
        if int(inv.get(id, 0)) <= 0:
                return false
        inv[id] = int(inv[id]) - 1
        if inv[id] <= 0:
                inv.erase(id)
                for i in SLOTS:
                        if hotbar[i] == id:
                                hotbar[i] = 0
        inv_changed.emit()
        return true


func count_of(id: int) -> int:
        return int(inv.get(id, 0))


func slot_id(i: int) -> int:
        return hotbar[i]


func selected_id() -> int:
        return hotbar[hotbar_sel]


func inventory_data() -> Dictionary:
        return {"inv": inv.duplicate(), "hotbar": hotbar.duplicate(), "sel": hotbar_sel}


func load_inventory(d: Dictionary) -> void:
        var iv: Dictionary = d.get("inv", {})
        inv.clear()
        for k in iv:
                inv[int(k)] = int(iv[k])
        var hb: Array = d.get("hotbar", [])
        hotbar.resize(SLOTS)
        for i in SLOTS:
                hotbar[i] = int(hb[i]) if i < hb.size() else 0
        hotbar_sel = clampi(int(d.get("sel", 0)), 0, SLOTS - 1)
        inv_changed.emit()


# ---------------- actions ----------------

func do_break() -> void:
        var hit := target_hit()
        if hit.is_empty():
                return
        if not Blocks.breakable(hit.id):
                return
        world.set_block(hit.pos, Blocks.AIR)
        Sfx.play("break", randf_range(0.9, 1.1))
        # Minecraft mechanic: the block is collected into the inventory
        var drop := Blocks.drop_of(hit.id)
        if drop != Blocks.AIR and give(drop, 1):
                Sfx.play("pickup", randf_range(0.95, 1.1))
                picked_up.emit(str(Blocks.NAMES.get(drop, "بلوک")))


func do_place(id: int) -> void:
        if id == Blocks.AIR:
                return
        if not consume(id):
                return  # nothing left in inventory
        var hit := target_hit()
        if hit.is_empty():
                consume_undo(id)
                return
        var cell: Vector3i = hit.pos + hit.n
        if world.get_block(cell) != Blocks.AIR:
                consume_undo(id)
                return
        # don't place inside player AABB
        var cc := Vector3(cell) + Vector3(0.5, 0.5, 0.5)
        var aabb_min := global_position - HALF
        var aabb_max := global_position + HALF
        if cc.x + 0.5 > aabb_min.x and cc.x - 0.5 < aabb_max.x \
                        and cc.y + 0.5 > aabb_min.y and cc.y - 0.5 < aabb_max.y \
                        and cc.z + 0.5 > aabb_min.z and cc.z - 0.5 < aabb_max.z:
                consume_undo(id)
                return
        world.set_block(cell, id)
        Sfx.play("place", randf_range(0.95, 1.05))


## give back the block if placement failed after consuming
func consume_undo(id: int) -> void:
        give(id, 1)


func take_damage(dmg: int, fall := false) -> void:
        if dead:
                return
        if hurt_cd > 0.0 and not fall:
                return
        if not fall:
                hurt_cd = 0.5
        hp = maxi(hp - dmg, 0)
        no_dmg_t = 0.0
        hp_changed.emit(hp)
        Sfx.play("hurt", randf_range(0.95, 1.1))
        if hp <= 0:
                dead = true
                died.emit()


func respawn(at: Vector3) -> void:
        global_position = at
        vel = Vector3.ZERO
        hp = 20
        dead = false
        no_dmg_t = 999.0
        hp_changed.emit(hp)


func reset_look(yaw_deg: float, pitch_deg: float) -> void:
        yaw_node.rotation.y = deg_to_rad(yaw_deg)
        pitch_node.rotation.x = clampf(deg_to_rad(pitch_deg), deg_to_rad(-85), deg_to_rad(85))


func get_look() -> Vector2:
        return Vector2(rad_to_deg(yaw_node.rotation.y), rad_to_deg(pitch_node.rotation.x))


## called by HUD look drag
func apply_look(dx: float, dy: float) -> void:
        yaw_node.rotation.y -= dx * 0.0032 * sens
        pitch_node.rotation.x = clampf(pitch_node.rotation.x - dy * 0.0032 * sens, deg_to_rad(-85), deg_to_rad(85))


func _physics_process(delta: float) -> void:
        if world == null or dead:
                return
        var keys_x := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
        var keys_y := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
        var move_in := Vector2(joy.x, joy.y)
        if move_in.length() < 0.01:
                move_in = Vector2(keys_x, keys_y)
        move_in = move_in.limit_length(1.0)

        var fwd := -yaw_node.global_transform.basis.z
        var right := yaw_node.global_transform.basis.x
        var wish := (right * move_in.x + fwd * move_in.y) * SPEED
        wish.y = 0.0
        vel.x = move_toward(vel.x, wish.x, 42.0 * delta)
        vel.z = move_toward(vel.z, wish.z, 42.0 * delta)

        prev_vy = vel.y
        vel.y = maxf(vel.y - GRAV * delta, -42.0)
        if jump_req and grounded:
                vel.y = JUMP_V
                jump_req = false
        grounded = false
        _move_axis(Vector3(vel.x * delta, 0, 0))
        _move_axis(Vector3(0, 0, vel.z * delta))
        _move_axis(Vector3(0, vel.y * delta, 0))

        # fall damage
        if grounded and prev_vy < -13.5:
                var dmg := int((-prev_vy - 13.5) * 1.1)
                if dmg > 0:
                        take_damage(dmg, true)

        # regen
        no_dmg_t += delta
        hurt_cd = maxf(hurt_cd - delta, 0.0)
        if hp > 0 and hp < 20 and no_dmg_t > 7.0:
                regen_t += delta
                if regen_t > 2.6:
                        regen_t = 0.0
                        hp = mini(hp + 1, 20)
                        hp_changed.emit(hp)

        # void
        if global_position.y < -14:
                take_damage(99, true)

        _update_outline()


func _move_axis(step: Vector3) -> void:
        if step == Vector3.ZERO:
                return
        var target := global_position + step
        if world.box_free(target, HALF):
                global_position = target
                if step.y < 0:
                        pass
                return
        # binary search for contact point
        var lo := 0.0
        var hi := 1.0
        for i in 7:
                var mid := (lo + hi) * 0.5
                if world.box_free(global_position + step * mid, HALF):
                        lo = mid
                else:
                        hi = mid
        global_position += step * lo
        # snap flush to the blocking face
        var snap := global_position + step * hi * 0.98
        if world.box_free(snap, HALF):
                global_position = snap
        if step.y < 0.0:
                grounded = true
                if prev_vy < -13.5:
                        pass
                vel.y = 0.0
        elif step.y > 0.0:
                vel.y = 0.0
        else:
                vel.x *= 0.0 if absf(step.x) > 0 else 1.0
                vel.z *= 0.0 if absf(step.z) > 0 else 1.0


func _update_outline() -> void:
        var hit := world.raycast(eye_pos(), look_dir(), REACH)
        if hit.is_empty():
                outline.visible = false
                return
        outline.visible = true
        outline.global_position = Vector3(hit.pos) + Vector3(0.5, 0.5, 0.5)


func target_hit() -> Dictionary:
        return world.raycast(eye_pos(), look_dir(), REACH)
