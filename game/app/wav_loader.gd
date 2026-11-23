class_name WavLoader
extends RefCounted

## Loads a WAV file from outside `res://`: PCM and float go to Godot's own
## loader; IMA ADPCM (format 0x11, used by many old games' sounds) is decoded
## here to 16-bit PCM. Anything else is `null`, without an engine error.

const FORMAT_PCM: int = 1
const FORMAT_FLOAT: int = 3
const FORMAT_IMA_ADPCM: int = 0x11

const _INDEX_TABLE: Array[int] = [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]
const _STEP_TABLE: Array[int] = [
	7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97,
	107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
	876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428,
	4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350,
	22385, 24623, 27086, 29794, 32767,
]


static func load(path: String) -> AudioStream:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" \
			or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var format: Dictionary = {}
	var data: PackedByteArray = PackedByteArray()
	var at: int = 12
	while at + 8 <= bytes.size():
		var chunk: String = bytes.slice(at, at + 4).get_string_from_ascii()
		var size: int = bytes.decode_u32(at + 4)
		var body: int = at + 8
		if chunk == "fmt ":
			format = {
				&"code": bytes.decode_u16(body),
				&"channels": bytes.decode_u16(body + 2),
				&"rate": bytes.decode_u32(body + 4),
				&"block_align": bytes.decode_u16(body + 12),
			}
		elif chunk == "data":
			data = bytes.slice(body, mini(body + size, bytes.size()))
		at = body + size + (size & 1)
	if format.is_empty() or data.is_empty():
		return null
	match int(format[&"code"]):
		FORMAT_PCM, FORMAT_FLOAT:
			return AudioStreamWAV.load_from_file(path)
		FORMAT_IMA_ADPCM:
			return _ima_adpcm(data, format[&"channels"], format[&"rate"], format[&"block_align"])
	return null


## Microsoft IMA ADPCM blocks: per channel a 4-byte header (first sample,
## step index), then nibbles; stereo interleaves 4 bytes per channel.
static func _ima_adpcm(data: PackedByteArray, channels: int, rate: int, block_align: int) -> AudioStreamWAV:
	if channels < 1 or channels > 2 or block_align <= 4 * channels:
		return null
	var pcm: PackedByteArray = PackedByteArray()
	# Plain arrays: a packed array inside an array is a copy, an Array is shared.
	var per_channel: Array[Array] = []
	for channel: int in channels:
		per_channel.append([])
	var block_start: int = 0
	while block_start + 4 * channels <= data.size():
		var block_end: int = mini(block_start + block_align, data.size())
		var predictors: Array[int] = []
		var indices: Array[int] = []
		for channel: int in channels:
			predictors.append(data.decode_s16(block_start + 4 * channel))
			indices.append(clampi(data[block_start + 4 * channel + 2], 0, 88))
			per_channel[channel].append(predictors[channel])
		var at: int = block_start + 4 * channels
		while at + 4 * channels <= block_end:
			for channel: int in channels:
				for i: int in 4:
					var byte: int = data[at + channel * 4 + i]
					for nibble: int in [byte & 0x0F, byte >> 4]:
						var step: int = _STEP_TABLE[indices[channel]]
						var diff: int = step >> 3
						if nibble & 1:
							diff += step >> 2
						if nibble & 2:
							diff += step >> 1
						if nibble & 4:
							diff += step
						predictors[channel] = clampi(predictors[channel] - diff if nibble & 8 else predictors[channel] + diff,
								-32768, 32767)
						indices[channel] = clampi(indices[channel] + _INDEX_TABLE[nibble], 0, 88)
						per_channel[channel].append(predictors[channel])
			at += 4 * channels
		block_start += block_align
	var frames: int = per_channel[0].size()
	pcm.resize(frames * channels * 2)
	for frame: int in frames:
		for channel: int in channels:
			pcm.encode_s16((frame * channels + channel) * 2, per_channel[channel][frame])
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = channels == 2
	stream.data = pcm
	return stream
