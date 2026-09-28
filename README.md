# SuperRPS

An auto-battler in the style of Hearthstone Battlegrounds, built on rock-paper-scissors.
Made with Godot 4.7. Targets Steam and mobile.

The rules are in [docs/RULES.md](docs/RULES.md).

## Layout

- `scripts/core/`: pure game logic. No nodes and no UI, so it's testable headless
  and can later be shared with P2P code.
  - `combat.gd`: resolves a fight between two boards
  - `player.gd`: player state and buy-phase actions (shop, inventory, tripling, leveling)
  - `weapon_pool.gd`, `mod.gd`, `mod_catalog.gd`: what shops can offer
  - `matchmaker.gd`: pairing with the rematch cooldown
  - `game.gd`: a whole lobby (rounds, ghosts, eliminations, placements)
  - `bot.gd`: simple AI for filling seats
- `tools/`: scripts like the balance simulator.
- `tests/`: headless tests for the core logic.

Game logic produces results and event logs. Scenes and UI read them and animate.
UI code never decides rules.

## Running tests

```bash
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
```

On Windows, use the `_console.exe` Godot build so the output shows in the terminal.
The `--import` step is only needed after adding new `class_name` scripts.

## Balance simulation

Plays all-bot games and prints game length, draw rate, damage and final levels:

```bash
godot --headless --path . -s res://tools/simulate.gd -- 500
```
