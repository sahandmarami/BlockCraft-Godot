class_name Tex
## All textures are generated procedurally at startup (deterministic).
## Atlas: 8x8 tiles of 16 px = 128x128.

const TILE = 16
const N = 8
const ATLAS_SIZE = TILE * N

static var _atlas: ImageTexture = null
static var _heads := {}
static var _hearts := {}


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


static func _build_atlas() -> void:
	var img := Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20250101
	var grass := Color8(89, 165, 44)
	var dirt := Color8(121, 85, 58)
	var stone := Color8(126, 126, 126)
	var sand := Color8(219, 207, 144)
	var wood := Color8(106, 82, 48)
	var leaf := Color8(47, 126, 30)
	var plank := Color8(163, 130, 76)
	var brick := Color8(156, 87, 69)

	# 0 grass top
	_noise_rect(img, 0, grass, 14, rng)
	for i in 26:
		_px(img, 0, rng.randi_range(0, 15), rng.randi_range(0, 15), Color8(72, 140, 34))
	# 1 grass side
	_noise_rect(img, 1, dirt, 10, rng)
	for x in TILE:
		var h := rng.randi_range(3, 5)
		for y in h:
			_px(img, 1, x, y, Color8(grass.r8 + rng.randi_range(-12, 12), grass.g8 + rng.randi_range(-12, 12), 44))
	# 2 dirt
	_noise_rect(img, 2, dirt, 11, rng)
	for i in 14:
		_px(img, 2, rng.randi_range(0, 15), rng.randi_range(0, 15), Color8(95, 66, 44))
	# 3 stone
	_noise_rect(img, 3, stone, 9, rng)
	for i in 10:
		var sx := rng.randi_range(0, 13)
		var sy := rng.randi_range(0, 13)
		for j in 3:
			_px(img, 3, sx + j, sy, Color8(108, 108, 108))
	# 4 cobble
	_noise_rect(img, 4, stone, 10, rng)
	for p in [0, 5, 11]:
		for i in TILE:
			_px(img, 4, (p + i / 5) % TILE, i, Color8(96, 96, 96))
			_px(img, 4, i, (p + i / 6) % TILE, Color8(96, 96, 96))
	# 5 sand
	_noise_rect(img, 5, sand, 9, rng)
	for i in 8:
		_px(img, 5, rng.randi_range(0, 15), rng.randi_range(0, 15), Color8(200, 188, 124))
	# 6 log side
	_noise_rect(img, 6, wood, 8, rng)
	for x in [2, 6, 11, 14]:
		for y in TILE:
			_px(img, 6, x, y, Color8(84, 64, 36))
	# 7 log top rings
	_noise_rect(img, 7, wood, 6, rng)
	for y in TILE:
		for x in TILE:
			var d := Vector2(x - 7.5, y - 7.5).length()
			if d > 6.8:
				_px(img, 7, x, y, Color8(78, 60, 34))
			elif absf(d - 4.2) < 0.7 or absf(d - 2.2) < 0.6:
				_px(img, 7, x, y, Color8(133, 104, 60))
			elif d <= 1.0:
				_px(img, 7, x, y, Color8(96, 74, 42))
	# 8 leaves
	_noise_rect(img, 8, leaf, 16, rng)
	for i in 18:
		_px(img, 8, rng.randi_range(0, 15), rng.randi_range(0, 15), Color8(24, 66, 14))
	for i in 10:
		_px(img, 8, rng.randi_range(0, 15), rng.randi_range(0, 15), Color8(70, 158, 48))
	# 9 planks
	_noise_rect(img, 9, plank, 8, rng)
	for y in [3, 7, 11, 15]:
		for x in TILE:
			_px(img, 9, x, y, Color8(126, 98, 56))
	for r in 4:
		var sx := rng.randi_range(1, 14)
		for y in range(r * 4, r * 4 + 3):
			_px(img, 9, sx, y, Color8(140, 110, 64))
	# 10 bricks
	_noise_rect(img, 10, brick, 8, rng)
	for y in TILE:
		for x in TILE:
			if y % 4 == 3 or ((x + (y / 4) * 4) % 8) == 7:
				_px(img, 10, x, y, Color8(206, 197, 188))
	# 11 snow
	_noise_rect(img, 11, Color8(238, 242, 245), 5, rng)
	for i in 6:
		_px(img, 11, rng.randi_range(0, 15), rng.randi_range(0, 15), Color8(222, 228, 234))
	# 12 bedrock
	_noise_rect(img, 12, Color8(58, 58, 58), 18, rng)
	for i in 20:
		var bx := rng.randi_range(0, 14)
		var by := rng.randi_range(0, 14)
		for j in 2:
			_px(img, 12, bx + j, by, Color8(28, 28, 28))
	# rest: transparent (unused)
	img.generate_mipmaps()
	_atlas = ImageTexture.create_from_image(img)


static func _build_heads() -> void:
	# 16x16 mob face textures
	var defs := {
		"zombie": {"base": Color8(84, 148, 86), "eye": Color8(20, 30, 20), "skin": Color8(70, 126, 72)},
		"pig": {"base": Color8(238, 164, 164), "eye": Color8(30, 30, 40), "skin": Color8(224, 148, 148)},
		"cow": {"base": Color8(107, 74, 51), "eye": Color8(25, 25, 25), "skin": Color8(240, 238, 234)},
		"sheep": {"base": Color8(226, 220, 210), "eye": Color8(30, 30, 30), "skin": Color8(214, 190, 166)},
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
