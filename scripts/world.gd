class_name VoxelWorld extends Node3D
## Chunked voxel world: generation, streaming, editing, raycast, day cycle.

const CS = 16
const CH = 64
const GRAV_CHECK = 999

var seed_val := 12345
var rd := 3  # render distance in chunks
var tod := 0.3  # time of day 0..1 (0.25 = noon-ish, 0.75 = midnight-ish)
var cells := {}   # "cx,cz" -> PackedByteArray (CS*CS*CH)
var meshes := {}  # "cx,cz" -> MeshInstance3D
var dirty := {}   # set of "cx,cz"
var mods := {}    # "cx,cz" -> {cell_index: id}  (saved edits)
var material: StandardMaterial3D
var noise_h: FastNoiseLite
var noise_d: FastNoiseLite
var noise_b: FastNoiseLite
var player_pos := Vector3.ZERO


func _init() -> void:
        material = Mesher.make_material()


func setup_noise(p_seed: int) -> void:
        seed_val = p_seed
        noise_h = FastNoiseLite.new()
        noise_h.seed = p_seed
        noise_h.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
        noise_h.frequency = 1.0 / 42.0
        noise_h.fractal_octaves = 4
        noise_d = FastNoiseLite.new()
        noise_d.seed = p_seed + 777
        noise_d.noise_type = FastNoiseLite.TYPE_SIMPLEX
        noise_d.frequency = 1.0 / 14.0
        noise_d.fractal_octaves = 2
        noise_b = FastNoiseLite.new()
        noise_b.seed = p_seed + 4242
        noise_b.noise_type = FastNoiseLite.TYPE_CELLULAR
        noise_b.frequency = 1.0 / 26.0


static func key(cx: int, cz: int) -> String:
        return str(cx) + "," + str(cz)


static func idx_of(lx: int, lz: int, y: int) -> int:
        return (lx * CS + lz) * CH + y


func has_cells(cx: int, cz: int) -> bool:
        return cells.has(key(cx, cz))


func get_cells(cx: int, cz: int) -> PackedByteArray:
        return cells[key(cx, cz)]


func gen_chunk(cx: int, cz: int) -> void:
        var k := key(cx, cz)
        if cells.has(k):
                return
        var arr := PackedByteArray()
        arr.resize(CS * CS * CH)
        var ox := cx * CS
        var oz := cz * CS
        # heights per column first
        var heights := {}
        for lx in CS:
                for lz in CS:
                        var wx := ox + lx
                        var wz := oz + lz
                        var h := int(20.0 + noise_h.get_noise_2d(wx, wz) * 16.0 + noise_d.get_noise_2d(wx, wz) * 3.5)
                        h = clampi(h, 4, CH - 14)
                        heights[Vector2i(lx, lz)] = h
        # trees decided deterministically per world column
        var tree_cols := {}
        for lx in range(2, CS - 2):
                for lz in range(2, CS - 2):
                        var wx := ox + lx
                        var wz := oz + lz
                        var r := fposmod(sin(float(wx * 127 + wz * 311) * 12.9898) * 43758.5453, 1.0)
                        if r < 0.012:
                                var h: int = heights[Vector2i(lx, lz)]
                                if h > 6 and h < CH - 14:
                                        tree_cols[Vector2i(lx, lz)] = h
        for lx in CS:
                for lz in CS:
                        var wx := ox + lx
                        var wz := oz + lz
                        var h: int = heights[Vector2i(lx, lz)]
                        var biome := noise_b.get_noise_2d(wx, wz)
                        var sandy := biome > 0.55 and h <= 22
                        var snowy := h >= 38
                        var base := (lx * CS + lz) * CH
                        for y in CH:
                                var id := 0
                                if y == 0:
                                        id = Blocks.BEDROCK
                                elif y < h - 3:
                                        id = Blocks.STONE
                                elif y < h:
                                        id = Blocks.DIRT if not sandy else Blocks.SAND
                                elif y == h:
                                        if sandy:
                                                id = Blocks.SAND
                                        elif snowy:
                                                id = Blocks.SNOW
                                        else:
                                                id = Blocks.GRASS
                                arr[base + y] = id
                        # tree trunk + leaves
                        if tree_cols.has(Vector2i(lx, lz)) and arr[base + h] == Blocks.GRASS:
                                var th := 4 + int(fposmod(float(wx * 31 + wz * 17), 2.0))
                                for ty in range(1, th + 1):
                                        if h + ty < CH:
                                                arr[base + h + ty] = Blocks.LOG
                                # canopy
                                for dy in range(th - 2, th + 2):
                                        var rad := 2 if dy < th else 1
                                        for dx in range(-rad, rad + 1):
                                                for dz in range(-rad, rad + 1):
                                                        if absi(dx) == rad and absi(dz) == rad and rad == 2:
                                                                continue
                                                        var ax := lx + dx
                                                        var az := lz + dz
                                                        var ay := h + dy + 1
                                                        if ax < 0 or ax >= CS or az < 0 or az >= CS or ay >= CH:
                                                                continue
                                                        var ai := idx_of(ax, az, ay)
                                                        if arr[ai] == 0:
                                                                arr[ai] = Blocks.LEAVES
        # apply saved mods
        if mods.has(k):
                var m: Dictionary = mods[k]
                for i in m:
                        arr[i] = m[i]
        cells[k] = arr


func get_block(c: Vector3i) -> int:
        if c.y < 0:
                return Blocks.BEDROCK
        if c.y >= CH:
                return Blocks.AIR
        var lx := ((c.x % CS) + CS) % CS
        var lz := ((c.z % CS) + CS) % CS
        var cx := (c.x - lx) / CS
        var cz := (c.z - lz) / CS
        var k := key(cx, cz)
        if not cells.has(k):
                return Blocks.AIR
        return cells[k][idx_of(lx, lz, c.y)]


func set_block(c: Vector3i, id: int) -> void:
        if c.y < 1 or c.y >= CH:
                return
        var lx := ((c.x % CS) + CS) % CS
        var lz := ((c.z % CS) + CS) % CS
        var cx := (c.x - lx) / CS
        var cz := (c.z - lz) / CS
        var k := key(cx, cz)
        if not cells.has(k):
                return
        var i := idx_of(lx, lz, c.y)
        cells[k][i] = id
        if not mods.has(k):
                mods[k] = {}
        mods[k][i] = id
        dirty[k] = true
        # neighbors on borders need remesh too
        if lx == 0:
                dirty[key(cx - 1, cz)] = true
        if lx == CS - 1:
                dirty[key(cx + 1, cz)] = true
        if lz == 0:
                dirty[key(cx, cz - 1)] = true
        if lz == CS - 1:
                dirty[key(cx, cz + 1)] = true
        flush_dirty()


func flush_dirty() -> void:
        for k in dirty.keys():
                if meshes.has(k):
                        var p: Array = _parse_key(k)
                        _mesh_one(p[0], p[1])
        dirty.clear()


func _parse_key(k: String) -> Array:
        var parts := k.split(",")
        return [int(parts[0]), int(parts[1])]


func _mesh_one(cx: int, cz: int) -> void:
        var k := key(cx, cz)
        var mesh := Mesher.build(self, cx, cz)
        var mi: MeshInstance3D = null
        if meshes.has(k):
                mi = meshes[k]
                if mesh == null:
                        mi.queue_free()
                        meshes.erase(k)
                        return
                mi.mesh = mesh
        else:
                if mesh == null:
                        return
                mi = MeshInstance3D.new()
                mi.mesh = mesh
                mi.material_override = material
                mi.position = Vector3(cx * CS, 0, cz * CS)
                add_child(mi)
                meshes[k] = mi


func neighbors_ready(cx: int, cz: int) -> bool:
        return has_cells(cx + 1, cz) and has_cells(cx - 1, cz) and has_cells(cx, cz + 1) and has_cells(cx, cz - 1)


## Continuous generation / meshing budget per frame. Returns true if did work.
func stream_around(pos: Vector3) -> bool:
        var pcx := floori(pos.x / float(CS))
        var pcz := floori(pos.z / float(CS))
        var did := false
        # generate ring rd+1
        for r in range(0, rd + 2):
                var best_d := 999999
                var best := Vector2i(9999, 9999)
                for dx in range(-r, r + 1):
                        for dz in range(-r, r + 1):
                                if maxi(absi(dx), absi(dz)) != r:
                                        continue
                                var cx := pcx + dx
                                var cz := pcz + dz
                                if not cells.has(key(cx, cz)):
                                        var d := dx * dx + dz * dz
                                        if d < best_d:
                                                best_d = d
                                                best = Vector2i(cx, cz)
                if best.x != 9999:
                        gen_chunk(best.x, best.y)
                        did = true
                        break  # 1 chunk gen per frame (pregen() does the initial burst)
        # mesh within rd
        for r in range(0, rd + 1):
                var best_d := 999999
                var best := Vector2i(9999, 9999)
                for dx in range(-r, r + 1):
                        for dz in range(-r, r + 1):
                                if maxi(absi(dx), absi(dz)) != r:
                                        continue
                                var cx := pcx + dx
                                var cz := pcz + dz
                                var k := key(cx, cz)
                                if cells.has(k) and not meshes.has(k) and neighbors_ready(cx, cz):
                                        var d := dx * dx + dz * dz
                                        if d < best_d:
                                                best_d = d
                                                best = Vector2i(cx, cz)
                if best.x != 9999:
                        _mesh_one(best.x, best.y)
                        did = true
                        break
        # unload far chunks
        if Engine.get_process_frames() % 60 == 0:
                var keys := cells.keys()
                for k in keys:
                        var p := _parse_key(k)
                        if maxi(absi(p[0] - pcx), absi(p[1] - pcz)) > rd + 3:
                                cells.erase(k)
                                if meshes.has(k):
                                        meshes[k].queue_free()
                                        meshes.erase(k)
        return did


func column_top(wx: int, wz: int) -> int:
        var c := Vector3i(wx, CH - 1, wz)
        while c.y > 0:
                var b := get_block(c)
                if b != Blocks.AIR and b != Blocks.LEAVES:
                        return c.y
                c.y -= 1
        return 0


## Ground height (top surface y) for mobs below a starting y.
func ground_y(wx: float, wz: float, from_y: float) -> float:
        var x := floori(wx)
        var z := floori(wz)
        var y := clampi(floori(from_y), 0, CH - 1)
        while y > 0 and get_block(Vector3i(x, y, z)) == Blocks.AIR:
                y -= 1
        return float(y) + 1.0


func box_free(center: Vector3, half: Vector3) -> bool:
        var mn := center - half
        var mx := center + half
        var x0 := floori(mn.x)
        var x1 := floori(mx.x - 0.001)
        var y0 := floori(mn.y)
        var y1 := floori(mx.y - 0.001)
        var z0 := floori(mn.z)
        var z1 := floori(mx.z - 0.001)
        for x in range(x0, x1 + 1):
                for y in range(maxi(y0, 0), mini(y1, CH - 1) + 1):
                        for z in range(z0, z1 + 1):
                                if get_block(Vector3i(x, y, z)) != Blocks.AIR:
                                        return false
        return true


## Voxel DDA raycast. Returns {} or {pos: Vector3i, n: Vector3i}
func raycast(from: Vector3, dir: Vector3, max_d: float) -> Dictionary:
        var x := floori(from.x)
        var y := floori(from.y)
        var z := floori(from.z)
        var sx := 1 if dir.x > 0.0 else -1
        var sy := 1 if dir.y > 0.0 else -1
        var sz := 1 if dir.z > 0.0 else -1
        var tdx := 999999.0 if absf(dir.x) < 1e-9 else absf(1.0 / dir.x)
        var tdy := 999999.0 if absf(dir.y) < 1e-9 else absf(1.0 / dir.y)
        var tdz := 999999.0 if absf(dir.z) < 1e-9 else absf(1.0 / dir.z)
        var tmx := 999999.0 if absf(dir.x) < 1e-9 else ((float(x) + (1.0 if sx > 0 else 0.0)) - from.x) / dir.x
        var tmy := 999999.0 if absf(dir.y) < 1e-9 else ((float(y) + (1.0 if sy > 0 else 0.0)) - from.y) / dir.y
        var tmz := 999999.0 if absf(dir.z) < 1e-9 else ((float(z) + (1.0 if sz > 0 else 0.0)) - from.z) / dir.z
        var n := Vector3i.ZERO
        for i in 160:
                var t := 0.0
                if tmx < tmy and tmx < tmz:
                        x += sx
                        t = tmx
                        tmx += tdx
                        n = Vector3i(-sx, 0, 0)
                elif tmy < tmz:
                        y += sy
                        t = tmy
                        tmy += tdy
                        n = Vector3i(0, -sy, 0)
                else:
                        z += sz
                        t = tmz
                        tmz += tdz
                        n = Vector3i(0, 0, -sz)
                if t > max_d:
                        return {}
                var c := Vector3i(x, y, z)
                var b := get_block(c)
                if b != Blocks.AIR:
                        return {"pos": c, "n": n, "id": b}
        return {}


func is_night() -> bool:
        return tod > 0.55 and tod < 0.97


func sun_factor() -> float:
        # 1 = full day, 0 = deep night
        if tod < 0.5:
                return 1.0
        elif tod < 0.58:
                return 1.0 - (tod - 0.5) / 0.08
        elif tod < 0.92:
                return 0.0
        else:
                return (tod - 0.92) / 0.08
