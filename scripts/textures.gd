class_name Tex
## All textures are generated procedurally at startup (deterministic).
## Atlas: 8x8 tiles of 32 px = 256x256.

const TILE = 32
const N = 8
const ATLAS_SIZE = TILE * N

static var _atlas: ImageTexture = null
static var _heads := {}
static var _hearts := {}
static var _clouds: ImageTexture = null


static func atlas() -> ImageTexture:
        if _atlas == null:
                _build_atlas()
        return _atlas


static func head_tex(kind: String) -> ImageTexture:
        if _heads.is_empty():
                _build_heads()
        return _heads[kind]


static func heart(full: bool) -> ImageTexture:
        if _hearts.is_empty():
                _build_hearts()
        return _hearts["full" if full else "empty"]


static func cloud_tex() -> ImageTexture:
        if _clouds == null:
                var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
                var rng := RandomNumberGenerator.new()
                rng.seed = 777001
                for i in 110:
                        var cx := rng.randf_range(0.0, 256.0)
                        var cy := rng.randf_range(0.0, 256.0)
                        var rx := rng.randf_range(14.0, 34.0)
                        var ry := rx * rng.randf_range(0.45, 0.7)
                        var a := rng.randf_range(0.35, 0.7)
                        var col := Color(1, 1, 1, a)
                        for y in range(int(cy - ry), int(cy + ry) + 1):
                                for x in range(int(cx - rx), int(cx + rx) + 1):
                                        var dx := (x - cx) / rx
                                        var dy := (y - cy) / ry
                                        if dx * dx + dy * dy <= 1.0:
                                                var xx := posmod(x, 256)
                                                var yy := posmod(y, 256)
                                                var old := img.get_pixel(xx, yy)
                                                img.set_pixel(xx, yy, Color(1, 1, 1, maxf(old.a, a)))
                img.generate_mipmaps()
                _clouds = ImageTexture.create_from_image(img)
        return _clouds


static func gradient_tex() -> ImageTexture:
        var img := Image.create(8, 128, false, Image.FORMAT_RGBA8)
        for y in 128:
                var t := float(y) / 127.0
                var c := Color(0.055, 0.07, 0.16).lerp(Color(0.01, 0.015, 0.05), t)
                for x in 8:
                        img.set_pixel(x, y, c)
        return ImageTexture.create_from_image(img)


static func _tile_origin(t: int) -> Vector2i:
        return Vector2i((t % N) * TILE, (t / N) * TILE)


static func _noise_rect(img: Image, t: int, base: Color, spread: int, rng: RandomNumberGenerator) -> void:
        var o := _tile_origin(t)
        for y in TILE:
                for x in TILE:
                        var d := int(rng.randf_range(-spread, spread))
                        var c := Color(
                                clampf(base.r + d / 255.0, 0.0, 1.0),
                                clampf(base.g + d / 255.0, 0.0, 1.0),
                                clampf(base.b + d / 255.0, 0.0, 1.0))
                        img.set_pixel(o.x + x, o.y + y, c)


static func _px(img: Image, t: int, x: int, y: int, c: Color) -> void:
        var o := _tile_origin(t)
        if x >= 0 and x < TILE and y >= 0 and y < TILE:
                img.set_pixel(o.x + x, o.y + y, c)


static func _blob(img: Image, t: int, cx: int, cy: int, rx: int, ry: int, c: Color, rng: RandomNumberGenerator) -> void:
        for y in range(cy - ry, cy + ry + 1):
                for x in range(cx - rx, cx + rx + 1):
                        var dx := float(x - cx) / maxf(rx, 0.5)
                        var dy := float(y - cy) / maxf(ry, 0.5)
                        if dx * dx + dy * dy <= 1.0:
                                var v := rng.randi_range(-8, 8)
                                _px(img, t, x, y, Color(clampf(c.r8 + v, 0, 255) / 255.0, clampf(c.g8 + v, 0, 255) / 255.0, clampf(c.b8 + v, 0, 255) / 255.0))


static func _shade(c: Color, d: int) -> Color:
        return Color8(clampi(c.r8 + d, 0, 255), clampi(c.g8 + d, 0, 255), clampi(c.b8 + d, 0, 255))


static func _build_atlas() -> void:
        var img := Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
        var rng := RandomNumberGenerator.new()
        rng.seed = 20250101
        var grass := Color8(110, 178, 56)
        var dirt := Color8(134, 96, 67)
        var stone := Color8(132, 132, 134)
        var sand := Color8(224, 212, 156)
        var wood := Color8(112, 88, 52)
        var leaf := Color8(58, 134, 38)
        var plank := Color8(172, 138, 84)
        var brick := Color8(158, 90, 70)

        # ---- 0 grass top: two-tone clumps + blades ----
        _noise_rect(img, 0, grass, 10, rng)
        for i in 42:
                _blob(img, 0, rng.randi_range(1, 30), rng.randi_range(1, 30), rng.randi_range(2, 4), rng.randi_range(2, 4), _shade(grass, rng.randi_range(-26, -10)), rng)
        for i in 42:
                _blob(img, 0, rng.randi_range(1, 30), rng.randi_range(1, 30), rng.randi_range(1, 3), rng.randi_range(1, 3), _shade(grass, rng.randi_range(8, 24)), rng)
        for i in 30:  # bright blades
                var bx := rng.randi_range(0, 31)
                var by := rng.randi_range(1, 31)
                _px(img, 0, bx, by, Color8(146, 208, 84))
                _px(img, 0, bx, by - 1, Color8(126, 194, 68))

        # ---- 1 grass side: dirt with jagged green cap + fringe + hanging blades ----
        _noise_rect(img, 1, dirt, 9, rng)
        for i in 16:
                _blob(img, 1, rng.randi_range(1, 30), rng.randi_range(14, 30), rng.randi_range(2, 4), rng.randi_range(2, 3), _shade(dirt, -16), rng)
        var cap := [9, 8, 10, 7, 9, 11, 8, 6, 9, 8, 10, 9, 7, 10, 8, 9, 11, 8, 7, 9, 10, 8, 9, 11, 8, 9, 7, 10, 9, 8, 9, 8]
        for x in TILE:
                var h: int = cap[x]
                for y in h:
                        var g := Color8(clampi(grass.r8 + rng.randi_range(-14, 14), 0, 255), clampi(grass.g8 + rng.randi_range(-14, 14), 0, 255), clampi(grass.b8 + rng.randi_range(-14, 6), 0, 255))
                        _px(img, 1, x, y, g)
                _px(img, 1, x, h, Color8(74, 118, 34))  # dark fringe line
                if x % 5 == rng.randi_range(0, 2):  # hanging blades
                        _px(img, 1, x, h + 1, Color8(84, 132, 38))
                if x % 7 == 0:
                        _px(img, 1, x, h + 1, Color8(74, 118, 34))
                        _px(img, 1, x, h + 2, Color8(64, 108, 30))

        # ---- 2 dirt: pebbles ----
        _noise_rect(img, 2, dirt, 9, rng)
        for i in 20:
                _blob(img, 2, rng.randi_range(1, 30), rng.randi_range(1, 30), rng.randi_range(1, 3), rng.randi_range(1, 3), _shade(dirt, rng.randi_range(-22, -8)), rng)
        for i in 12:
                _blob(img, 2, rng.randi_range(1, 30), rng.randi_range(1, 30), rng.randi_range(1, 2), rng.randi_range(1, 2), _shade(dirt, rng.randi_range(8, 20)), rng)

        # ---- 3 stone: blotches + cracks ----
        _noise_rect(img, 3, stone, 7, rng)
        for i in 18:
                _blob(img, 3, rng.randi_range(1, 30), rng.randi_range(1, 30), rng.randi_range(3, 6), rng.randi_range(2, 5), _shade(stone, rng.randi_range(-14, 12)), rng)
        for i in 5:  # cracks: random-walk lines
                var cx := rng.randi_range(2, 29)
                var cy := rng.randi_range(2, 29)
                for j in rng.randi_range(6, 12):
                        _px(img, 3, cx, cy, Color8(98, 98, 100))
                        cx += [-1, 0, 1][rng.randi_range(0, 2)]
                        cy += 1
                        if cx < 0 or cx > 31 or cy > 31:
                                break

        # ---- 4 cobble: rounded stones with dark mortar ----
        _noise_rect(img, 4, stone, 8, rng)
        for y in TILE:
                for x in TILE:
                        var row := y / 8
                        var col := (x + (row % 2) * 4) / 8
                        var sx := (x + (row % 2) * 4) % 8
                        var sy := y % 8
                        var edge: bool = sx < 2 or sy < 2
                        if edge:
                                _px(img, 4, x, y, Color8(92, 92, 94))
        for i in 22:
                _blob(img, 4, rng.randi_range(1, 30), rng.randi_range(1, 30), rng.randi_range(1, 2), rng.randi_range(1, 2), _shade(stone, rng.randi_range(-18, 16)), rng)

        # ---- 5 sand: speckles + ripples ----
        _noise_rect(img, 5, sand, 7, rng)
        for i in 40:
                _px(img, 5, rng.randi_range(0, 31), rng.randi_range(0, 31), Color8(198, 184, 128))
        for i in 24:
                _px(img, 5, rng.randi_range(0, 31), rng.randi_range(0, 31), Color8(242, 232, 184))
        for y in range(3, 32, 7):
                for x in 32:
                        if (x + y) % 9 != 0:
                                _px(img, 5, x, y, _shade(sand, -6))

        # ---- 6 log side: bark streaks + knot ----
        _noise_rect(img, 6, wood, 7, rng)
        for x in [2, 7, 12, 16, 21, 26, 30]:
                for y in TILE:
                        _px(img, 6, x, y, _shade(wood, -20))
                        _px(img, 6, (x + 1) % TILE, y, _shade(wood, -10))
        for y in TILE:
                for x in [5, 19, 24]:
                        if rng.randi_range(0, 4) < 3:
                                _px(img, 6, x, y, _shade(wood, 10))
        _blob(img, 6, 15, 16, 3, 4, _shade(wood, -26), rng)
        _blob(img, 6, 15, 16, 1, 2, _shade(wood, 14), rng)

        # ---- 7 log top: rings + bark border ----
        _noise_rect(img, 7, wood, 6, rng)
        for y in TILE:
                for x in TILE:
                        var d := Vector2(x - 15.5, y - 15.5).length()
                        if d > 14.0:
                                _px(img, 7, x, y, _shade(wood, -24))
                        elif absf(d - 11.5) < 1.1:
                                _px(img, 7, x, y, Color8(140, 110, 64))
                        elif absf(d - 8.5) < 1.0:
                                _px(img, 7, x, y, Color8(128, 100, 58))
                        elif absf(d - 5.0) < 0.9:
                                _px(img, 7, x, y, Color8(140, 110, 64))
                        elif d <= 1.4:
                                _px(img, 7, x, y, Color8(104, 80, 46))
                        else:
                                _px(img, 7, x, y, _shade(Color8(176, 142, 88), rng.randi_range(-8, 8)))

        # ---- 8 leaves: multi-tone + holes ----
        _noise_rect(img, 8, leaf, 13, rng)
        for i in 40:
                _blob(img, 8, rng.randi_range(1, 30), rng.randi_range(1, 30), rng.randi_range(2, 4), rng.randi_range(2, 4), _shade(leaf, rng.randi_range(-30, -12)), rng)
        for i in 34:
                _blob(img, 8, rng.randi_range(1, 30), rng.randi_range(1, 30), rng.randi_range(1, 3), rng.randi_range(1, 3), _shade(leaf, rng.randi_range(10, 30)), rng)
        for i in 16:  # dark holes
                _px(img, 8, rng.randi_range(0, 31), rng.randi_range(0, 31), Color8(22, 54, 12))

        # ---- 9 planks: horizontal boards + grain + nails ----
        _noise_rect(img, 9, plank, 7, rng)
        for y0 in range(0, 32, 8):
                for x in 32:
                        _px(img, 9, x, y0, Color8(126, 98, 56))
                        _px(img, 9, x, y0 + 7, Color8(126, 98, 56))
                for g in rng.randi_range(2, 4):  # grain
                        var gx := rng.randi_range(2, 29)
                        for y in range(y0 + 2, y0 + 6):
                                _px(img, 9, gx, y, Color8(146, 114, 66))
                _px(img, 9, 3, y0 + 4, Color8(112, 86, 48))  # nails
                _px(img, 9, 28, y0 + 4, Color8(112, 86, 48))

        # ---- 10 bricks: offset rows + light mortar ----
        _noise_rect(img, 10, brick, 7, rng)
        for y in TILE:
                for x in TILE:
                        if y % 8 >= 6:
                                _px(img, 10, x, y, Color8(206, 198, 190))
                        else:
                                var off := (y / 8) % 2 * 8
                                if (x + off) % 16 >= 14:
                                        _px(img, 10, x, y, Color8(206, 198, 190))
        for i in 26:
                _px(img, 10, rng.randi_range(0, 31), rng.randi_range(0, 31), _shade(brick, rng.randi_range(-18, 14)))

        # ---- 11 snow: sparkles + dimples ----
        _noise_rect(img, 11, Color8(240, 244, 248), 4, rng)
        for i in 30:
                _px(img, 11, rng.randi_range(0, 31), rng.randi_range(0, 31), Color8(255, 255, 255))
        for i in 22:
                _blob(img, 11, rng.randi_range(1, 30), rng.randi_range(1, 30), rng.randi_range(2, 3), rng.randi_range(1, 2), Color8(224, 230, 238), rng)

        # ---- 12 bedrock: chaotic dark ----
        _noise_rect(img, 12, Color8(62, 62, 64), 14, rng)
        for i in 30:
                _blob(img, 12, rng.randi_range(1, 30), rng.randi_range(1, 30), rng.randi_range(2, 5), rng.randi_range(2, 4), Color8(30, 30, 32), rng)
        for i in 18:
                _blob(img, 12, rng.randi_range(1, 30), rng.randi_range(1, 30), rng.randi_range(1, 3), rng.randi_range(1, 2), Color8(96, 96, 98), rng)

        img.generate_mipmaps()
        _atlas = ImageTexture.create_from_image(img)


static func _build_heads() -> void:
        # 16x16 mob face textures
        var defs := {
                "zombie": {"base": Color8(84, 148, 86), "eye": Color8(20, 30, 20), "skin": Color8(70, 126, 72)},
                "pig": {"base": Color8(238, 164, 164), "eye": Color8(30, 30, 40), "skin": Color8(224, 148, 148)},
                "cow": {"base": Color8(107, 74, 51), "eye": Color8(25, 25, 25), "skin": Color8(240, 238, 234)},
                "sheep": {"base": Color8(226, 220, 210), "eye": Color8(30, 30, 30), "skin": Color8(214, 190, 166)},
                "chicken": {"base": Color8(236, 236, 232), "eye": Color8(24, 24, 24), "skin": Color8(226, 172, 64)},
        }
        for kind in defs:
                var d: Dictionary = defs[kind]
                var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
                var rng := RandomNumberGenerator.new()
                rng.seed = hash(kind)
                for y in 16:
                        for x in 16:
                                var v := rng.randi_range(-8, 8)
                                img.set_pixel(x, y, Color(clampf(d.base.r8 + v, 0, 255) / 255.0, clampf(d.base.g8 + v, 0, 255) / 255.0, clampf(d.base.b8 + v, 0, 255) / 255.0))
                # eyes (2x2 each, white pixel for pig/cow/sheep)
                for ex in [3, 11]:
                        img.set_pixel(ex, 6, d.eye)
                        img.set_pixel(ex + 1, 6, d.eye)
                        if kind != "zombie":
                                img.set_pixel(ex + (0 if ex == 3 else 1), 6, Color8(250, 250, 250))
                                img.set_pixel(ex + (1 if ex == 3 else 0), 6, d.eye)
                if kind == "zombie":
                        for x in range(5, 11):
                                img.set_pixel(x, 11, Color8(30, 44, 30))
                        for y in range(4, 7):
                                img.set_pixel(5, y, Color8(56, 104, 58))
                                img.set_pixel(10, y, Color8(56, 104, 58))
                if kind == "pig":
                        for y in range(9, 14):
                                for x in range(4, 12):
                                        img.set_pixel(x, y, Color8(221, 130, 130))
                        for x in [5, 10]:
                                img.set_pixel(x, 11, Color8(120, 60, 60))
                                img.set_pixel(x, 12, Color8(120, 60, 60))
                if kind == "cow":
                        for y in range(3, 16):
                                for x in range(6, 10):
                                        img.set_pixel(x, y, d.skin)
                        for x in [1, 2, 13, 14]:
                                img.set_pixel(x, 15, Color8(236, 232, 226))
                if kind == "sheep":
                        for y in range(6, 16):
                                for x in range(4, 12):
                                        img.set_pixel(x, y, d.skin)
                        for x in range(4, 12):
                                img.set_pixel(x, 6, Color8(200, 176, 150))
                if kind == "chicken":
                        # yellow beak + red wattle
                        for y in range(9, 11):
                                for x in range(6, 10):
                                        img.set_pixel(x, y, Color8(226, 172, 64))
                        for y in range(11, 13):
                                for x in range(7, 9):
                                        img.set_pixel(x, y, Color8(190, 60, 52))
                _heads[kind] = ImageTexture.create_from_image(img)


static func _build_hearts() -> void:
        var rows := [
                " XX XX ", "XXXXXXX", "XXXXXXX", "XXXXXXX", " XXXXX ", "  XXX  ", "   X   ",
        ]
        for mode in ["full", "empty"]:
                var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
                var fill := Color8(227, 52, 52) if mode == "full" else Color8(70, 70, 76)
                var dark := Color8(120, 16, 16) if mode == "full" else Color8(38, 38, 44)
                for y in 7:
                        for x in 7:
                                if rows[y][x] == "X":
                                        var c := fill
                                        if y == 0 or rows[y - 1][x] == " ":
                                                c = fill.lightened(0.25)
                                        elif y >= 4:
                                                c = dark
                                        img.set_pixel(x, y, c)
                _hearts[mode] = ImageTexture.create_from_image(img)


static func tile_uv(t: int) -> Vector2:
        return Vector2((t % N) / float(N), (t / N) / float(N))


static func atlas_texture_for_tile(t: int) -> AtlasTexture:
        var at := AtlasTexture.new()
        at.atlas = atlas()
        at.region = Rect2((t % N) * TILE, (t / N) * TILE, TILE, TILE)
        return at
