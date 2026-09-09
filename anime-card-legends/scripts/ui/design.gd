class_name Design
extends RefCounted

# =========================================================
# DESIGN TOKENS - the single source of truth for all visual values.
# Nothing anywhere else in the game should contain a raw hex colour,
# a magic pixel size, or a font size. Change the look of the entire
# game from this file.
# =========================================================

# ---------------- SURFACES ----------------
const BG          := Color("#0b0d14")  # app background
const SURFACE     := Color("#141824")  # cards, panels
const SURFACE_2   := Color("#1c2130")  # raised elements, buttons
const SURFACE_3   := Color("#262c3d")  # hover / active
const OVERLAY     := Color(0, 0, 0, 0.72)
const HAIRLINE    := Color("#2d3446")

# ---------------- TEXT ----------------
const TEXT        := Color("#eef0f5")
const TEXT_DIM    := Color("#a3aab9")
const TEXT_MUTED  := Color("#646c7e")
const TEXT_INVERT := Color("#0b0d14")

# ---------------- BRAND / SEMANTIC ----------------
const ACCENT      := Color("#f5a623")
const ACCENT_SOFT := Color("#4a3410")
const SUCCESS     := Color("#3ecf7e")
const DANGER      := Color("#ef4444")
const INFO        := Color("#3b82f6")
const ENERGY      := Color("#f5c518")

# ---------------- RARITY RAMP ----------------
const RARITY := {
	"Common":    Color("#8a8f9a"),
	"Uncommon":  Color("#3ecf7e"),
	"Rare":      Color("#3b82f6"),
	"Epic":      Color("#a855f7"),
	"Legendary": Color("#f5a623"),
	"Mythic":    Color("#ef4444"),
	"Secret":    Color("#ffffff"),
	"Awakened":  Color("#ff2d95"),
}

# Visual weight per rarity: border thickness and aura bloom radius.
const RARITY_BORDER := {
	"Common": 2, "Uncommon": 2, "Rare": 3, "Epic": 4,
	"Legendary": 5, "Mythic": 6, "Secret": 7, "Awakened": 8,
}
const RARITY_AURA := {
	"Common": 0, "Uncommon": 4, "Rare": 8, "Epic": 13,
	"Legendary": 18, "Mythic": 24, "Secret": 30, "Awakened": 38,
}

# ---------------- ELEMENTS ----------------
const ELEMENT := {
	"Fire":  Color("#e0532c"),
	"Water": Color("#2c86e0"),
	"Earth": Color("#8a6a42"),
	"Wind":  Color("#3ac9a6"),
	"Light": Color("#e0c840"),
	"Dark":  Color("#7a4ae0"),
}
const ELEMENT_ICON := {
	"Fire": "🔥", "Water": "💧", "Earth": "⛰️",
	"Wind": "🌪️", "Light": "✨", "Dark": "🌑",
}
const ROLE_ICON := {
	"Tank": "🛡️", "DPS": "⚔️", "Assassin": "🗡️",
	"Healer": "💚", "Support": "🔮",
}

# ---------------- SPACING SCALE ----------------
const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S5 := 24
const S6 := 32
const S7 := 48

# ---------------- TYPE SCALE ----------------
const FS_DISPLAY := 34
const FS_TITLE   := 24
const FS_HEADING := 17
const FS_BODY    := 14
const FS_SMALL    := 12
const FS_MICRO   := 10

# ---------------- RADIUS ----------------
const R_SM := 6
const R_MD := 10
const R_LG := 14

# ---------------- CARD GEOMETRY ----------------
# Card geometry - 2:3 portrait, art is full-bleed behind the overlays.
const CARD_W := 196
const CARD_H := 294
const CARD_W_SM := 132
const CARD_H_SM := 198

# ---------------- MOTION ----------------
const T_FAST := 0.18
const T_BASE := 0.28
const T_SLOW := 0.55


static func rarity_color(rarity: String) -> Color:
	return RARITY.get(rarity, TEXT_MUTED)

static func element_color(element: String) -> Color:
	return ELEMENT.get(element, SURFACE_3)

static func alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
