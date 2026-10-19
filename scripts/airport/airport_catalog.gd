class_name AirportCatalog
extends RefCounted
## Explicit fictional training catalogue. No real preparation or handling guidance.
## Suspect props have probabilistic legal lookalikes; truth is host-owned.
const CATEGORIES: Array = ["legal", "narcotics", "organic", "weapons", "explosives", "dangerous", "wildlife", "customs", "pet", "safeguarding"]
const DISPOSAL_CATEGORIES: Array = ["weapons", "explosives", "dangerous"]
const ENTRIES: Array = [
	{"kind":"clothes", "label":"Folded clothes", "category":"legal", "mass":[0.4, 3.0]},
	{"kind":"socks", "label":"Travel socks", "category":"legal", "mass":[0.1, 0.5]},
	{"kind":"documents", "label":"Travel documents", "category":"legal", "mass":[0.1, 0.3]},
	{"kind":"electronics", "label":"Personal electronics", "category":"legal", "mass":[1.0, 7.0]},
	{"kind":"books", "label":"Holiday books", "category":"legal", "mass":[0.5, 5.0]},
	{"kind":"snacks", "label":"Packaged snacks", "category":"legal", "mass":[0.2, 1.5]},
	{"kind":"dildo", "label":"Adult personal item (dildo)", "category":"legal", "mass":[0.2, 0.7]},
	{"kind":"vibrator", "label":"Adult personal item (vibrator)", "category":"legal", "mass":[0.2, 0.8]},
	{"kind":"narcotics", "label":"Fictional violet-dust training packet", "category":"narcotics", "probability":0.72, "mass":[0.2, 1.5]},
	{"kind":"tablets", "label":"Fictional moon-tablet training packet", "category":"narcotics", "probability":0.65, "mass":[0.1, 0.5]},
	{"kind":"fruit", "label":"Undeclared moon fruit", "category":"organic", "probability":0.85, "mass":[0.5, 4.0]},
	{"kind":"vegetable", "label":"Undeclared cloud vegetable", "category":"organic", "probability":0.85, "mass":[0.5, 3.0]},
	{"kind":"seeds", "label":"Undeclared star seeds", "category":"organic", "probability":0.8, "mass":[0.1, 1.0]},
	{"kind":"weapon_prop", "label":"Fictional restricted weapon training prop", "category":"weapons", "probability":0.8, "mass":[1.0, 6.0]},
	{"kind":"explosive_prop", "label":"Fictional inert explosive training block", "category":"explosives", "probability":0.8, "mass":[1.0, 4.0]},
	{"kind":"hazard_canister", "label":"Fictional hazardous glow-canister prop", "category":"dangerous", "probability":0.75, "mass":[0.5, 3.0]},
	{"kind":"wildlife_crate", "label":"Protected fictional cloud-lizard carrier", "category":"wildlife", "mass":[2.0, 8.0]},
	{"kind":"customs_relic", "label":"Undeclared fictional museum relic", "category":"customs", "probability":0.8, "mass":[1.0, 5.0]},
	{"kind":"customs_gems", "label":"Undeclared fictional glass-gem collection", "category":"customs", "probability":0.75, "mass":[0.3, 2.0]},
	{"kind":"pet_cat", "label":"Cat in a ventilated pet carrier", "category":"pet", "mass":[2.5, 6.0]},
	{"kind":"pet_rabbit", "label":"Rabbit in a ventilated pet carrier", "category":"pet", "mass":[1.5, 4.0]}
]

static func entry(kind: String) -> Dictionary:
	for spec in ENTRIES:
		if spec.kind == kind:
			return spec.duplicate(true)
	return {}

static func instantiate(spec: Dictionary, rng: RandomNumberGenerator, id: int, certain: bool = false) -> Dictionary:
	var probability: float = float(spec.get("probability", 1.0))
	var roll: float = rng.randf()
	var actual: String = spec.category if certain or roll < probability else "legal"
	var label: String = spec.label
	if actual == "legal" and spec.category != "legal":
		label = "Cleared legal lookalike — " + label
	return {"id":id, "kind":str(spec.kind), "label":label, "category":actual,
		"mass_kg":float(snappedf(rng.randf_range(float(spec.mass[0]), float(spec.mass[1])), 0.01)),
		"location":"bag", "position":Vector3(-8, 1.14, -2), "held_by":0, "deposited":false,
		"velocity":Vector3.ZERO, "flight_age":0.0, "last_thrower":0,
		"truth":{"declared_category":str(spec.category), "restricted":actual != "legal", "roll":roll, "probability":probability}}

static func random_spec(rng: RandomNumberGenerator) -> Dictionary:
	# Ordinary belongings are common, but every supported category can occur.
	var pool_size: int = 8 if rng.randf() < 0.52 else ENTRIES.size()
	return ENTRIES[rng.randi_range(0, pool_size - 1)].duplicate(true)
