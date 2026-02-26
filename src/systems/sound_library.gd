extends Node

## SoundLibrary — generates and caches procedural sound effects at runtime.
## Access sounds via SoundLibrary.jump, SoundLibrary.coin, etc.
## All sounds are short AudioStreamWAV resources built from PCM synthesis.

const SAMPLE_RATE: int = 22050
const MIX_RATE: int = 22050

# Cached sound streams (populated in _ready)
var jump: AudioStreamWAV
var double_jump: AudioStreamWAV
var land: AudioStreamWAV
var wall_run_start: AudioStreamWAV
var wall_jump: AudioStreamWAV
var coin: AudioStreamWAV
var star: AudioStreamWAV
var hurt: AudioStreamWAV
var enemy_hit: AudioStreamWAV
var enemy_death: AudioStreamWAV
var ground_pound: AudioStreamWAV
var spin_attack: AudioStreamWAV
var crate_break: AudioStreamWAV
var checkpoint: AudioStreamWAV
var level_complete: AudioStreamWAV
var health_pickup: AudioStreamWAV
var dash: AudioStreamWAV
var wall_slide: AudioStreamWAV
var slide: AudioStreamWAV
var bat_screech: AudioStreamWAV
var bat_swoop: AudioStreamWAV
var crystal_shatter: AudioStreamWAV


func _ready() -> void:
	jump = _make_chirp(300.0, 600.0, 0.08, 0.6)
	double_jump = _make_chirp(400.0, 800.0, 0.1, 0.5)
	land = _make_noise(0.06, 0.4)
	wall_run_start = _make_chirp(200.0, 500.0, 0.12, 0.5)
	wall_jump = _make_chirp(500.0, 900.0, 0.1, 0.5)
	coin = _make_two_tone(800.0, 1200.0, 0.15, 0.5)
	star = _make_arpeggio([523.0, 659.0, 784.0, 1047.0], 0.4, 0.5)
	hurt = _make_chirp_square(400.0, 150.0, 0.2, 0.5)
	enemy_hit = _mix([_make_noise(0.08, 0.4), _make_sine(120.0, 0.1, 0.5)])
	enemy_death = _mix([_make_sine(600.0, 0.08, 0.5), _make_noise(0.1, 0.3)])
	ground_pound = _mix([_make_sine(80.0, 0.2, 0.7), _make_noise(0.15, 0.4)])
	spin_attack = _make_filtered_noise_sweep(0.15, 0.5)
	crate_break = _make_noise(0.12, 0.5)
	checkpoint = _make_two_tone(600.0, 900.0, 0.3, 0.4)
	level_complete = _make_arpeggio([523.0, 659.0, 784.0, 1047.0], 0.5, 0.5)
	health_pickup = _make_chirp(400.0, 700.0, 0.2, 0.4)
	dash = _make_filtered_noise_sweep(0.1, 0.6)
	wall_slide = _make_filtered_noise_sweep(0.3, 0.3)  # Low continuous scrape
	slide = _make_filtered_noise_sweep(0.12, 0.5)  # Short whoosh/scrape
	bat_screech = _make_chirp(800.0, 1200.0, 0.08, 0.5)
	bat_swoop = _make_filtered_noise_sweep(0.15, 0.5)
	crystal_shatter = _mix([_make_sine(1200.0, 0.1, 0.5), _make_noise(0.12, 0.4)])


## Generate a pure sine wave tone.
func _make_sine(freq: float, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)  # 16-bit = 2 bytes per sample

	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0 - (float(i) / samples)  # Linear fade out
		var sample_val := sin(t * freq * TAU) * volume * envelope
		var sample_int := clampi(int(sample_val * 32767.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	return _pack_wav(data)


## Generate a frequency sweep (chirp) using sine wave.
func _make_chirp(freq_start: float, freq_end: float, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / samples
		var freq := lerpf(freq_start, freq_end, progress)
		var envelope := 1.0 - progress  # Fade out
		var sample_val := sin(t * freq * TAU) * volume * envelope
		var sample_int := clampi(int(sample_val * 32767.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	return _pack_wav(data)


## Generate a chirp using square wave (buzzy, retro sound).
func _make_chirp_square(freq_start: float, freq_end: float, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / samples
		var freq := lerpf(freq_start, freq_end, progress)
		var envelope := 1.0 - progress
		var sine_val := sin(t * freq * TAU)
		var square_val := 1.0 if sine_val >= 0.0 else -1.0
		var sample_val := square_val * volume * envelope * 0.5  # Quieter since square is harsh
		var sample_int := clampi(int(sample_val * 32767.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	return _pack_wav(data)


## Generate white noise burst.
func _make_noise(duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var progress := float(i) / samples
		var envelope := 1.0 - progress
		var sample_val := randf_range(-1.0, 1.0) * volume * envelope
		var sample_int := clampi(int(sample_val * 32767.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	return _pack_wav(data)


## Generate a two-tone ding (coin-like).
func _make_two_tone(freq_a: float, freq_b: float, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var half := samples / 2

	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var freq := freq_a if i < half else freq_b
		var local_progress := float(i % half) / half if half > 0 else 0.0
		var envelope := 1.0 - (float(i) / samples) * 0.7  # Slow overall fade
		var sample_val := sin(t * freq * TAU) * volume * envelope
		var sample_int := clampi(int(sample_val * 32767.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	return _pack_wav(data)


## Generate an ascending arpeggio from an array of frequencies.
func _make_arpeggio(freqs: Array, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var note_samples := samples / freqs.size()

	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var note_idx := mini(i / note_samples, freqs.size() - 1) if note_samples > 0 else 0
		var freq: float = freqs[note_idx]
		var overall_env := 1.0 - (float(i) / samples) * 0.5
		var note_progress := float(i % note_samples) / note_samples if note_samples > 0 else 0.0
		var note_env := 1.0 - note_progress * 0.3  # Slight per-note fade
		var sample_val := sin(t * freq * TAU) * volume * overall_env * note_env
		var sample_int := clampi(int(sample_val * 32767.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	return _pack_wav(data)


## Generate a filtered noise sweep (whoosh effect).
func _make_filtered_noise_sweep(duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var prev_sample := 0.0

	for i in range(samples):
		var progress := float(i) / samples
		var envelope := sin(progress * PI)  # Bell curve: rises then falls
		# Simple low-pass: blend noise with previous sample, sweep the mix factor
		var mix_factor := lerpf(0.2, 0.8, progress)  # More filtering over time
		var noise := randf_range(-1.0, 1.0)
		var filtered := prev_sample * mix_factor + noise * (1.0 - mix_factor)
		prev_sample = filtered
		var sample_val := filtered * volume * envelope
		var sample_int := clampi(int(sample_val * 32767.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	return _pack_wav(data)


## Mix multiple AudioStreamWAV together by summing their PCM data.
func _mix(streams: Array) -> AudioStreamWAV:
	if streams.is_empty():
		return _make_sine(440.0, 0.1)

	# Find the longest stream
	var max_samples := 0
	for stream in streams:
		var s: AudioStreamWAV = stream
		var sample_count := s.data.size() / 2
		if sample_count > max_samples:
			max_samples = sample_count

	var mixed := PackedByteArray()
	mixed.resize(max_samples * 2)

	for i in range(max_samples):
		var sum := 0.0
		for stream in streams:
			var s: AudioStreamWAV = stream
			var idx := i * 2
			if idx + 1 < s.data.size():
				var lo: int = s.data[idx]
				var hi: int = s.data[idx + 1]
				var sample_int := lo | (hi << 8)
				if sample_int >= 32768:
					sample_int -= 65536
				sum += float(sample_int) / 32767.0
		# Clamp the mixed result
		sum = clampf(sum, -1.0, 1.0)
		var out_int := clampi(int(sum * 32767.0), -32768, 32767)
		mixed[i * 2] = out_int & 0xFF
		mixed[i * 2 + 1] = (out_int >> 8) & 0xFF

	return _pack_wav(mixed)


## Package raw PCM data into an AudioStreamWAV.
func _pack_wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
