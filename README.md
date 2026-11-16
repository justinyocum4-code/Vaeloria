# Vaeloria — a Lynxos RPG

An original 2D turn-based RPG built with Godot 4.6. Inspired by the feel of
classic JRPGs (party, turn-based battles, epic story) — not a copy of any of
them. All characters, story, art and sounds are original.

- **World:** Vaeloria. **Kingdom:** Aldermere, powered by Emberstones.
- **Hero:** Kael Arden, 19, sword fighter. **Party:** Lyra Voss (mage),
  Mira Solenne (healer), Dax Rook (rogue).
- **Villain:** Lord Varik Kane, a fallen knight after the Emberstones.

## Play (v1.0 starter)
Title screen → Aldermere village → talk to Lyra, Mira and Dax → face the
Ember Wolf at the east gate or the Ember Slime by the pond. Win battles to
gain XP and level up. Save from the village HUD (or press S). Narration is
spoken aloud (Godot TTS) and shown on screen.

Controls: arrows / D-pad / WASD to walk, Enter / Space / A button to talk
and confirm, Back / Esc for the title screen, tap-to-move on touch screens.
Built for tablet and TV.

## Build
See `BUILD_NOTES.md`. GitHub Actions (`.github/workflows/build-apk.yml`)
exports a debug Android APK with Godot 4.6. Open the project in the Godot
4.6 editor to edit scenes and scripts.
