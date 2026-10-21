# The Boss Fight — Prototype 0.1

A Godot 4.x top-down boss-fight prototype intended to test combat, cutscene timing, a two-phase boss, projectiles, melee, and visual effects. The project is deliberately a prototype, not a finished game/editor.

## Controls
- WASD / arrow keys: move
- Left mouse button: player revolver
- Space: melee attack
- R: restart encounter

## Prototype encounter
- Intro subtitles are placeholders and can be replaced in `scripts/main.gd` (`INTRO`). No original show audio is included.
- Phase 1: boss fires a spread of revolver shots.
- Phase 2 starts at 30% boss HP and adds telegraphed chemical explosive projectiles.
- Player has a ranged attack and melee attack.
- Arena, characters, bullets, explosions and UI are currently drawn in code as placeholder art. Replace with original pixel-art assets, animation frames, audio, real lighting and particles in later iterations.

## Architecture notes
- Local simulation state is separated conceptually from drawing and UI.
- Boss behaviour is isolated into functions that can later become per-boss scripts/resources.
- There is no networking in this version. IDs, authority, replication and prediction are not implemented; this is only a prototype seam for future multiplayer-friendly design.
- User-created mods should not execute arbitrary untrusted scripts without a sandbox or permission model.

## Open
Open `project.godot` in Godot 4.x. Android export requires Godot export templates and Android SDK/JDK configured locally or in CI. An APK has not been built or verified as part of this source package.

## Copyright note
The encounter uses a fan-test interpretation of a recognizable fictional character. For public release or commercial distribution, replace protected names, likeness, dialogue and distinctive character elements with original material or obtain the necessary rights.
