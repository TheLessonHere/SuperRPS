# SuperRPS Rules Spec

The source of truth for game rules. Tunable numbers live in
`scripts/core/game_config.gd`. Keep this doc and that file in sync.

## Lobby

- 6 players per lobby. Bots fill empty seats (and later, P2P queue gaps).
- Starting health: **25** (subject to change).
- Placement: top 3 gain Elo (weighted toward 1st); 4th–6th lose Elo.
- At game start each player picks 1 of 2 offered heroes. Each hero has a hero power.

## Player level (1–5)

Level sets:
- battle slots (= level)
- weapon slots in the shop (= level), plus 1 mod slot, always
- max weapon level offered in the shop (= level)
- strength of mods offered

Leveling up costs gold, like the Battlegrounds tavern upgrade:
- You can't level on turn 1 (the cost is higher than your gold).
- On turn 2 it's affordable but takes all your gold.
- Each level costs more than the last.
- Each turn you don't level, the current cost drops by 1.

## Buy phase

- Gold per turn: 3 on turn 1, then +1 per turn, capped at 10. Unspent gold doesn't carry over.
- Weapons cost 3g and sell for 1g.
- Mods cost 0g or more, and sell for 0g unless the mod says otherwise.
- Rolling the shop costs 1g.
- Inventory (hand) holds 10 items, weapons or mods. Purchases go to the inventory.
  If it's full, you can't buy until you sell something from the inventory or the board.
- Weapons can be played from the inventory into battle slots and moved between slots.
- Weapon mods attach to a weapon, 1 per weapon; applying a new mod replaces the old one.
  Shop mods affect the economy (sell for gold, grant weapons, etc.).
- Weapons come from a shared pool with roll odds that depend on level, like TFT and
  Battlegrounds. The numbers are still to be decided.

## Tripling

- 3 weapons of the **same type and same level**, counting both board and inventory,
  combine automatically into 1 weapon of that type one level higher (max Diamond).
- If more than one of the 3 has a mod, the player picks which mod to keep and the
  others are discarded.
- A triple also grants a **triple reward**: the player's choice of 1 mod, or 1 random
  weapon of level (player level + 1), capped at 5.

## Weapons

| Level | Name     | Durability |
|------:|----------|-----------:|
| 1     | (basic)  | 1 |
| 2     | Silver   | 2 |
| 3     | Gold     | 3 |
| 4     | Platinum | 4 |
| 5     | Diamond  | 5 |

Types: Rock, Paper, Scissors. Paper > Rock, Scissors > Paper, Rock > Scissors.

## Battle phase

- Each slot fights the opponent's slot straight across. Lanes are independent.
- Each swing costs both weapons 1 durability, whatever the outcome.
  - A win adds 1 to that player's win count.
  - A tie (same type) costs durability but adds no win to either player.
  - A weapon at 0 durability leaves the slot for the rest of the fight.
- A weapon swinging into an empty slot always wins, 1 win per swing, until its
  durability runs out.
- The fight ends when no weapon has durability left.
- **Extra slots:** for each battle slot (from level) a player has that the opponent
  doesn't, that player gets 1 free win, plus 1 more if a weapon is in that slot
  (max 2 per extra slot). Weapons in extra slots don't swing, so durability there
  doesn't matter.
- **Damage:** the loser takes (winner's wins − loser's wins) + winner's level.
  If the win counts are equal, nobody takes damage.
- Weapons return to full durability after the fight.

Worked example (both players at level 3):
P1 `[Scissors1, Rock1, Paper1]` vs P2 `[Rock1, Scissors2, Scissors2]`.
Lane 1: Rock beats Scissors → P2 +1.
Lane 2: Rock beats Scissors, then the Rock is gone and Scissors swings into empty → 1–1.
Lane 3: Scissors beats Paper, then swings into empty → P2 +2.
Total 1–4. P1 takes 3 + 3 = **6** damage.

## Pairing

- Opponents are random, but you can't face the same opponent again within 3 fights.
- With an odd number of living players, one player fights a **ghost**: a copy of the
  most recently eliminated player's board.

## Implementation decisions (placeholders; change if they feel wrong)

- **Shop:** a bought weapon leaves an empty shop slot until the next roll. Unbought
  offers go back to the pool on each roll and at the start of each turn. Leveling
  up doesn't refresh the shop; the new slot appears on the next roll.
- **Pool:** each weapon level is drawn by the odds for your player level. Within a
  level, the type is weighted by copies left. Sold weapons return 1 copy of their
  level, never above the starting count. Weapons consumed by a triple don't return.
- **Mods** aren't pooled; the shop's mod slot offers any mod with tier ≤ player level.
- **Triple placement:** if any of the 3 were on the board, the new weapon takes the
  leftmost of their slots; otherwise it goes to the inventory.
- **Triple reward:** the mod and the weapon are both rolled when the triple happens.
  The one you don't pick is discarded; an unpicked weapon goes back to the pool.
- **Pending choices** (which mod to keep, triple reward) block everything except
  selling and choosing. If the buy phase ends first, they auto-resolve: first mod,
  and the weapon reward. A reward with no inventory room is forfeited.
- **Simultaneous eliminations** are placed by health: the least negative places
  highest and becomes the ghost.
- **Round cap:** after `MAX_ROUNDS` (50), the remaining players are ranked by health.
  This is a safety net; see the stall note below.
- **Odd lobby with no one eliminated yet** (only possible in custom lobby sizes):
  one random player sits the round out.

## Open questions / assumptions

- **Late-game draws:** when both boards are all Diamond, each lane goes 5–0 or 0–0,
  so evenly matched boards draw a lot (about 22% of all fights in bot sims). Worth
  watching once mods and heroes exist.

- **Pool:** copies per weapon per level, and roll odds per player level.
- **Level-up base costs:** placeholders `[5, 7, 8, 9]` for levels 2–5.
- **Buy-phase timer length.**
- **Mod and hero lists.**
