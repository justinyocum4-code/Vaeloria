# Vaeloria — Build notes

## v1.1.4 (Nov 16, 2026) — Real voices + moving mouths
- Justin's report on v1.1.3: "For the movie scene the characters mouth needs to be moving at all so I think they need real voices and not the accessibility voice speaking for them." Root cause, two parts: (1) the movie clips are fixed footage — no mouth in them can ever move, whatever the voice; (2) the lines were spoken by the device accessibility voice (TTS), not a character's voice.
- Fix: the talk moved OUT of the movie and into the close-up, where the characters are live 3D models. (a) REAL VOICES: every dialogue line is now a recorded voice clip, generated free with Piper (local neural TTS, no account, no card) and baked into the game as `assets/voices/*.ogg` (10 lines, ~350 KB total). A different voice per character: Lyra = en_US-amy-medium (woman), Maren = en_US-joe-medium (older man), Kael = en_US-ryan-medium (young man). Edge TTS was tried first and is BLOCKED from this sandbox (SSL failure to speech.platform.bing.com), so Piper is the voice path. (b) MOVING MOUTHS: `MeshFactory.make_humanoid` now builds a face — two eyes and a mouth (thin dark box) on the front of the head — and `MeshFactory.set_mouth_open(root, amount)` scales the mouth's height. While a voice line plays, the dialogue scene flaps the speaker's mouth open/closed every 0.12 s (random open amount). It moves in time with the talking, NOT per syllable — a flap, not true lip-sync; real lip-sync would need a paid talking-head service. (c) CAMERA: the close-up now frames the SPEAKER from the front-side (three-quarter view) instead of the old straight side shot, which hid the mouth entirely (profile view). The listener stands behind the speaker, in shot. (d) STRUCTURE: the movie clip is now only a silent 4-second establishing shot (the clip's first seconds), then it cuts to the close-up talk. Skipping the shot goes straight to the talk; only skipping the talk itself cancels it. The wolf's line is Kael speaking, so it is labeled Kael, voiced by Kael's voice, and Kael's mouth moves (the wolf has no mouth). If a voice file is ever missing, that line falls back to the device TTS voice + word-count timer, so a talk never goes silent.
- Dialogue fix folded in: Lyra's 3rd line no longer says "Lyra Voss joined the party!" in her own voice (third person, and `_finish_talk()` already announces it via Narration right after). It is now just "The east gate is that way — the Ember Wolf is waiting." Repeat lines got their own voice files (maren_04, lyra_04, kael_02) — the voice key offsets past the first-talk lines so a repeat never plays the wrong clip.
- Files: new `assets/voices/*.ogg` (10 files), changed `scripts/mesh_factory.gd` (face + set_mouth_open), `scripts/cutscene_dialogue.gd` (voice player, flap timer, Narration fallback), `scripts/video_cutscene.gd` (rewritten as a plain establishing-shot player; the v1.1.3 lines/subtitle machinery is gone), `scripts/village_3d.gd` (4 s establishing shot, speaker-framed camera, voice keys, wolf speaker = Kael, Lyra line 3), `export_presets.cfg` (1.1.4/8).
- Headless test: /tmp/test_vaeloria_114.gd (frame-counted SceneTree, no awaits in _init; project scripts loaded at runtime via load()). Run: `godot --headless --path . -s /tmp/test_vaeloria_114.gd`.
- Scope: LEVEL 1 ONLY (Aldermere village + Ember Wolf battle). Other regions are parked until Level 1 is down.

## v1.1.3 (Nov 16, 2026) — Talking movie scenes
- Justin's report on v1.1.2: "The movie scenes play fine but in the game I want them to speak their lines like if they were talking." Root cause: the movie clips were silent by design (no audio track) and the talking only happened AFTER the movie, in the letterbox dialogue scene — so the movie itself felt like a silent film.
- Fix: the lines moved INTO the movie. `scripts/video_cutscene.gd` now takes the talk's lines and, while the clip plays, speaks each line aloud (device TTS via Narration, same voice as the dialogue scene) and shows it as a subtitle at the bottom (speaker name in gold, line in large white text, movie-caption style). The 10-second clip loops until the lines are done — Maren and Lyra have 3 lines each, about 20 seconds of talking, so the clip plays about twice. When the last line finishes, the talk is complete right there (Lyra joins, the wolf fight starts) and the lines are NOT repeated afterwards. Tap / Enter / Back still skips the movie, and skipping now falls back to the letterbox dialogue scene so the talk is never lost — only skipping the dialogue itself cancels it. A missing clip file also falls back to the dialogue (emits skipped, not finished) so a bad video never eats the lines. With no lines at all the scene behaves as before (ends when the clip ends).
- Files: rewritten `scripts/video_cutscene.gd`, changed `scripts/village_3d.gd` (passes lines to the movie; video-finished now completes the talk via `_finish_talk()`; new `_cutscene_lines()` helper shared by the movie and the dialogue scene), `export_presets.cfg` (1.1.3/7).
- Headless test: /tmp/test_vaeloria_113.gd (frame-counted SceneTree, no awaits in _init; project scripts loaded at runtime via load()). Run: `godot --headless --path . -s /tmp/test_vaeloria_113.gd`.
- Scope: LEVEL 1 ONLY (Aldermere village + Ember Wolf battle). Other regions are parked until Level 1 is down.

## v1.1.2 (Nov 16, 2026) — Movie scenes + game music
- NEW: full-screen movie scenes (Justin's ask: talking to characters and approaching bosses should feel like a real movie). Three AI-generated cinematic video clips, 10 s each, 960x540: Lyra in the village square (ember-red hair, flame in her palm), Elder Maren at the glowing rune shrine, the Ember Wolf bursting through the east gate. They play via a new `scripts/video_cutscene.gd` (VideoStreamPlayer, Theora .ogv) BEFORE the spoken dialogue scene: tap a character (or walk up to the wolf) → movie plays → dialogue scene → (wolf) battle. Tap / Enter / Back skips the movie; skipping the movie never cancels the talk, only skipping the dialogue does. The wolf's movie ALSO triggers on approach (within 4 units of the gate), with the trigger resetting when Kael walks 7+ units away. Real film clips are not possible (copyright) — these are original AI-generated scenes, not footage from any movie.
- NEW: game music — there was none at all before. `scripts/music_manager.gd` autoload (`Music`): calm village theme in the village and on the title screen, tense battle theme in battle. Tracks: Kevin MacLeod "Meditation Impromptu 01" (village, ~3:33) and "Five Armies" (battle, ~2:36), CC-BY 4.0, credited in the title screen footer. Converted to Vorbis .ogg (q3). Loops are done by hand (replay on `finished`) with a 2-second fade-out at the end and fade-in after the restart, so the loop point never pops. Switching tracks never restarts a track that is already playing.
- Files: new `assets/cutscenes/cutscene_{lyra,maren,wolf}.ogv` (~4 MB each, Theora q6, 960x540, no audio track), new `assets/music/music_{village,battle}.ogg` (~2.1 MB each), new scripts `video_cutscene.gd` + `music_manager.gd` (autoload), changed `village_3d.gd` (video layer 40, approach trigger, music start), `battle_3d.gd` (battle music), `title.gd` (village music + credit line), `project.godot` (Music autoload), `export_presets.cfg` (1.1.2/6). APK grows ~17 MB (was ~26 MB, now ~43 MB).
- Headless test: /tmp/test_vaeloria_112.gd (frame-counted SceneTree, no awaits in _init; project scripts loaded at runtime via load()). Run: `godot --headless --path . -s /tmp/test_vaeloria_112.gd`.
- Scope: LEVEL 1 ONLY (Aldermere village + Ember Wolf battle). Other regions are parked until Level 1 is down.

## v1.1.1 (Nov 16, 2026) — Level 1 polish: tap-to-talk fix, cinematic dialogue, richer graphics
- BUG FIX (reported by Justin on v1.1.0): explore-by-touch spoke names fine, but tapping a character did nothing — no dialogue, game could not move on. Root cause: pressing on ANYTHING started tap-to-move, so Kael walked and the camera followed before the finger lifted, and the release-position raycast no longer pointed at the character (the NPC capsule is only ~25-40 px on screen). Fix: the tap is now judged by the pick at the PRESS position, a press on a character never starts tap-to-move, tolerance raised 48px -> 64px, drags that start on a character are explore-only, and the raycast excludes Kael's own body (it could block the ray up close). Fallback: when Kael stands near someone, a big tappable "Talk: <name>" button appears (Enter / A still works too).
- NEW: cinematic dialogue (`scripts/cutscene_dialogue.gd`). Talking to an NPC cuts to a movie-like scene: the camera sweeps in close on Kael and the NPC facing each other, letterbox bars slide in, each line is SPOKEN aloud automatically and auto-advances on a timer estimated from word count (no TTS callbacks — unreliable headless). Tap or Enter advances now; Back or Skip exits early, and skipping does NOT count (Lyra does not join, the wolf does not attack — the player can talk again). Same dialogue content as before (Elder Maren's Emberstone explanation, Lyra's recruitment). The opening narration still uses the text box; the battle victory overlay is unchanged. NO engine switch: Unity was considered and rejected (starting over, new account/license, a build pipeline we do not have) — the graphics gap is art detail, closed with richer Godot primitives instead.
- GRAPHICS (Level 1 only): houses gained door frames + handles, window shutters, roof overhangs, stone steps, chimney caps and smoke puffs; new market stall (striped canopy, fruit, bread basket) and stone well; 14 flowers, 10 grass tufts, stepping stones along both roads, ground color patches and bushes; pond glints that bob; 4 village torches + 2 arena torches with flicker; ember motes rising around the shrine crystal; warmer golden-hour sky, warmer sun with softer shadows, and soft glow (WorldEnvironment glow, supported under the Compatibility renderer — verified in the headless test; if it ever causes trouble on a device, switch it off first). Primitive counts stay modest for tablet / Fire TV Stick.
- Headless test: /tmp/test_vaeloria_111.gd (frame-counted SceneTree, no awaits in _init; project scripts loaded at runtime via load()). Run: `godot --headless --path . -s /tmp/test_vaeloria_111.gd`.
- Scope: LEVEL 1 ONLY (Aldermere village + Ember Wolf battle). Other regions are parked until Level 1 is down.

## v1.1.0 (Nov 16, 2026) — Phase 1: the 3D engine
- The game is now 3D. Aldermere village rebuilt as a walkable 3D world (48x36 units): 5 gold-trimmed houses, trees, pond, fences, east gate, and a lit Emberstone shrine in the center. All art is stylized low-poly built from Godot primitives in code (`scripts/mesh_factory.gd`) — no textures, cheap enough for a tablet and an old Fire TV Stick.
- Player: CharacterBody3D Kael, speed 5, D-pad/arrows/WASD + tap-to-move. Fixed camera rig follows behind and above at ~35 degrees down with light smoothing — no free camera rotation. DirectionalLight3D with shadows, procedural sky, light fog. Rendering is already `gl_compatibility` for both desktop and mobile in project.godot (unchanged).
- NPCs: Elder Maren (quest giver, explains the Emberstones, points to the east gate) and Lyra Voss (fire/lightning mage — talking to her recruits her into the party; she then fights beside Kael in battle with her own Firebolt). Mira Solenne and Dax Rook are NOT in this phase; they join in later regions.
- One 3D battle: the Ember Wolf at the east gate (talk to it, then battle). New `scenes/battle_3d.tscn` + `scripts/battle_3d.gd`: 3D arena with Kael (+ Lyra if recruited) vs the wolf model, same mechanics as the 2D battle (Attack / Magic: Firebolt / Heal / Run, 30 XP, enemy 8-12 damage). The menu/log are a Control overlay reusing the 2D layout lessons (compact sizes, ScrollContainer safety net, result button on screen, victory line says "Press Return to Village to continue.", Back returns to the village).
- Built-in explore-by-touch in 3D (`scripts/explore_touch_3d.gd`): dragging a finger raycasts from the camera into the world and speaks the label under it (houses, trees, NPCs, wolf, shrine), only when the hovered object changes. Tapping (release within 48px) on an NPC talks to them; tapping the wolf starts the battle. Village tap-to-talk is tap-on-release so dragging only explores. Dialogue still uses the 2D `dialogue_box.gd` overlay.
- Title screen kept (2D) but New Game / Continue now point at `scenes/village_3d.tscn`. GameState gained `spawn_pos_3d` (Vector3, saved as spawn3d_x/y/z); old 2D saves from v1.0.x do NOT carry over — a v1.0.x save loads with level/XP/flags but spawns at the 3D village start. The 2D scenes (village.tscn, battle.tscn) and their scripts stay in the repo unused.
- Headless test: /tmp/test_vaeloria_3d.gd (frame-counted SceneTree, no awaits in _init). Run: `godot --headless --path . -s /tmp/test_vaeloria_3d.gd`.
- Known Phase 1 limits: fences have collision but the player can walk around their ends; the wolf has no wandering AI (it waits at the gate); no shops/inns/side quests yet (Phase 2).

## v1.0.2 (Nov 16, 2026) — battle freeze + back button + touch exploration
- BUG: after winning a battle the screen looked frozen with no Continue button. Cause: the battle layout was ~636 units tall on a 540-unit screen, so the "Return to Village" button sat below the fold. Fix: compacted the layout (smaller sprite/log/margins, now ends ~520) + a ScrollContainer safety net + the button scrolls itself into view and the victory line now says "Press Return to Village to continue." Verified headless: result button rect bottom 520 <= 540.
- BUG: Android Back in battle quit the whole game (no handler). Fix: battle and village now handle both ui_cancel and NOTIFICATION_WM_GO_BACK_REQUEST — back returns to the village (battle) or the title (village, closing dialogue first). Title keeps the default (back quits).
- NEW: built-in explore-by-touch (`scripts/explore_touch.gd`). Drag a finger across any screen and the game reads aloud whatever is under it (buttons, NPCs, enemies) via its own narration — no device accessibility needed. Village tap-to-talk moved from touch-press to tap-on-release so dragging across an NPC only speaks its name; a deliberate tap talks. Dialogue text can be tapped to hear the line again.
- Headless test: /tmp/test_vaeloria.gd (frame-counted SceneTree, no awaits in _init — those deadlock headless). Run: `godot --headless --path . -s /tmp/test_vaeloria.gd`.
- Future direction (Justin's call Nov 16): 3D version later; 2D is fine for now.

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
