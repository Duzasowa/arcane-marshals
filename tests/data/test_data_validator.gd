extends TestSuite

## The validator accepts the real data and the sample set, and every rule fires
## on data broken on purpose (one broken field per case).


func test_real_data_is_valid() -> void:
	var data: GameData = GameData.new()
	data.load_all()
	expect_eq([], data.errors, "loads")
	expect_eq([], DataValidator.validate(data), "valid")


func test_sample_set_is_valid() -> void:
	expect_eq([], DataValidator.validate(_samples()), "samples valid")


func test_every_rule_catches_its_break() -> void:
	var cases: Array[Array] = [
		["empty name_key", func(d: GameData) -> void: d.unit(&"sample_unit").name_key = &"", "empty name_key"],
		["faction school", func(d: GameData) -> void: d.faction(&"sample_faction").school = &"fire", "unknown school 'fire'"],
		["unit faction", func(d: GameData) -> void: d.unit(&"sample_unit").faction = &"nope", "unknown faction 'nope'"],
		["unit tier", func(d: GameData) -> void: d.unit(&"sample_unit").tier = 8, "tier 8 outside"],
		["unit hp", func(d: GameData) -> void: d.unit(&"sample_unit").hp = 0, "hp 0 outside"],
		["unit damage", func(d: GameData) -> void: d.unit(&"sample_unit").min_dmg = 5, "min_dmg (1..max_dmg) 5"],
		["unit speed", func(d: GameData) -> void: d.unit(&"sample_unit").speed = 0, "speed 0 outside"],
		["unit initiative", func(d: GameData) -> void: d.unit(&"sample_unit").initiative = 31, "initiative 31"],
		["unit size", func(d: GameData) -> void: d.unit(&"sample_unit").size = 3, "size 3 outside"],
		["unit resist", func(d: GameData) -> void: d.unit(&"sample_unit").magic_resist = 1001, "magic_resist 1001"],
		["unit model", func(d: GameData) -> void: d.unit(&"sample_unit").model = "res://no/such.glb", "model res://no/such.glb not found"],
		["unit shots", func(d: GameData) -> void: d.unit(&"sample_unit").shots = 0, "a SHOOTER needs shots"],
		["unit mana", func(d: GameData) -> void: d.unit(&"sample_unit").mana = 0, "spells without mana"],
		["unit cost key", func(d: GameData) -> void: d.unit(&"sample_unit").cost = {&"mithril": 1}, "unknown resource 'mithril'"],
		["unit cost sign", func(d: GameData) -> void: d.unit(&"sample_unit").cost = {&"gold": -5}, "negative cost"],
		["unit ability", func(d: GameData) -> void: d.unit(&"sample_unit").abilities = [&"nope"], "unknown ability 'nope'"],
		["unit spell", func(d: GameData) -> void: d.unit(&"sample_unit").spells = [&"nope"], "unknown spell 'nope'"],
		["upgrade missing", func(d: GameData) -> void: d.unit(&"sample_unit_up").upgrade_of = &"nope", "unknown upgrade_of 'nope'"],
		["upgrade tier", func(d: GameData) -> void: d.unit(&"sample_unit_up").tier = 3, "keep faction and tier"],
		["upgrade of upgrade", func(d: GameData) -> void: d.unit(&"sample_unit").upgrade_of = &"sample_unit_up", "must name a base unit"],
		["ability weight", func(d: GameData) -> void: d.ability(&"sample_ability").ai_weight = -2000, "ai_weight -2000"],
		["ability handler", func(d: GameData) -> void: d.ability(&"sample_ability").handler = load("res://tests/test_suite.gd"), "handler must extend AbilityHook"],
		["spell school", func(d: GameData) -> void: d.spell(&"sample_spell").school = &"", "unknown school ''"],
		["spell level", func(d: GameData) -> void: d.spell(&"sample_spell").level = 4, "level 4 outside"],
		["spell table", func(d: GameData) -> void: d.spell(&"sample_spell").base = PackedInt32Array([1, 2]), "need 4 values"],
		["spell duration", func(d: GameData) -> void: d.spell(&"sample_spell").duration_rule = SpellDef.Duration.FIXED, "FIXED duration"],
		["spell handler", func(d: GameData) -> void: d.spell(&"sample_spell").handler = load("res://tests/test_suite.gd"), "handler must extend SpellHook"],
		["spell no handler", func(d: GameData) -> void: d.spell(&"sample_spell").handler = null, "no handler"],
		["order cost", func(d: GameData) -> void: d.order(&"sample_order").cost = 0, "cost 0 outside"],
		["order effect", func(d: GameData) -> void: d.order(&"sample_order").effect = &"", "empty effect"],
		["class faction", func(d: GameData) -> void: d.hero_class(&"sample_class").faction = &"nope", "unknown faction 'nope'"],
		["class weights", func(d: GameData) -> void: d.hero_class(&"sample_class").attribute_weights = PackedInt32Array([0, 0, 0, 0]), "sum to zero"],
		["class weight count", func(d: GameData) -> void: d.hero_class(&"sample_class").attribute_weights = PackedInt32Array([1]), "need 4 values"],
		["class start count", func(d: GameData) -> void: d.hero_class(&"sample_class").starting_attributes = PackedInt32Array([1]), "starting_attributes need 4"],
		["class start value", func(d: GameData) -> void: d.hero_class(&"sample_class").starting_attributes = PackedInt32Array([1, -1, 0, 0]), "starting attribute -1 outside"],
		["class skill", func(d: GameData) -> void: d.hero_class(&"sample_class").skill_weights = {&"nope": 1}, "unknown skill in skill_weights 'nope'"],
		["class start skill", func(d: GameData) -> void: d.hero_class(&"sample_class").starting_skills = [&"nope"], "unknown starting skill 'nope'"],
		["hero class", func(d: GameData) -> void: d.hero(&"sample_hero").hero_class = &"nope", "unknown hero_class 'nope'"],
		["hero army unit", func(d: GameData) -> void: d.hero(&"sample_hero").starting_army = {&"nope": 5}, "unknown unit in starting_army 'nope'"],
		["hero army count", func(d: GameData) -> void: d.hero(&"sample_hero").starting_army = {&"sample_unit": 0}, "starting_army count 0"],
		["hero spell", func(d: GameData) -> void: d.hero(&"sample_hero").starting_spells = [&"nope"], "unknown starting spell 'nope'"],
		["hero specialization", func(d: GameData) -> void: d.hero(&"sample_hero").specialization = &"", "empty specialization"],
		["skill levels", func(d: GameData) -> void: d.skill(&"sample_skill").level_params = [{}], "need 3 entries"],
		["perk skill", func(d: GameData) -> void: d.perk(&"sample_perk").skill = &"nope", "unknown skill 'nope'"],
		["perk level", func(d: GameData) -> void: d.perk(&"sample_perk").required_level = 0, "required_level 0"],
		["artifact value", func(d: GameData) -> void: d.artifact(&"sample_artifact").value = -1, "value -1 outside"],
		["building faction", func(d: GameData) -> void: d.building(&"sample_dwelling").faction = &"nope", "unknown faction 'nope'"],
		["building requires", func(d: GameData) -> void: d.building(&"sample_dwelling").requires = [&"nope"], "unknown required building 'nope'"],
		["building cycle", func(d: GameData) -> void: d.building(&"sample_hall").requires = [&"sample_dwelling"], "requires form a cycle"],
		["dwelling unit", func(d: GameData) -> void: d.building(&"sample_dwelling").dwelling_unit = &"nope", "unknown dwelling_unit 'nope'"],
		["dwelling on hall", func(d: GameData) -> void: d.building(&"sample_hall").dwelling_unit = &"sample_unit", "non-DWELLING"],
		["object footprint", func(d: GameData) -> void: d.map_object(&"sample_mine").footprint = [], "empty footprint"],
		["object entry", func(d: GameData) -> void: d.map_object(&"sample_mine").entry = Vector2i(5, 5), "entry must be on or next"],
		["object reward", func(d: GameData) -> void: d.map_object(&"sample_mine").reward = {&"ore": -2}, "negative reward"],
		["template players", func(d: GameData) -> void: d.map_template(&"sample_template").players_max = 1, "players_max (players_min..) 1"],
		["template starts", func(d: GameData) -> void: d.map_template(&"sample_template").zones[1].kind = MapZoneDef.Kind.NEUTRAL, "1 start zones for 2 players"],
		["template zone id", func(d: GameData) -> void: d.map_template(&"sample_template").zones[1].id = &"start_0", "present and unique"],
		["template link", func(d: GameData) -> void: d.map_template(&"sample_template").links[0].zone_b = &"nope", "two different known zones"],
		["template mines", func(d: GameData) -> void: d.map_template(&"sample_template").zones[0].mines = {&"gems": 1}, "unknown resource 'gems'"],
	]
	for case: Array in cases:
		var data: GameData = _samples()
		(case[1] as Callable).call(data)
		var problems: Array[String] = DataValidator.validate(data)
		var found: bool = false
		for problem: String in problems:
			found = found or problem.contains(case[2])
		expect_true(found, "%s: expected '%s' in %s" % [case[0], case[2], problems])


func test_full_roster_needs_all_tiers_and_roles() -> void:
	var data: GameData = _samples()
	expect_eq([], DataValidator.validate(data, false), "off: partial faction passes")
	var problems: Array[String] = DataValidator.validate(data, true)
	expect_true(problems.has("faction 'sample_faction': no base unit of tier 1"), "tier 1 missing")
	expect_true(problems.has("faction 'sample_faction': no TANK unit"), "tank missing")
	expect_false(problems.has("faction 'sample_faction': no base unit of tier 2"), "tier 2 present")
	expect_false(problems.has("faction 'sample_faction': no SHOOTER unit"), "shooter present")


func test_full_roster_accepts_a_complete_faction() -> void:
	var data: GameData = GameData.new()
	data.add(DataSamples.faction())
	var roles: Array[int] = [
		UnitDef.Role.MASS, UnitDef.Role.SHOOTER, UnitDef.Role.TANK, UnitDef.Role.FAST,
		UnitDef.Role.SUPPORT, UnitDef.Role.ELITE, UnitDef.Role.CHAMPION,
	]
	for tier: int in range(1, 8):
		var unit: UnitDef = DataSamples.unit()
		unit.id = StringName("tier_%d" % tier)
		unit.tier = tier
		unit.role = roles[tier - 1]
		unit.abilities = []
		unit.spells = []
		data.add(unit)
	expect_eq([], DataValidator.validate(data, true), "complete faction")


func _samples() -> GameData:
	var data: GameData = GameData.new()
	for def: GameDef in DataSamples.all():
		data.add(def)
	return data
