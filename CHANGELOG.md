# Changelog

## v1.2.0
**Added**
- **Mode 4 – Silent turns + skill select + bonus phase + encounter/victory:** everything mode 3 silences, plus the lines at the start of a battle and on victory. Handy when random battles are frequent.
- **On-screen mode popup:** pressing **F7** now shows the new mode at the top of the screen for a couple of seconds, so you no longer need the log to see which mode you're in.
- The log now lists which encounter/victory lines were found the first time the battle voice table loads.

**Fixed**
- Modes could fail to apply without any error in the log, so turn-start lines such as "My turn!" still played. The mod now reads the battle voice table's row names correctly, and every mode takes effect again.

**Upgrading from 1.1.0**
- Modes 0–3 are unchanged, so your saved mode carries over. Press **F7** past mode 3 to reach mode 4.

## v1.1.0
**Added**
- Bonus-phase voice lines can now be silenced. After a **Sweeping Stagger**, every party member gets an extra action, and each one used to play a voice line. They're now covered by the new mode 3.

**Changed**
- Modes are now a simple ladder; each one silences everything the one before it does, plus one more group:
  - **Mode 0 – Vanilla:** nothing silenced.
  - **Mode 1 – Silent turns (default):** all turn-start lines.
  - **Mode 2 – Silent turns + skill select:** also the bark when picking a skill.
  - **Mode 3 – Silent turns + skill select + bonus phase:** also the bonus-phase / Sweeping Stagger party lines.
- Still one key: **F7** cycles all modes.

**Removed**
- The "Situational only" mode, which turned off only the generic turn line.

**Upgrading from 1.0.0**
- Mode numbers have changed, so a saved mode from 1.0.0 may now select a different mode. After updating, press **F7** in-game to pick your mode again, or delete `ue4ss/Mods/QuietTurnVoice/mode.txt` to start from the default.

## v1.0.0
- Initial release.
- Silences the turn-start voice lines (e.g. "My turn!") for all playable characters, in English and Japanese.
- Four modes, cycled with **F7**: Vanilla, Situational only, Silent turns (default), and Silent turns + skill select.
- Your chosen mode is saved between sessions.
- No game files are modified; everything changes in memory while the game runs.
