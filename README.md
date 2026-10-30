# The Boss Fight — Prototype 0.2

A Godot 4 top-down boss-fight prototype with two phases, projectile combat, melee, basic visual effects and touch controls on Android.

## Controls
- PC: WASD / arrow keys to move, left mouse button to shoot, Space for melee, R to restart.
- Android: on-screen directional buttons, FIRE, HIT and RETRY.

## Build
Open `project.godot` in Godot 4.4.1 or build the Android APK via GitHub Actions. The workflow installs the matching Godot export templates, JDK 17 and Android SDK, performs a headless import/smoke check, then exports and uploads `TheBossFight.apk` as an Actions artifact.

## Important
The project remains a prototype. Its art and encounter dialogue are placeholders. No multiplayer networking is implemented. The Android workflow has been updated but this package has not been run in the Godot engine in this environment; a green GitHub Actions run is required to confirm the APK export succeeds.
