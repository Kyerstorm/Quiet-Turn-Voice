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
-- The battle-start and victory lines use Encount (1) and Result (12). Their labels are not
-- listed here; those rows are matched by the situation they shipped with instead.
--
-- Rows are matched by playLabel or shipped playSituation rather than row order, so a game
-- patch that reorders the table does not break the mod. Original values are cached by row
-- name the first time a row is seen, which lets every mode, Vanilla included, be reached
-- again without restarting the game. Situation matching has to use that cached value: once
-- a row is set to None, its live value no longer says what it was.
--
-- F7 shows the new mode on screen as a small widget built at runtime. PrintString would be
-- simpler, but it is compiled out of Shipping builds and draws nothing in this game. The
-- toast is optional: if any part of it fails, the log line still records the switch.
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
-- Situations, not labels: Encount (1) and Result (12).
local ENCOUNTER_VICTORY = { [1] = true, [12] = true }
local NO_SITUATIONS = {}

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
    [4] = { name = "Silent turns + skill select + bonus phase + encounter/victory",
            off = Set(TURN, SKILL_SELECT, BONUS_PHASE), offSituations = ENCOUNTER_VICTORY },
}
local MODE_COUNT = 5
local DEFAULT_MODE = 1
local CHECK_INTERVAL_MS = 2000
local TOAST_MS = 2500
-- Z-order for the toast, high enough to draw above the game's own HUD.
local TOAST_Z = 10000
-- ESlateVisibility values: shown without catching clicks, or taking no space at all.
local VISIBILITY_HIT_TEST_INVISIBLE = 3
local VISIBILITY_COLLAPSED = 1

-- Every label any mode can silence; only these rows are ever touched.
local TRACKED = Set(TURN, SKILL_SELECT, BONUS_PHASE)

local mode = DEFAULT_MODE
-- row name -> playSituation as shipped. Filled on first sight and never overwritten,
-- so a restore always goes back to the game's own value.
local original = {}
local reportedEncounterVictory = false
-- { widget, text } once built. Lua does not keep UObjects alive, and a level load removes
-- viewport widgets, so it is checked with IsValid before every use and rebuilt if needed.
local toast = nil
local toastBuilds = 0
-- Bumped on every show, so a hide timer from an earlier press does nothing.
local toastSerial = 0
local toastDisabled = false

local function Log(msg)
    print(MOD .. msg .. "\n")
end

local function ModeName()
    return "mode " .. mode .. " [" .. MODES[mode].name .. "]"
end

local function ToastText()
    return "Quiet Turn Voice - Mode " .. mode .. ": " .. MODES[mode].name
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

-- ForEachRow passes the row name as a plain Lua string; ToString covers an FName as well.
local function RowNameOf(name)
    if type(name) == "string" then return name end
    local ok, s = pcall(function() return name:ToString() end)
    if ok and type(s) == "string" then return s end
    return nil
end

-- Logs once which encounter/victory rows were found, so the log shows what mode 4 covers.
local function ReportEncounterVictory(labels, count)
    if reportedEncounterVictory or count == 0 then return end
    reportedEncounterVictory = true
    local list = {}
    for label in pairs(labels) do list[#list + 1] = label end
    table.sort(list)
    Log("found " .. count .. " encounter/victory row(s): " .. table.concat(list, ", "))
end

-- Brings every tracked row to the state the current mode wants.
-- Returns the number of rows changed, or nil if the table is not loaded.
local function Apply()
    local dt = FindTable()
    if not dt then return nil end
    local off = MODES[mode].off
    local offSituations = MODES[mode].offSituations or NO_SITUATIONS
    local changed = 0
    local seenLabels, seenCount = {}, 0
    dt:ForEachRow(function(name, row)
        local key = RowNameOf(name)
        if not key then return end
        local current = row.playSituation
        if original[key] == nil then original[key] = current end
        local shipped = original[key]
        local label = LabelOf(row)
        local byLabel = label and TRACKED[label]
        local bySituation = ENCOUNTER_VICTORY[shipped]
        if bySituation then
            seenCount = seenCount + 1
            seenLabels[label or "?"] = true
        end
        if byLabel or bySituation then
            local silence = (byLabel and off[label]) or (bySituation and offSituations[shipped])
            local want = silence and SITUATION_NONE or shipped
            if current ~= want then
                row.playSituation = want
                changed = changed + 1
            end
        end
    end)
    ReportEncounterVictory(seenLabels, seenCount)
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

local function FindClass(path)
    local cls = StaticFindObject(path)
    if not (cls and cls:IsValid()) then error("class not found: " .. path) end
    return cls
end

-- Builds the toast: a UserWidget whose tree is a dark Border holding one TextBlock.
-- The widget's outer is the GameInstance, which lives for the whole session.
local function BuildToast()
    local gi = FindFirstOf("GameInstance")
    if not (gi and gi:IsValid()) then error("no GameInstance yet") end
    toastBuilds = toastBuilds + 1
    local suffix = "_" .. toastBuilds
    local widget = StaticConstructObject(FindClass("/Script/UMG.UserWidget"), gi, FName("QTV_Toast" .. suffix))
    local tree = StaticConstructObject(FindClass("/Script/UMG.WidgetTree"), widget, FName("QTV_Tree" .. suffix))
    local border = StaticConstructObject(FindClass("/Script/UMG.Border"), tree, FName("QTV_Border" .. suffix))
    local text = StaticConstructObject(FindClass("/Script/UMG.TextBlock"), tree, FName("QTV_Text" .. suffix))
    widget.WidgetTree = tree
    tree.RootWidget = border
    border:SetBrushColor({ R = 0, G = 0, B = 0, A = 0.65 })
    border:SetPadding({ Left = 18, Top = 8, Right = 18, Bottom = 8 })
    border:SetContent(text)
    return { widget = widget, text = text }
end

local function ShowToastNow(msg)
    if not (toast and toast.widget:IsValid() and toast.text:IsValid()) then
        toast = BuildToast()
    end
    local widget = toast.widget
    toast.text:SetText(FText(msg))
    if not widget:IsInViewport() then
        widget:AddToViewport(TOAST_Z)
        -- Top-centre, a little below the edge, at any resolution.
        widget:SetAnchorsInViewport({ Minimum = { X = 0.5, Y = 0.06 }, Maximum = { X = 0.5, Y = 0.06 } })
        widget:SetAlignmentInViewport({ X = 0.5, Y = 0 })
    end
    widget:SetVisibility(VISIBILITY_HIT_TEST_INVISIBLE)
end

local function HideToast(serial)
    if serial ~= toastSerial then return end
    ExecuteInGameThread(function()
        if serial ~= toastSerial then return end
        pcall(function()
            if toast and toast.widget:IsValid() then
                toast.widget:SetVisibility(VISIBILITY_COLLAPSED)
            end
        end)
    end)
end

-- Shows msg on screen for TOAST_MS. A failure is logged once and the toast is then left
-- off for the session, so a UE4SS build without UMG support costs one log line.
local function ShowToast(msg)
    if toastDisabled then return end
    ExecuteInGameThread(function()
        local ok, err = pcall(ShowToastNow, msg)
        if not ok then
            toastDisabled = true
            toast = nil
            Log("overlay unavailable, mode switches are logged only: " .. tostring(err))
            return
        end
        toastSerial = toastSerial + 1
        local serial = toastSerial
        ExecuteWithDelay(TOAST_MS, function() HideToast(serial) end)
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
    ShowToast(ToastText())
    SafeApply("hotkey")
end)

LoadMode()
Log("loaded, " .. ModeName() .. ". Press F7 to cycle modes.")
