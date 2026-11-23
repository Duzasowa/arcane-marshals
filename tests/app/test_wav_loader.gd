extends TestSuite

## WavLoader: IMA ADPCM is decoded to 16-bit PCM, PCM goes to Godot's loader,
## anything else is null.

const DIR: String = "user://test_wav_loader"


func test_ima_adpcm_block() -> void:
	# One mono block: header (first sample 1000, step index 0) + 32 bytes of zero nibbles.
	var body: PackedByteArray = PackedByteArray()
	body.resize(36)
	body.fill(0)
	body.encode_s16(0, 1000)
	var path: String = _write("adpcm.wav", _wav(WavLoader.FORMAT_IMA_ADPCM, 1, 22050, 36, 4, body))
	var stream: AudioStreamWAV = WavLoader.load(path) as AudioStreamWAV
	expect_true(stream != null, "decoded")
	if stream == null:
		return
	expect_eq(AudioStreamWAV.FORMAT_16_BITS, stream.format, "16-bit")
	expect_eq(22050, stream.mix_rate, "rate kept")
	expect_eq(65 * 2, stream.data.size(), "1 + 64 samples")
	expect_eq(1000, stream.data.decode_s16(0), "first sample from the header")
	expect_eq(1000, stream.data.decode_s16(64 * 2), "zero nibbles at the smallest step keep it")


func test_pcm_and_garbage() -> void:
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(200)
	samples.fill(0)
	var pcm: AudioStream = WavLoader.load(_write("pcm.wav", _wav(WavLoader.FORMAT_PCM, 1, 8000, 2, 16, samples)))
	expect_true(pcm is AudioStreamWAV, "PCM loads")
	expect_true(WavLoader.load(_write("junk.wav", "not a wave file".to_utf8_buffer())) == null, "junk is null")
	expect_true(WavLoader.load(_write("odd.wav", _wav(2, 1, 8000, 2, 4, samples))) == null, "MS ADPCM is null")
	expect_true(WavLoader.load(DIR.path_join("missing.wav")) == null, "missing file is null")


func _wav(code: int, channels: int, rate: int, block_align: int, bits: int, data: PackedByteArray) -> PackedByteArray:
	var fmt: PackedByteArray = PackedByteArray()
	fmt.resize(16)
	fmt.encode_u16(0, code)
	fmt.encode_u16(2, channels)
	fmt.encode_u32(4, rate)
	fmt.encode_u32(8, rate * block_align)
	fmt.encode_u16(12, block_align)
	fmt.encode_u16(14, bits)
	var bytes: PackedByteArray = "RIFF".to_ascii_buffer()
	var size: PackedByteArray = PackedByteArray()
	size.resize(4)
	size.encode_u32(0, 4 + 8 + fmt.size() + 8 + data.size())
	bytes.append_array(size)
	bytes.append_array("WAVEfmt ".to_ascii_buffer())
	size.encode_u32(0, fmt.size())
	bytes.append_array(size)
	bytes.append_array(fmt)
	bytes.append_array("data".to_ascii_buffer())
	size.encode_u32(0, data.size())
	bytes.append_array(size)
	bytes.append_array(data)
	return bytes


func _write(file_name: String, bytes: PackedByteArray) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path: String = DIR.path_join(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return path
