extends Node
## Narration autoload — spoken narration for blind-friendly play.
## Uses Godot 4.6's real built-in TTS: DisplayServer.tts_speak().
## (Verified present in the 4.6 stable binary: tts_speak / tts_stop /
## tts_is_speaking / tts_get_voices. On Android it uses the device TTS
## engine; on desktop it uses the OS speech service when available.)
## Every call is guarded, so the game still works with full on-screen
## text if the platform has no TTS voices.

var enabled := true


func speak(text: String) -> void:
	if not enabled:
		return
	if text == "":
		return
	# Guard: TTS exists on Android / iOS / Windows / macOS. On platforms
	# without it the call is skipped and the on-screen text carries the line.
	if DisplayServer.has_method("tts_speak"):
		# Godot 4.6: tts_speak(text, voice, ...) — voice is required,
		# empty string means the default voice.
		DisplayServer.tts_speak(text, "")


func stop() -> void:
	if DisplayServer.has_method("tts_stop"):
		DisplayServer.tts_stop()


func toggle() -> bool:
	enabled = not enabled
	if not enabled:
		stop()
	return enabled


func is_speaking() -> bool:
	if DisplayServer.has_method("tts_is_speaking"):
		return DisplayServer.tts_is_speaking()
	return false
