extends Node

const ASCII_LETTERS = "abcdefghijklmnopqrstuvwxyz"
const ASCII_DIGITS = "0123456789"
const ASCII_HEXDIGITS = "0123456789ABCDEF"
const ASCII_PUNCTUATION =  "!\"#$%&'()*+, -./:;<=>?@[\\]^_`{|}~"

func _ready() -> void:
	self.set_process(false)
	self.set_process_input(false)

func bool(probability: float = .5) -> bool:
	randomize()

	return bool(randf() < 1 - probability)

func vec2() -> Vector2:
	randomize()

	return Vector2(randf(), randf())

func vec3() -> Vector3:
	randomize()

	return Vector3(randf(), randf(), randf())

func letters(length: int = 1, uppercase : bool = false, unique: bool = false) -> String:
	return from_string(ASCII_LETTERS.to_upper() if uppercase else ASCII_LETTERS, length, unique)

func numeric(length: int = 1, unique: bool = false) -> String:
	return from_string(ASCII_DIGITS, length, unique)

func alphanumeric(length: int = 1, uppercase: bool = false, unique: bool = false) -> String:
	return from_string((ASCII_LETTERS.to_upper() if uppercase else ASCII_LETTERS) + ASCII_DIGITS, length, unique)
	
func hex(length: int = 1, uppercase: bool = false, unique: bool = false) -> String:
	return from_string(ASCII_HEXDIGITS.to_upper() if uppercase else ASCII_HEXDIGITS, length, unique)

func from_string(_string: String, length: int = 1, unique: bool = false) -> String:
	var array: PackedByteArray = from_array(_string.to_utf8_buffer(), length, unique)
	return array.get_string_from_utf8()

func color(hueMin: float = 0, hueMax: float = 1, saturationMin: float = 0, saturationMax: float = 1, valueMin: float = 0, valueMax: float = 1, alphaMin: float = 1, alphaMax: float = 1) -> Color:
	randomize()
	var opaque = alphaMin == alphaMax

	return Color.from_hsv(randf_range(hueMin, hueMax), randf_range(saturationMin, saturationMax), randf_range(valueMin, valueMax), 1.0 if opaque else randf_range(alphaMin, alphaMax))

func byte() -> int:
	randomize()

	return randi() % 256

func byte_array(size: int = 1) -> PackedByteArray:
	randomize()
	var array = []

	for _i in range(0, size):
		array.append(byte())

	return PackedByteArray(array)

func from_array(array: Array, num: int = 1, unique: bool = false) -> Array:
	assert(num >= 1, "Invalid element count.")

	if unique: assert(num <= len(array), "Ran out of characters.")

	randomize()

	if len(array) == 1:
		return array[0]
	elif num == 1:
		return [array[randi() % len(array)]]
	else:
		var results = []

		while num > 0:
			var index = randi() % len(array)
			results.append(array[index])
			num -= 1

			if unique:
				array.erase(index)

		return results
