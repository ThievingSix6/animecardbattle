class_name CardData
extends Resource

@export_category("Identity")
@export var card_id: String = ""
@export var card_name: String = ""
@export_multiline var description: String = ""

@export_category("Classification")
@export var faction: String = ""
@export var element: String = ""
@export var role: String = ""
@export var origin_tag: String = ""

@export_category("Rarity")
@export var rarity: String = "Common"
@export var modifier: String = "Normal"

@export_category("Stats")
@export var level: int = 1
@export var max_level: int = 100
@export var attack: int = 10
@export var defense: int = 10
@export var health: int = 100
@export var speed: int = 10
@export var crit_chance: float = 0.05
@export var crit_damage: float = 1.5

@export_category("Abilities")
@export var basic_ability: String = ""
@export var ultimate_ability: String = ""

@export_category("Targeting")
@export_enum("active", "backline", "aoe") var basic_target_mode: String = "active"
@export_enum("active", "backline", "aoe") var ultimate_target_mode: String = "active"

@export_category("Passive Skill")
# Id into the skill library (scripts/core/skills.gd); "" means none.
@export var skill_id: String = ""

@export_category("Progression")
@export var stars: int = 1
@export var max_stars: int = 6
@export var experience: int = 0

@export_category("Economy")
@export var sell_value: int = 10
@export var upgrade_cost: int = 100

@export_category("Collection")
@export var obtained: bool = false
@export var locked: bool = false
