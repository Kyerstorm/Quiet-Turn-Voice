# QuietTurnVoice

A UE4SS Lua mod for **FINAL FANTASY RESONANCE** that stops characters saying a line ("my turn") at the start of every battle turn, and can also silence skill-select barks and the party lines that play during the bonus phase after a **Sweeping Stagger**, and, in mode 4, the battle-start and victory lines. Story, skill and damage voices are untouched. **F7** cycles modes in-game.

| Mode | What is silenced |
|---|---|
| 0 Vanilla | Nothing, as shipped |
| **1 Silent turns** (default) | All turn-start lines |
| 2 Silent turns + skill select | Also the bark when picking a skill |
| 3 Silent turns + skill select + bonus phase | Also the lines spoken when party members take their bonus-phase action, including every member's action after a Sweeping Stagger |
| 4 Silent turns + skill select + bonus phase + encounter/victory | Also the lines at the start of a battle and on victory |

Each mode silences everything the one before it does, plus one more group. The chosen mode is saved to `QuietTurnVoice/mode.txt` and restored on the next launch.

## How it works
Battle voices are chosen from the DataTable `/Game/Datatable/Battle/Sound/DT_BtlVoiceData`. The turn-start lines are the rows labelled `VO_BTL_CMD_01_`–`VO_BTL_CMD_04_` (situation `BeginCmd`), and the skill-select barks are `VO_BTL_CMD_11_`/`12_` (situation `SkillSelect`). The bonus-phase lines are `VO_BTL_EXP_01_`–`VO_BTL_EXP_03_` (situation `OpenExCmd`; "Ex" is the game's internal name for the bonus phase). A Sweeping Stagger gives every party member a bonus action, which is why those lines play once per member. Battle-start and victory lines are every row whose shipped situation is `Encount` or `Result`; they are matched by situation rather than label. The mod sets the selected rows' `playSituation` to `None` in memory, so the game never requests them. No game files are modified. Rows are matched by label, so the mod keeps working if a patch reorders the table.

## Requirements
- **UE4SS v4** (a release supporting UE 5.6) from the official project: https://github.com/UE4SS-RE/RE-UE4SS/releases
- No other mod tools are required.

## Install
1. Extract UE4SS into `<game>/FFRS/Binaries/Win64/`. You should end up with `dwmapi.dll` and a `ue4ss/` folder next to `FFRS-Win64-Shipping.exe`.
   - UE4SS uses `dwmapi.dll`, so it does not conflict with ReShade/Luma's `dxgi.dll`.
2. Copy the `QuietTurnVoice` folder into `<game>/FFRS/Binaries/Win64/ue4ss/Mods/`.
3. Enable it **one** way only: either add `QuietTurnVoice : 1` to `ue4ss/Mods/mods.txt` (above the `Keybinds` line) and delete the mod's `enabled.txt`, or leave `enabled.txt` in place and don't list it in `mods.txt`. If it's enabled both ways, F7 can register twice and skip modes.
4. Launch the game. `ue4ss/UE4SS.log` should show `[QuietTurnVoice] loaded, mode 1 [Silent turns]`.

## Uninstall
Delete `ue4ss/Mods/QuietTurnVoice/`. To remove UE4SS entirely, delete `dwmapi.dll` and `ue4ss/` from `Win64`.

## Troubleshooting
- **Nothing changes in battle:** check `UE4SS.log` for `[QuietTurnVoice] mode ... applied`. If that line never appears, the table was not found (a patch may have renamed it).
- **F7 mid-battle doesn't take effect until the next battle:** the game may read the table when a battle starts; the mode still applies from the next battle.
- **`apply failed` in the log:** the UE4SS build may not support DataTable editing (`ForEachRow` needs UE4SS v4). Update UE4SS.
