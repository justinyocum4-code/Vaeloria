# Vaeloria — Build notes (v1.0 starter)

## What this is
An original 2D top-down turn-based RPG in Godot 4.6 (GDScript). Inspired by
the feel of classic JRPGs — party, turn-based battles, epic story, big world —
but NOT a copy: original world (Vaeloria), kingdom (Aldermere), characters
(Kael Arden, Lyra Voss, Mira Solenne, Dax Rook), villain (Lord Varik Kane),
and original pixel art + sounds. No Final Fantasy characters, music, or story.

## Godot version used
- **Godot 4.6 stable** (`4.6.stable.official.89cea1439`), Linux x86_64 editor
  binary downloaded from the official GitHub release
  (`godotengine/godot` releases, tag `4.6-stable`).
- Local copy used for verification: `~/workspace/tools/godot-4.6/Godot_v4.6-stable_linux.x86_64`
  (the project folder itself contains no Godot binary — keep it small).

## Contents (v1.0 starter scope)
- Title screen: New Game / Continue (shows saved level) / Narration on-off.
  Big buttons, D-pad focusable, party sprites on display.
- Aldermere village: one 1280x960 map, walk with arrows / D-pad / WASD or
  tap-to-move. Houses, trees, paths, pond area. Talk to Lyra, Mira, Dax.
- Two turn-based battles: Ember Wolf (east gate, harder) and Ember Slime
  (southwest pond, easier). Attack / Magic: Firebolt (5 MP) / Heal (5 MP) /
  Run. Win gives XP; Kael levels up (more HP/MP/attack). Lose returns to
  the village at half HP.
- Save/load: JSON at `user://vaeloria_save.json` (level, XP, HP/MP, flags,
  spawn position). Save button in the village HUD, `S` key, auto-save on
  entering/exiting battle. Continue on the title screen.
- Spoken narration: real Godot 4.6 TTS via `DisplayServer.tts_speak()`
  (verified present in the 4.6 binary). Every dialogue and battle line is
  spoken when the platform has a TTS engine; on-screen text always shows
  too, so the game is fully playable without TTS. Toggle on the title.
- Original art + sounds: 12 pixel sprites + 5 sound effects, all generated
  programmatically with Python (PIL + wave). Generator kept at
  `assets/generate_assets.py`. Total assets ~85 KB. Project total is well
  under 50 MB.

## How to build (GitHub Actions)
- Workflow: `.github/workflows/build-apk.yml`
- It runs in the `barichello/godot-ci:4.6` container (Godot editor +
  export templates + Android SDK/JDK), imports the project, then exports a
  **debug** APK from the `Android` preset in `export_presets.cfg`
  (package `com.lynxosrpg.app`, app name "Vaeloria", arm64 only).
- The APK is uploaded as the `lynxos-rpg-apk` artifact. Sideload it on the
  tablet / TV to test.
- **Release signing TODO (parent):** debug APKs install fine for testing,
  but a public/store build needs the Lynxos keystore. Add the 4 repo
  secrets (KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_PASSWORD,
  KEY_ALIAS=lynxos), decode the keystore in a workflow step, and export
  in release mode with the `GODOT_ANDROID_KEYSTORE_*` env vars. Never
  paste keystore values into the workflow file.

## TV notes (Android TV / Google TV / Fire TV)
- Viewport is 960x540, stretch mode `canvas_items`, aspect `expand` — the
  game fills TV screens and stays readable.
- Everything is D-pad navigable: menus use Godot's built-in `ui_*` actions
  (arrows + D-pad + Enter/Space + joypad A). Village movement uses the
  same `ui_*` directions. Back / Esc returns to the title screen.
- HUD buttons are large (48-68 px tall) and the dialogue box uses 26 px
  text. No tiny touch-only controls: every action is reachable by D-pad.
- **Not yet confirmed on device:** the Leanback launcher entry. The game
  is fully D-pad navigable either way, but whether it appears in the TV
  launcher's app row (vs. sideloaded-apps only) needs a real on-device
  check after the first APK install. If it does not appear, enable the
  Leanback option in the Android export preset in the Godot editor and
  rebuild. Fire TV (Fire OS 7 / API 28) also needs an on-device check:
  Godot 4.6 targets newer APIs; the debug APK may install on Fire TV but
  this has NOT been tested.

## What was verified locally (this VM, 2026-11-16)
- Godot binary runs: `Godot_v4.6-stable_linux.x86_64 --version` →
  `4.6.stable.official.89cea1439`.
- TTS API confirmed present in the binary (`tts_speak`, `tts_stop`,
  `tts_is_speaking`, `tts_get_voices`). Note: in 4.6 `tts_speak`
  requires the voice argument — the code calls
  `DisplayServer.tts_speak(text, "")` (default voice). Found and fixed
  by the script checker.
- Full headless import: `godot --headless --path . --import --quit` →
  0 SCRIPT ERROR, 0 ERROR. (Per-script `--check-only` in isolation
  falsely flags autoload names like GameState/Narration and the global
  class DialogueBox — those resolve fine in the full project import.)
- Headless runs of all three scenes (240 frames each, title / village /
  battle): 0 SCRIPT ERROR, 0 ERROR. Two real bugs found and fixed by
  these runs: (1) `Camera2D.make_current()` called before the camera
  was inside the tree (village); (2) `GridContainer` has no `alignment`
  property (battle menu — wrapped in a CenterContainer instead).
- GameState logic test (temporary script, since removed): fresh game Lv 1,
  50/50 HP; +120 XP → Lv 2, 70 XP banked, 60/60 HP, attack 12; save →
  reset → load restores level, XP, flags and spawn position exactly.
  (One benign shutdown note in that test only: "1 resources still in
  use at exit" — the test harness's own un-freed node, not a game error.)
- All 12 sprites + 5 sounds verified present at the exact specified
  sizes/formats (see assets section above).

## What is NOT yet tested
- No Android APK has been produced locally (no Android SDK / export
  templates on this VM) — the first APK comes from GitHub Actions.
- No on-device playtest: tablet controls, TV D-pad, TTS voice on Android,
  battle flow, save/continue round-trip, and performance are all awaiting
  Justin's install + test.
- Export preset (`export_presets.cfg`) was hand-authored; the first
  GitHub Actions run is the real test of it.
