extends RefCounted

const ARMY_SLOT: int = 0
const POLICE_SLOT: int = 4
const NAMES: Array[String] = ["AK-47", "PISTOLA", "M4A1", "AR-15", "M16"]
const PATHS: Array[String] = [
	"res://assets/third_person_shooter/rifles/ak47.glb",
	"res://assets/third_person_shooter/pistol.glb",
	"res://assets/third_person_shooter/rifles/m4a1.glb",
    "res://assets/third_person_shooter/rifles/ar15.glb",
    "res://assets/third_person_shooter/rifles/m16.glb"
]
const SCENES: Array[PackedScene] = [preload(PATHS[0]), preload(PATHS[1]), preload(PATHS[2]), preload(PATHS[3]), preload(PATHS[4])]
# The donor has two animation/sound families, independent of inventory slots.
const ANIMATION_KIND: Array[int] = [0, 1, 0, 0, 0]
const FIRE_RATES: Array[float] = [1.0 / 8.0, 1.0 / 6.0, 1.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0]
const DAMAGE: Array[float] = [34.0, 24.0, 34.0, 34.0, 34.0]
const MAGAZINE: Array[int] = [40, 15, 40, 40, 40]
const RESERVE: Array[int] = [1000, 1000, 1000, 1000, 1000]
const RELOAD_TIME: Array[float] = [1.20, 1.20, 1.20, 1.20, 1.20]
const IMPULSE: Array[float] = [2.6, 1.1, 2.6, 2.6, 2.6]
const AUTOMATIC: Array[bool] = [true, false, true, true, true]
const SWITCH_TIME: Array[float] = [0.50, 0.40, 0.50, 0.50, 0.50]

static func attachment(index: int) -> Transform3D:
	if ANIMATION_KIND[index] == 1:
		return Transform3D(
			Vector3(-0.0212634,0.0204641,-0.00224973), Vector3(0.00140209,0.00466622,0.029193),
			Vector3(0.0205397,0.0208667,-0.00432179), Vector3(-0.00442243,0.0715724,0.0180326))
	var orientation := Basis(
		Vector3(-0.0462644,0.0492228,-0.0213227), Vector3(0.00282256,0.0303522,0.063943),
		Vector3(0.0535684,0.0409121,-0.0217846)).orthonormalized()
	return Transform3D(orientation, Vector3(-0.010,0.075,0.012))
