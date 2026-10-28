class_name Mesher
## Builds one ArrayMesh per chunk with hidden-face culling.
## Culling is disabled on the material, so winding order is not critical.

# face: {d: Vector3i dir, v: Array[Vector3] 4 unit corners, s: shade}
const FACES = [
        {"d": Vector3i(0, 1, 0), "v": [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)], "s": 1.0},
        {"d": Vector3i(0, -1, 0), "v": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], "s": 0.5},
        {"d": Vector3i(1, 0, 0), "v": [Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)], "s": 0.72},
        {"d": Vector3i(-1, 0, 0), "v": [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)], "s": 0.72},
        {"d": Vector3i(0, 0, 1), "v": [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)], "s": 0.86},
        {"d": Vector3i(0, 0, -1), "v": [Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)], "s": 0.86},
]

const TILE_INSET = 0.004


static func build(w, cx: int, cz: int) -> ArrayMesh:
        var CS: int = w.CS
        var CH: int = w.CH
        var cells: PackedByteArray = w.get_cells(cx, cz)
        var ox := cx * CS
        var oz := cz * CS

        var verts := PackedVector3Array()
        var norms := PackedVector3Array()
        var uvs := PackedVector2Array()
        var cols := PackedColorArray()
        var idxs := PackedInt32Array()
        var ts := 1.0 / Tex.N

        for lx in CS:
                for lz in CS:
                        var col_base := (lx * CS + lz) * CH
                        for y in CH:
                                var id := cells[col_base + y]
                                if id == 0:
                                        continue
                                for f in 6:
                                        var face: Dictionary = FACES[f]
                                        var d: Vector3i = face.d
                                        # neighbor lookup (world handles borders / vertical bounds)
                                        var nb: int = w.get_block(Vector3i(ox + lx + d.x, y + d.y, oz + lz + d.z))
                                        if nb != 0:
                                                continue
                                        var tile := Blocks.face_tile(id, f)
                                        var tu := (tile % Tex.N) * ts
                                        var tv := (tile / Tex.N) * ts
                                        var shade: float = face.s
                                        # subtle per-column variation for organic feel
                                        if f == 0:
                                                shade *= 0.96 + 0.04 * float(((lx * 7 + lz * 13) % 5)) / 4.0
                                        var vi := verts.size()
                                        for i in 4:
                                                var p: Vector3 = face.v[i]
                                                verts.append(Vector3(lx + p.x, y + p.y, lz + p.z))
                                                norms.append(Vector3(d.x, d.y, d.z))
                                                var uu := 0.0
                                                var vv := 0.0
                                                match f:
                                                        0, 1:
                                                                uu = p.x
                                                                vv = p.z
                                                        2, 3:
                                                                uu = p.z
                                                                vv = 1.0 - p.y
                                                        _:
                                                                uu = p.x
                                                                vv = 1.0 - p.y
                                                var inset := TILE_INSET * ts
                                                uvs.append(Vector2(tu + inset + uu * (ts - 2.0 * inset), tv + inset + vv * (ts - 2.0 * inset)))
                                                cols.append(Color(shade, shade, shade))
                                        idxs.append_array([vi, vi + 1, vi + 2, vi, vi + 2, vi + 3])

        if verts.is_empty():
                return null
        var arrays := []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = verts
        arrays[Mesh.ARRAY_NORMAL] = norms
        arrays[Mesh.ARRAY_TEX_UV] = uvs
        arrays[Mesh.ARRAY_COLOR] = cols
        arrays[Mesh.ARRAY_INDEX] = idxs
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        return mesh


static func make_material() -> StandardMaterial3D:
        var m := StandardMaterial3D.new()
        m.albedo_texture = Tex.atlas()
        m.vertex_color_use_as_albedo = true
        m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
        m.cull_mode = BaseMaterial3D.CULL_DISABLED
        m.roughness = 1.0
        m.metallic = 0.0
        m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
        return m
