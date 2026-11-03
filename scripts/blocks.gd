class_name Blocks
## Block ids, tiles and helpers. Tile atlas is 8x8 tiles of 16px.

const AIR = 0
const GRASS = 1
const DIRT = 2
const STONE = 3
const COBBLE = 4
const SAND = 5
const LOG = 6
const LEAVES = 7
const PLANKS = 8
const BRICKS = 9
const SNOW = 10
const BEDROCK = 11

# Tile index in the 8x8 atlas for uniform blocks
const UNIFORM_TILE = {
        2: 2, 3: 3, 4: 4, 5: 5, 7: 8, 8: 9, 9: 10, 10: 11, 11: 12,
}

# Tile shown in the hotbar / menu for each block id
const ICON_TILE = {
        1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 8: 9, 7: 8,
}

## Persian display names
const NAMES = {
        1: "بلوک چمن", 2: "خاک", 3: "سنگ", 4: "سنگ لاشه", 5: "شن",
        6: "تنه درخت", 7: "شاخ‌وبرگ", 8: "چوب", 9: "آجر", 10: "برف",
}

## What a broken block drops (Minecraft-like: grass->dirt, stone->cobble)
static func drop_of(id: int) -> int:
        if id == GRASS:
                return DIRT
        if id == STONE:
                return COBBLE
        if id == AIR or id == BEDROCK:
                return AIR
        return id


static func face_tile(id: int, face: int) -> int:
        # face: 0=+Y top, 1=-Y bottom, 2..5 sides
        if id == GRASS:
                if face == 0:
                        return 0
                elif face == 1:
                        return 2
                return 1
        if id == LOG:
                return 7 if face < 2 else 6
        return int(UNIFORM_TILE.get(id, 3))


static func is_solid_id(id: int) -> bool:
        return id != AIR


static func breakable(id: int) -> bool:
        return id != AIR and id != BEDROCK
