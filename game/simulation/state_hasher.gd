class_name StateHasher
extends RefCounted

## Exact sha256 digest of a simulation state tree, for determinism tests now and
## save/load and host/client desync checks later.
##
## Walks script variables by reflection, so a new state field is covered without
## touching this file, and writes exact bytes (`var_to_bytes`, no rounding).
## A class leaves fields out (caches, presentation buffers) by declaring
## `const HASH_SKIPPED_FIELDS: Array[StringName] = [&"_cache"]`.
##
## A `Node` or `Callable` is a tag only. A `RandomNumberGenerator` is its `seed`
## and `state`. Any other object without a script is its class name. A reference
## cycle is reported with `push_error` and hashed as a tag.

const SKIPPED_FIELDS_CONSTANT: String = "HASH_SKIPPED_FIELDS"

const _TAG_VALUE: int = 1
const _TAG_ARRAY: int = 2
const _TAG_DICTIONARY: int = 3
const _TAG_OBJECT: int = 4
const _TAG_NULL: int = 5
const _TAG_NODE: int = 6
const _TAG_CALLABLE: int = 7
const _TAG_RNG: int = 8
const _TAG_NATIVE: int = 9
const _TAG_CYCLE: int = 10

## `Script -> Array[StringName]`: memo of the fields a script's objects are hashed by.
static var _field_names_by_script: Dictionary = {}


## One sha256 hex digest of the whole value tree under `root`.
static func digest(root: Variant) -> String:
	return _sha256_hex(encode(root))


## `field name -> sha256 hex` of each hashed field of `root`, to find which part
## of the state two simulations disagree on.
static func field_digests(root: Object) -> Dictionary:
	var digests: Dictionary = {}
	var script: Script = root.get_script()
	if script == null:
		return digests
	for field_name: StringName in _field_names(script):
		digests[field_name] = _sha256_hex(encode(root.get(field_name)))
	return digests


## The exact bytes `digest()` hashes.
static func encode(value: Variant) -> PackedByteArray:
	var encoder: _Encoder = _Encoder.new()
	encoder.put_value(value)
	return encoder.bytes()


static func _sha256_hex(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func _field_names(script: Script) -> Array[StringName]:
	if _field_names_by_script.has(script):
		return _field_names_by_script[script]
	var skipped: Array = []
	var constants: Dictionary = script.get_script_constant_map()
	if constants.has(SKIPPED_FIELDS_CONSTANT):
		skipped = constants[SKIPPED_FIELDS_CONSTANT]
	var names: Array[StringName] = []
	for property: Dictionary in script.get_script_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var property_name: StringName = StringName(property["name"])
		if skipped.has(property_name) or names.has(property_name):
			continue
		names.append(property_name)
	_field_names_by_script[script] = names
	return names


static func _script_key(script: Script) -> String:
	var global_name: StringName = script.get_global_name()
	return String(global_name) if global_name != &"" else script.resource_path


## Writes one value tree into a byte buffer; `bytes()` returns it.
class _Encoder:
	var _buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	## Instance ids of the objects on the current path, against cycles.
	var _on_path: Dictionary = {}

	func bytes() -> PackedByteArray:
		return _buffer.data_array

	func put_value(value: Variant) -> void:
		match typeof(value):
			TYPE_OBJECT:
				put_object(value)
			TYPE_ARRAY:
				var array: Array = value
				_buffer.put_u8(_TAG_ARRAY)
				_buffer.put_u32(array.size())
				for element: Variant in array:
					put_value(element)
			TYPE_DICTIONARY:
				var dictionary: Dictionary = value
				_buffer.put_u8(_TAG_DICTIONARY)
				_buffer.put_u32(dictionary.size())
				# Insertion order: the same on two simulations that ran the same.
				for key: Variant in dictionary.keys():
					put_value(key)
					put_value(dictionary[key])
			TYPE_CALLABLE, TYPE_SIGNAL:
				_buffer.put_u8(_TAG_CALLABLE)
			_:
				var encoded: PackedByteArray = var_to_bytes(value)
				_buffer.put_u8(_TAG_VALUE)
				_buffer.put_u32(encoded.size())
				_buffer.put_data(encoded)

	func put_object(value: Variant) -> void:
		if not is_instance_valid(value):
			_buffer.put_u8(_TAG_NULL)
			return
		var object: Object = value
		if object is Node:
			_buffer.put_u8(_TAG_NODE)
			_buffer.put_utf8_string(object.get_class())
			return
		if object is RandomNumberGenerator:
			var generator: RandomNumberGenerator = object
			_buffer.put_u8(_TAG_RNG)
			_buffer.put_u64(generator.seed)
			_buffer.put_u64(generator.state)
			return
		var script: Script = object.get_script()
		if script == null:
			_buffer.put_u8(_TAG_NATIVE)
			_buffer.put_utf8_string(object.get_class())
			return
		var instance_id: int = object.get_instance_id()
		if _on_path.has(instance_id):
			push_error("StateHasher: reference cycle through %s" % StateHasher._script_key(script))
			_buffer.put_u8(_TAG_CYCLE)
			return
		_on_path[instance_id] = true
		var field_names: Array[StringName] = StateHasher._field_names(script)
		_buffer.put_u8(_TAG_OBJECT)
		_buffer.put_utf8_string(StateHasher._script_key(script))
		_buffer.put_u32(field_names.size())
		for field_name: StringName in field_names:
			put_value(object.get(field_name))
		_on_path.erase(instance_id)
