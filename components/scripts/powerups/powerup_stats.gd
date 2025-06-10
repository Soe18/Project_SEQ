extends Node
enum rar {
	common = 0,
	uncommon = 1,
	rare = 2,
	epic = 3,
	legendary = 4
}

enum type {
	offensive,
	defensive,
	special
}

const RARITY_COLORS = {
	"common" : Color(1.0, 1.0, 1.0),
	"uncommon" : Color(0.0, 1.0, 0.0),
	"rare" : Color(0.0, 0.92, 0.73),
	"epic" : Color(0.24, 0.0, 1.00),
	"legendary" : Color(0.96, 0.26, 0.0)
}
