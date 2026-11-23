class_name DataSamples
extends RefCounted

## A small, valid, fully linked set with one definition of every type, so a
## test can break one field and see exactly that rule fire.


static func faction() -> FactionDef:
	var def: FactionDef = FactionDef.new()
	def.id = &"sample_faction"
	def.name_key = &"SAMPLE_FACTION_NAME"
	def.school = &"order"
	def.color = Color(0.2, 0.4, 0.8)
	return def


static func unit() -> UnitDef:
	var def: UnitDef = UnitDef.new()
	def.id = &"sample_unit"
	def.name_key = &"SAMPLE_UNIT_NAME"
	def.faction = &"sample_faction"
	def.tier = 2
	def.role = UnitDef.Role.SHOOTER
	def.attack = 3
	def.defence = 3
	def.min_dmg = 2
	def.max_dmg = 4
	def.hp = 11
	def.speed = 4
	def.initiative = 9
	def.shots = 10
	def.abilities = [&"sample_ability"]
	def.spells = [&"sample_spell"]
	def.mana = 10
	def.magic_resist = 200
	def.weekly_growth = 12
	def.cost = {&"gold": 60}
	def.exp = 6
	def.sounds = {&"attack": "sounds/sample_attack.wav"}
	return def


static func upgraded_unit() -> UnitDef:
	var def: UnitDef = unit()
	def.id = &"sample_unit_up"
	def.name_key = &"SAMPLE_UNIT_UP_NAME"
	def.upgrade_of = &"sample_unit"
	def.attack = 4
	def.cost = {&"gold": 90}
	return def


static func ability() -> AbilityDef:
	var def: AbilityDef = AbilityDef.new()
	def.id = &"sample_ability"
	def.name_key = &"SAMPLE_ABILITY_NAME"
	def.params = {&"bonus": 100}
	def.ai_weight = 50
	return def


static func spell() -> SpellDef:
	var def: SpellDef = SpellDef.new()
	def.id = &"sample_spell"
	def.name_key = &"SAMPLE_SPELL_NAME"
	def.school = &"order"
	def.level = 2
	def.mana_cost = 8
	def.target = SpellDef.Target.ENEMY
	def.area = 1
	def.base = PackedInt32Array([10, 15, 20, 30])
	def.per_power = PackedInt32Array([5, 6, 7, 8])
	def.effect = SpellDef.Effect.STATUS
	def.duration_rule = SpellDef.Duration.BY_POWER
	def.handler = load("res://game/simulation/battle/spells/damage.gd")
	return def


static func order() -> OrderDef:
	var def: OrderDef = OrderDef.new()
	def.id = &"sample_order"
	def.name_key = &"SAMPLE_ORDER_NAME"
	def.cost = 2
	def.effect = &"hold_line"
	def.params = {&"defence": 300}
	return def


static func hero_class() -> HeroClassDef:
	var def: HeroClassDef = HeroClassDef.new()
	def.id = &"sample_class"
	def.name_key = &"SAMPLE_CLASS_NAME"
	def.faction = &"sample_faction"
	def.attribute_weights = PackedInt32Array([40, 30, 15, 15])
	def.starting_attributes = PackedInt32Array([2, 1, 1, 1])
	def.skill_weights = {&"sample_skill": 10}
	def.starting_skills = [&"sample_skill"]
	return def


static func hero() -> HeroDef:
	var def: HeroDef = HeroDef.new()
	def.id = &"sample_hero"
	def.name_key = &"SAMPLE_HERO_NAME"
	def.hero_class = &"sample_class"
	def.specialization = &"sample_spec"
	def.starting_army = {&"sample_unit": 20}
	def.starting_spells = [&"sample_spell"]
	return def


static func skill() -> SkillDef:
	var def: SkillDef = SkillDef.new()
	def.id = &"sample_skill"
	def.name_key = &"SAMPLE_SKILL_NAME"
	def.effect = &"attack_bonus"
	def.level_params = [{&"bonus": 1}, {&"bonus": 2}, {&"bonus": 3}]
	return def


static func perk() -> PerkDef:
	var def: PerkDef = PerkDef.new()
	def.id = &"sample_perk"
	def.name_key = &"SAMPLE_PERK_NAME"
	def.skill = &"sample_skill"
	def.required_level = 2
	def.effect = &"first_strike"
	return def


static func artifact() -> ArtifactDef:
	var def: ArtifactDef = ArtifactDef.new()
	def.id = &"sample_artifact"
	def.name_key = &"SAMPLE_ARTIFACT_NAME"
	def.slot = ArtifactDef.Slot.RING
	def.bonuses = {&"attack": 2}
	def.value = 3000
	def.rarity = ArtifactDef.Rarity.MAJOR
	return def


static func building_hall() -> BuildingDef:
	var def: BuildingDef = BuildingDef.new()
	def.id = &"sample_hall"
	def.name_key = &"SAMPLE_HALL_NAME"
	def.effect = BuildingDef.Effect.INCOME
	def.cost = {&"gold": 2500}
	def.params = {&"gold": 1000}
	return def


static func building_dwelling() -> BuildingDef:
	var def: BuildingDef = BuildingDef.new()
	def.id = &"sample_dwelling"
	def.name_key = &"SAMPLE_DWELLING_NAME"
	def.faction = &"sample_faction"
	def.cost = {&"gold": 1000, &"wood": 5}
	def.requires = [&"sample_hall"]
	def.effect = BuildingDef.Effect.DWELLING
	def.dwelling_unit = &"sample_unit"
	return def


static func map_object() -> MapObjectDef:
	var def: MapObjectDef = MapObjectDef.new()
	def.id = &"sample_mine"
	def.name_key = &"SAMPLE_MINE_NAME"
	def.footprint = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(1, -1)]
	def.entry = Vector2i(0, 1)
	def.visit_rule = MapObjectDef.Visit.CAPTURE
	def.reward = {&"ore": 2}
	def.guard_value = 1500
	def.value = 4000
	return def


static func map_template() -> MapTemplateDef:
	var def: MapTemplateDef = MapTemplateDef.new()
	def.id = &"sample_template"
	def.name_key = &"SAMPLE_TEMPLATE_NAME"
	def.players_min = 2
	def.players_max = 2
	def.size = 36
	var zones: Array[MapZoneDef] = []
	for index: int in 2:
		var zone: MapZoneDef = MapZoneDef.new()
		zone.id = StringName("start_%d" % index)
		zone.kind = MapZoneDef.Kind.START
		zone.player = index
		zone.has_town = true
		zone.mines = {&"wood": 1, &"ore": 1}
		zone.treasure_budget = 20000
		zone.density = 6
		zones.append(zone)
	def.zones = zones
	var link: MapLinkDef = MapLinkDef.new()
	link.zone_a = &"start_0"
	link.zone_b = &"start_1"
	link.guard = 3000
	link.wide = true
	def.links = [link]
	return def


## Every sample, one per type plus the upgrade and the dwelling that link them.
static func all() -> Array[GameDef]:
	return [
		faction(), unit(), upgraded_unit(), ability(), spell(), order(), hero_class(), hero(),
		skill(), perk(), artifact(), building_hall(), building_dwelling(), map_object(), map_template(),
	]
