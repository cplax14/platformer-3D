extends Node

## MusicLibrary — generates and caches procedural looping music tracks at runtime.
## Access tracks via MusicLibrary.world_1, MusicLibrary.boss, etc.
## All tracks are AudioStreamWAV with loop_mode = LOOP_FORWARD.

const SAMPLE_RATE: int = 22050
const MIX_RATE: int = 22050

# Cached music streams (populated in _ready)
var world_1: AudioStreamWAV
var world_2: AudioStreamWAV
var world_3: AudioStreamWAV
var boss: AudioStreamWAV
var menu: AudioStreamWAV


func _ready() -> void:
	# Generate menu music first so it plays immediately
	menu = _generate_menu()
	# Defer heavier tracks to avoid blocking the first frame
	call_deferred("_generate_remaining")


func _generate_remaining() -> void:
	world_1 = _generate_world_1()
	world_2 = _generate_world_2()
	world_3 = _generate_world_3()
	boss = _generate_boss()


## World 1 — Cheerful C major pentatonic, 120 BPM, 8-bar loop.
## Sine melody + square bass + noise percussion.
func _generate_world_1() -> AudioStreamWAV:
	var bpm := 120.0
	var beat_duration := 60.0 / bpm
	var bar_duration := beat_duration * 4.0
	var total_duration := bar_duration * 8.0
	var samples := int(SAMPLE_RATE * total_duration)
	var data := PackedByteArray()
	data.resize(samples * 2)

	# C major pentatonic: C4, D4, E4, G4, A4, C5
	var melody_notes := [261.6, 293.7, 329.6, 392.0, 440.0, 523.3]
	# Bass notes: C3, G2, A2, F3
	var bass_notes := [130.8, 98.0, 110.0, 174.6]

	# Simple melody pattern (note index per eighth note)
	var melody_pattern := [0, -1, 2, -1, 4, -1, 3, -1, 2, -1, 0, -1, 1, -1, 3, -1,
		5, -1, 4, -1, 3, -1, 2, -1, 4, -1, 3, -1, 2, -1, 0, -1,
		0, -1, 3, -1, 4, -1, 5, -1, 3, -1, 2, -1, 0, -1, 1, -1,
		2, -1, 4, -1, 3, -1, 2, -1, 0, -1, 1, -1, 0, -1, -1, -1]
	# Bass pattern (note index per beat)
	var bass_pattern := [0, 0, 1, 1, 2, 2, 3, 3, 0, 0, 1, 1, 2, 2, 0, 0,
		0, 0, 3, 3, 1, 1, 2, 2, 0, 0, 1, 1, 3, 3, 0, 0]

	var eighth_duration := beat_duration * 0.5

	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var sample := 0.0

		# Melody: sine wave
		var eighth_idx := int(t / eighth_duration) % melody_pattern.size()
		var note_idx: int = melody_pattern[eighth_idx]
		if note_idx >= 0:
			var note_t := fmod(t, eighth_duration)
			var env := maxf(1.0 - note_t / (eighth_duration * 0.9), 0.0)
			var freq: float = melody_notes[note_idx]
			sample += sin(t * freq * TAU) * 0.25 * env

		# Bass: square wave (quieter)
		var beat_idx := int(t / beat_duration) % bass_pattern.size()
		var bass_freq: float = bass_notes[bass_pattern[beat_idx]]
		var bass_t := fmod(t, beat_duration)
		var bass_env := maxf(1.0 - bass_t / (beat_duration * 0.8), 0.0)
		var bass_sine := sin(t * bass_freq * TAU)
		var bass_square := 1.0 if bass_sine >= 0.0 else -1.0
		sample += bass_square * 0.12 * bass_env

		# Percussion: noise on beats 1 and 3
		var beat_in_bar := fmod(t, bar_duration) / beat_duration
		var beat_phase := fmod(beat_in_bar, 1.0)
		if (int(beat_in_bar) == 0 or int(beat_in_bar) == 2) and beat_phase < 0.05:
			sample += randf_range(-0.15, 0.15)

		var sample_int := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	return _pack_looping_wav(data)


## World 2 — Mysterious A minor, 90 BPM. Deeper tones with echo effect.
func _generate_world_2() -> AudioStreamWAV:
	var bpm := 90.0
	var beat_duration := 60.0 / bpm
	var bar_duration := beat_duration * 4.0
	var total_duration := bar_duration * 8.0
	var samples := int(SAMPLE_RATE * total_duration)
	var data := PackedByteArray()
	data.resize(samples * 2)

	# A minor: A3, C4, D4, E4, G4, A4
	var melody_notes := [220.0, 261.6, 293.7, 329.6, 392.0, 440.0]
	# Bass: A2, E2, D3, C3
	var bass_notes := [110.0, 82.4, 146.8, 130.8]

	var melody_pattern := [0, -1, -1, 2, -1, -1, 4, -1, -1, 3, -1, -1,
		5, -1, -1, 4, -1, -1, 3, -1, -1, 1, -1, -1,
		0, -1, -1, 3, -1, -1, 4, -1, -1, 2, -1, -1,
		1, -1, -1, 0, -1, -1, -1, -1, -1, -1, -1, -1]
	var bass_pattern := [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3,
		0, 0, 0, 0, 3, 3, 3, 3, 1, 1, 1, 1, 0, 0, 0, 0]

	var triplet_duration := beat_duration / 3.0

	# Echo buffer (delay by ~200ms)
	var echo_delay := int(SAMPLE_RATE * 0.22)
	var echo_buffer := PackedFloat32Array()
	echo_buffer.resize(echo_delay)

	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var sample := 0.0

		# Melody: sine with slight detune for depth
		var trip_idx := int(t / triplet_duration) % melody_pattern.size()
		var note_idx: int = melody_pattern[trip_idx]
		if note_idx >= 0:
			var note_t := fmod(t, triplet_duration)
			var env := maxf(1.0 - note_t / (triplet_duration * 1.5), 0.0)
			var freq: float = melody_notes[note_idx]
			sample += sin(t * freq * TAU) * 0.2 * env
			sample += sin(t * freq * 1.003 * TAU) * 0.1 * env  # Slight detune

		# Bass: deep sine
		var beat_idx := int(t / beat_duration) % bass_pattern.size()
		var bass_freq: float = bass_notes[bass_pattern[beat_idx]]
		var bass_t := fmod(t, beat_duration)
		var bass_env := maxf(1.0 - bass_t / (beat_duration * 0.9), 0.0)
		sample += sin(t * bass_freq * TAU) * 0.15 * bass_env

		# Echo effect
		var echo_idx := i % echo_delay
		var echo_val: float = echo_buffer[echo_idx]
		echo_buffer[echo_idx] = sample
		sample = sample * 0.7 + echo_val * 0.3

		var sample_int := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	return _pack_looping_wav(data)


## World 3 — Uplifting D major, 130 BPM. Bright arpeggios, soaring feel for Sky Fortress.
func _generate_world_3() -> AudioStreamWAV:
	var bpm := 130.0
	var beat_duration := 60.0 / bpm
	var bar_duration := beat_duration * 4.0
	var total_duration := bar_duration * 8.0
	var samples := int(SAMPLE_RATE * total_duration)
	var data := PackedByteArray()
	data.resize(samples * 2)

	# D major pentatonic: D4, E4, F#4, A4, B4, D5
	var melody_notes := [293.7, 329.6, 370.0, 440.0, 493.9, 587.3]
	# Bass: D3, A2, G2, E3
	var bass_notes := [146.8, 110.0, 98.0, 164.8]

	var melody_pattern := [0, -1, 2, -1, 4, -1, 5, -1, 4, -1, 2, -1, 3, -1, 1, -1,
		0, -1, 3, -1, 5, -1, 4, -1, 2, -1, 3, -1, 4, -1, 5, -1,
		5, -1, 4, -1, 3, -1, 2, -1, 0, -1, 1, -1, 2, -1, 3, -1,
		4, -1, 5, -1, 4, -1, 2, -1, 0, -1, 1, -1, 0, -1, -1, -1]
	var bass_pattern := [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3,
		0, 0, 0, 0, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0]

	var eighth_duration := beat_duration * 0.5

	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var sample := 0.0

		# Melody: bright sine with shimmer
		var eighth_idx := int(t / eighth_duration) % melody_pattern.size()
		var note_idx: int = melody_pattern[eighth_idx]
		if note_idx >= 0:
			var note_t := fmod(t, eighth_duration)
			var env := maxf(1.0 - note_t / (eighth_duration * 0.9), 0.0)
			var freq: float = melody_notes[note_idx]
			sample += sin(t * freq * TAU) * 0.22 * env
			# Octave shimmer
			sample += sin(t * freq * 2.0 * TAU) * 0.06 * env

		# Bass: warm sine
		var beat_idx := int(t / beat_duration) % bass_pattern.size()
		var bass_freq: float = bass_notes[bass_pattern[beat_idx]]
		var bass_t := fmod(t, beat_duration)
		var bass_env := maxf(1.0 - bass_t / (beat_duration * 0.8), 0.0)
		sample += sin(t * bass_freq * TAU) * 0.14 * bass_env

		# Light percussion on beats
		var beat_in_bar := fmod(t, bar_duration) / beat_duration
		var beat_phase := fmod(beat_in_bar, 1.0)
		if beat_phase < 0.03:
			sample += randf_range(-0.1, 0.1) * (1.0 - beat_phase / 0.03)

		var sample_int := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	return _pack_looping_wav(data)


## Boss — Intense, 140 BPM, driving rhythm with tension chords.
func _generate_boss() -> AudioStreamWAV:
	var bpm := 140.0
	var beat_duration := 60.0 / bpm
	var bar_duration := beat_duration * 4.0
	var total_duration := bar_duration * 8.0
	var samples := int(SAMPLE_RATE * total_duration)
	var data := PackedByteArray()
	data.resize(samples * 2)

	# E minor tension: E3, G3, B3, C4, D4, E4
	var melody_notes := [164.8, 196.0, 246.9, 261.6, 293.7, 329.6]
	# Bass: E2, B1, C2, D2
	var bass_notes := [82.4, 61.7, 65.4, 73.4]

	var melody_pattern := [0, 0, 2, -1, 4, 4, 3, -1, 5, 5, 4, -1, 2, 2, 0, -1,
		3, 3, 5, -1, 4, 4, 2, -1, 0, 0, 3, -1, 5, 5, 4, -1,
		0, 0, 2, -1, 5, 5, 4, -1, 3, 3, 1, -1, 0, 0, 2, -1,
		4, 4, 5, -1, 3, 3, 2, -1, 0, 0, -1, -1, 0, -1, -1, -1]
	var bass_pattern := [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3,
		0, 0, 0, 0, 2, 2, 2, 2, 3, 3, 3, 3, 0, 0, 0, 0]

	var sixteenth_duration := beat_duration * 0.25

	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var sample := 0.0

		# Melody: aggressive square-ish wave
		var six_idx := int(t / sixteenth_duration) % melody_pattern.size()
		var note_idx: int = melody_pattern[six_idx]
		if note_idx >= 0:
			var note_t := fmod(t, sixteenth_duration)
			var env := maxf(1.0 - note_t / (sixteenth_duration * 0.7), 0.0)
			var freq: float = melody_notes[note_idx]
			var sine_val := sin(t * freq * TAU)
			# Mix sine + clipped sine for edge
			sample += (sine_val * 0.6 + clampf(sine_val * 2.0, -1.0, 1.0) * 0.4) * 0.18 * env

		# Bass: powerful low square
		var beat_idx := int(t / beat_duration) % bass_pattern.size()
		var bass_freq: float = bass_notes[bass_pattern[beat_idx]]
		var bass_t := fmod(t, beat_duration * 0.5)
		var bass_env := maxf(1.0 - bass_t / (beat_duration * 0.4), 0.0)
		var bass_sine := sin(t * bass_freq * TAU)
		var bass_sq := 1.0 if bass_sine >= 0.0 else -1.0
		sample += bass_sq * 0.15 * bass_env

		# Driving percussion: kick on every beat, snare on 2/4
		var beat_in_bar := fmod(t, bar_duration) / beat_duration
		var beat_phase := fmod(beat_in_bar, 1.0)
		# Kick on every beat
		if beat_phase < 0.04:
			var kick_env := 1.0 - beat_phase / 0.04
			sample += sin(beat_phase * 80.0 * TAU) * 0.2 * kick_env
		# Snare (noise) on 2 and 4
		if (int(beat_in_bar) == 1 or int(beat_in_bar) == 3) and beat_phase < 0.06:
			sample += randf_range(-0.18, 0.18) * (1.0 - beat_phase / 0.06)

		var sample_int := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	return _pack_looping_wav(data)


## Menu — Calm arpeggios, sparse melody, 100 BPM.
func _generate_menu() -> AudioStreamWAV:
	var bpm := 100.0
	var beat_duration := 60.0 / bpm
	var bar_duration := beat_duration * 4.0
	var total_duration := bar_duration * 8.0
	var samples := int(SAMPLE_RATE * total_duration)
	var data := PackedByteArray()
	data.resize(samples * 2)

	# C major 7th arpeggio: C4, E4, G4, B4, C5
	var arp_notes := [261.6, 329.6, 392.0, 493.9, 523.3]
	# Sparse melody: G4, A4, B4, C5, E5
	var melody_notes := [392.0, 440.0, 493.9, 523.3, 659.3]

	# Arpeggio cycles through notes on eighth notes
	var melody_pattern := [-1, -1, -1, -1, -1, -1, 0, -1,
		-1, -1, -1, -1, 2, -1, -1, -1,
		-1, -1, 1, -1, -1, -1, -1, -1,
		3, -1, -1, -1, -1, -1, 4, -1,
		-1, -1, -1, -1, 2, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, 0, -1,
		-1, -1, 1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1]

	var eighth_duration := beat_duration * 0.5

	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var sample := 0.0

		# Arpeggio: cycling through chord tones
		var arp_idx := int(t / eighth_duration) % arp_notes.size()
		var arp_t := fmod(t, eighth_duration)
		var arp_env := maxf(1.0 - arp_t / (eighth_duration * 1.2), 0.0)
		var arp_freq: float = arp_notes[arp_idx]
		sample += sin(t * arp_freq * TAU) * 0.15 * arp_env

		# Sparse melody
		var mel_idx := int(t / eighth_duration) % melody_pattern.size()
		var m_note: int = melody_pattern[mel_idx]
		if m_note >= 0:
			var mel_t := fmod(t, eighth_duration)
			var mel_env := maxf(1.0 - mel_t / (eighth_duration * 2.0), 0.0)
			var mel_freq: float = melody_notes[m_note]
			sample += sin(t * mel_freq * TAU) * 0.12 * mel_env

		# Soft pad: low C3 sine for warmth
		sample += sin(t * 130.8 * TAU) * 0.06

		var sample_int := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	return _pack_looping_wav(data)


## Package raw PCM data into a looping AudioStreamWAV.
func _pack_looping_wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = data.size() / 2  # In samples, not bytes
	return stream
