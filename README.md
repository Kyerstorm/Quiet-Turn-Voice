# QuietTurnVoice

A UE4SS Lua mod for **FINAL FANTASY RESONANCE** that stops characters saying a line ("my turn") at the start of every battle turn. Story, skill, damage and victory voices are untouched. **F7** cycles modes in-game.

| Mode | What you hear at turn start |
|---|---|
| 0 Vanilla | Everything, as shipped |
| 1 Situational only | The generic every-turn line is off; rarer situational turn lines remain |
| **2 Silent turns** (default) | No turn-start lines |
| 3 Silent turns + skill select | Also no bark when picking a skill |

The chosen mode is saved to `QuietTurnVoice/mode.txt` and restored on the next launch.

## How it works
Battle voices are chosen from the DataTable `/Game/Datatable/Battle/Sound/DT_BtlVoiceData`. The turn-start lines are the rows labelled `VO_BTL_CMD_01_`–`VO_BTL_CMD_04_` (situation `BeginCmd`), and the skill-select barks are `VO_BTL_CMD_11_`/`12_` (situation `SkillSelect`). The mod sets the selected rows' `playSituation` to `None` in memory, so the game never requests them. No game files are modified. Rows are matched by label, so the mod keeps working if a patch reorders the table.

## Requirements
- **UE4SS v4** (a release supporting UE 5.6) from the official project: https://github.com/UE4SS-RE/RE-UE4SS/releases
- No other mod tools are required.

## Install
1. Extract UE4SS into `<game>/FFRS/Binaries/Win64/`. You should end up with `dwmapi.dll` and a `ue4ss/` folder next to `FFRS-Win64-Shipping.exe`.
   - UE4SS uses `dwmapi.dll`, so it does not conflict with ReShade/Luma's `dxgi.dll`.
2. Copy the `QuietTurnVoice` folder into `<game>/FFRS/Binaries/Win64/ue4ss/Mods/`.
3. Enable it **one** way only: either add `QuietTurnVoice : 1` to `ue4ss/Mods/mods.txt` (above the `Keybinds` line) and delete the mod's `enabled.txt`, or leave `enabled.txt` in place and don't list it in `mods.txt`. If it's enabled both ways, F7 can register twice and skip modes.
4. Launch the game. `ue4ss/UE4SS.log` should show `[QuietTurnVoice] loaded, mode 2 [Silent turns]`.

## Uninstall
Delete `ue4ss/Mods/QuietTurnVoice/`. To remove UE4SS entirely, delete `dwmapi.dll` and `ue4ss/` from `Win64`.

## Troubleshooting
- **Nothing changes in battle:** check `UE4SS.log` for `[QuietTurnVoice] mode 2 ... applied`. If that line never appears, the table was not found (a patch may have renamed it).
- **F7 mid-battle doesn't take effect until the next battle:** the game may read the table when a battle starts; the mode still applies from the next battle.
- **`apply failed` in the log:** the UE4SS build may not support DataTable editing (`ForEachRow` needs UE4SS v4). Update UE4SS.
