# OMA ENGINE

> A no-code 2D RPG game engine built with Flutter — design, build, and export games without writing a single line of code.

---

## What is OMA Engine?

OMA Engine is a visual game editor and engine for creating top-down 2D RPG games on Windows. It gives non-programmers a complete set of tools to design maps, place characters, define game behavior with visual rules, import sprites and audio, and export a fully playable standalone game — all from one app.

No external tools. No coding required. Just build and play.

---

## Features

### Map Editor
- Grid-based tile painting with left-click drag
- Erase tiles with right-click
- Tile variants — multiple visual versions per tile type
- Collision tool — mark tiles as solid or passable
- Zoom and pan the canvas freely
- Show/hide grid toggle
- Multiple maps per project — switch between them instantly

### Objects & Characters
- Place game objects on the map: **Player Spawn, Enemy, NPC, Coin, Chest, Door**
- Custom sprites per object type
- Spritesheet animation support with frame slicing preview
- Floating, dash, and projectile motion effects
- Sprite alpha (transparency) control

### Visual Rules System (No-Code Logic)
- **When → Then** rule builder
- Triggers: on collision, on key press, on proximity, on game start, and more
- Actions: move player, show message, play sound, switch map, spawn object, and more
- Rules are attached per object — no scripting needed

### Play Mode
- Test your game directly inside the editor
- WASD / Arrow key movement
- Tile-based collision detection
- HUD display
- Game events fire in real time

### Audio
- Import background music (MP3/WAV/OGG)
- Import sound effects
- Rule actions: Play Music, Play SFX, Stop Music

### Sprite & Asset Import
- Import custom sprites per object type
- Import tile sprites with variant support
- Import spritesheets with configurable frame size and count
- Animated sprites driven by frame rate settings

### Project System
- Folder-based project structure (`project.json` + `maps/` folder)
- Multi-map projects with a defined start map
- In-memory map cache — switch maps without losing unsaved work
- Unsaved changes indicator with save/discard confirmation
- Window close guard — never lose work by accident

### Export
- **Export .exe** — packages your game as a standalone Windows executable using the pre-built OMA Runtime. No Flutter SDK needed on the player's machine.
- **Export .apk** — packages your game as an Android APK, ready to install on any Android device.

---

## Getting Started

### Download
Go to [Releases](../../releases) and download the latest `OMA_Engine_Windows.zip`.

### Run
1. Unzip the downloaded file
2. Run `oma_engine.exe`
3. No installation required

### Create Your First Game
1. Click **New** in the toolbar
2. Set your project name, map size, and tile size
3. Paint tiles on the canvas using the left panel palette
4. Switch to the **Objects** tab and place a **Player Spawn**
5. Add enemies, coins, and doors as needed
6. Open the **Rules** tab on the right panel to define behavior
7. Press **Play** to test your game in the editor
8. Click **Export .exe** to build a standalone game

---

## Project Folder Structure

```
MyGame/
  project.json       — project settings (name, maps, start map)
  maps/
    level_1.json     — map tile data, objects, rules
    level_2.json
  music/             — imported background music
  sfx/               — imported sound effects
  fonts/             — custom fonts (future)
```

---

## System Requirements

| | Minimum |
|---|---|
| OS | Windows 10 / 11 (64-bit) |
| RAM | 4 GB |
| Storage | 200 MB |

---

## Roadmap

- [ ] Start screen for exported games
- [ ] Pause screen (Escape key)
- [ ] Global variables (lives, score, inventory)
- [ ] Save/load player data between sessions
- [ ] Font import
- [ ] Isometric map support

---

## License

MIT License — see [LICENSE](LICENSE) for details.
