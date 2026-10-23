-- QuietTurnVoice: silences repetitive battle voice lines in FINAL FANTASY RESONANCE.
--
-- The lines come from DT_BtlVoiceData, where each row has a playSituation. The turn-start
-- rows use BeginCmd (2) and the labels VO_BTL_CMD_01_ to VO_BTL_CMD_04_; the skill-select
-- barks use SkillSelect (3) with VO_BTL_CMD_11_ and VO_BTL_CMD_12_. The bonus-phase lines
-- use OpenExCmd (4) with VO_BTL_EXP_01_ to VO_BTL_EXP_03_: "Ex" is the game's name for the
-- bonus phase, and a sweeping stagger (FullBreak internally) gives every party member a
-- bonus action, so those lines play once per member. Setting a row's playSituation to
-- None (0) means no situation ever asks for it, so it never plays.
-- probabilityWithinSituation is a weight between candidates, not a gate, so it is left alone.
--
-- Rows are matched by playLabel rather than row name or order, so a game patch that reorders
-- the table does not break the mod. Original values are cached the first time a row is seen,
-- which lets every mode, Vanilla included, be reached again without restarting the game.
--
-- No path in this file contains a backslash: paths use forward slashes, which Windows
-- accepts, and string.char(92) stands in where a backslash has to be matched. A stray
-- backslash in a path string is an invalid escape, and Lua then refuses the whole file.

local MOD = "[QuietTurnVoice] "
local TABLE_PATH = "/Game/Datatable/Battle/Sound/DT_BtlVoiceData.DT_BtlVoiceData"
local SITUATION_NONE = 0

local TURN = { "VO_BTL_CMD_01_", "VO_BTL_CMD_02_", "VO_BTL_CMD_03_", "VO_BTL_CMD_04_" }
local SKILL_SELECT = { "VO_BTL_CMD_11_", "VO_BTL_CMD_12_" }
local BONUS_PHASE = { "VO_BTL_EXP_01_", "VO_BTL_EXP_02_", "VO_BTL_EXP_03_" }

-- Builds a label set from any number of label lists.
local function Set(...)
    local s = {}
    for _, list in ipairs({ ... }) do
        for _, label in ipairs(list) do s[label] = true end
    end
    return s
end

-- Each mode silences everything the one before it does, plus one more group.
local MODES = {
    [0] = { name = "Vanilla (all lines play)", off = {} },
    [1] = { name = "Silent turns", off = Set(TURN) },
    [2] = { name = "Silent turns + skill select", off = Set(TURN, SKILL_SELECT) },
    [3] = { name = "Silent turns + skill select + bonus phase", off = Set(TURN, SKILL_SELECT, BONUS_PHASE) },
}
local MODE_COUNT = 4
local DEFAULT_MODE = 1
local CHECK_INTERVAL_MS = 2000

-- Every label any mode can silence; only these rows are ever touched.
local TRACKED = Set(TURN, SKILL_SELECT, BONUS_PHASE)

local mode = DEFAULT_MODE
-- playLabel -> playSituation as shipped. Filled on first sight and never overwritten,
-- so a restore always goes back to the game's own value.
local original = {}

local function Log(msg)
    print(MOD .. msg .. "\n")
end

local function ModeName()
    return "mode " .. mode .. " [" .. MODES[mode].name .. "]"
end

-- The mode file sits beside this mod's Scripts folder.
local function ModeFilePath()
    local here = debug and debug.getinfo and debug.getinfo(1, "S")
    local src = ((here and here.source) or ""):gsub(string.char(92), "/")
    local scripts = src:match("^@(.*)/[^/]+$")
    if not scripts then return nil end
    return scripts .. "/../mode.txt"
end

local function LoadMode()
    local path = ModeFilePath()
    local f = path and io.open(path, "r")
    if not f then return end
    local n = tonumber((f:read("*l") or ""):match("%d+"))
    f:close()
    if n and MODES[n] then mode = n end
end

local function SaveMode()
    local path = ModeFilePath()
    local f = path and io.open(path, "w")
    if not f then
        Log("could not write mode.txt, the mode will reset to the default next launch")
        return
    end
    f:write(tostring(mode) .. "\n")
    f:close()
end

local function FindTable()
    local ok, dt = pcall(StaticFindObject, TABLE_PATH)
    if ok and dt and dt:IsValid() then return dt end
    return nil
end

local function LabelOf(row)
    local ok, s = pcall(function() return row.playLabel:ToString() end)
    if ok and type(s) == "string" then return s end
    return nil
end

-- Brings every tracked row to the state the current mode wants.
-- Returns the number of rows changed, or nil if the table is not loaded.
local function Apply()
    local dt = FindTable()
    if not dt then return nil end
    local off = MODES[mode].off
    local changed = 0
    dt:ForEachRow(function(_, row)
        local label = LabelOf(row)
        if label and TRACKED[label] then
            local current = row.playSituation
            if original[label] == nil then original[label] = current end
            local want = off[label] and SITUATION_NONE or original[label]
            if current ~= want then
                row.playSituation = want
                changed = changed + 1
            end
        end
    end)
    return changed
end

local function SafeApply(reason)
    ExecuteInGameThread(function()
        local ok, result = pcall(Apply)
        if not ok then
            Log("apply failed (" .. reason .. "): " .. tostring(result))
        elseif result and result > 0 then
            Log(ModeName() .. " applied (" .. reason .. "): " .. result .. " row(s) changed")
        end
    end)
end

-- The table can load lazily at battle start and be unloaded again afterwards, so a quiet
-- periodic check re-applies the mode whenever the table is found in its shipped state.
-- Apply only writes rows that differ, so a check that finds nothing to do costs one lookup.
LoopAsync(CHECK_INTERVAL_MS, function()
    SafeApply("table check")
    return false
end)

RegisterInitGameStatePostHook(function()
    SafeApply("level load")
end)

RegisterKeyBind(Key.F7, function()
    mode = (mode + 1) % MODE_COUNT
    SaveMode()
    Log("F7: switched to " .. ModeName())
    SafeApply("hotkey")
end)

LoadMode()
Log("loaded, " .. ModeName() .. ". Press F7 to cycle modes.")
