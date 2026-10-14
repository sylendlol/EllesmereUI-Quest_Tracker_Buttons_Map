-------------------------------------------------------------------------------
--  EllesmereUI_QTBackgroundFix  (standalone add-on, no EllesmereUI file edited)
--
--  The bug (EllesmereUIQuestTracker_Visibility.lua, present in 9.4 and 9.5.4):
--   1) ResizeBGToContent: when the tracker empties, it keeps the background at
--      its last size and schedules a 0.2s re-check -- but the re-check lands in
--      the same branch (bg._lastLowest is never cleared), re-arms itself and
--      never hides. The empty background stays until some unrelated pass
--      (e.g. a target change) runs the visibility code again.
--   2) SyncBGToTracker Show()s the background on every zone change / loading
--      screen, content or not.
--   3) Blizzard can hide an emptied module after EUI's last resize pass
--      without firing anything EUI listens to.
--
--  The fix watches EUI's own background frame (_G.EllesmereUIQTBackground)
--  from the outside:
--   * whenever it is shown, and once a second while it stays shown, the
--     tracker's content is checked the same way EUI does it (lowest shown
--     module, Scenario / UIWidget trackers skipped -- those are never touched);
--   * no content for 0.25s  -> background hidden, stale anchor forgotten;
--   * content moved         -> EUI's own ResizeBGToContent re-anchors it.
--  Extra checks run after every zone change / loading screen.
-------------------------------------------------------------------------------
local CONFIRM_DELAY = 0.25
local TICK = 1

local function BG()  return _G.EllesmereUIQTBackground end
local function EQT() return _G.EllesmereUIQuestTracker end

-- Same rule as EUI's GetLowestContentFrame (reference-only, no coordinates).
local function LowestContent()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return nil end
    local modules = otf.modules or otf.MODULES
    if type(modules) ~= "table" then return nil end
    local scenario, widget = _G.ScenarioObjectiveTracker, _G.UIWidgetObjectiveTracker
    local lowest
    for _, m in ipairs(modules) do
        if m ~= scenario and m ~= widget and type(m) == "table"
           and m.IsShown and m.GetObjectType and m:IsShown() then
            lowest = m
        end
    end
    return lowest
end

local confirmPending = false
local function Check()
    local bg = BG()
    if not bg or not bg:IsShown() then return end
    local lowest = LowestContent()
    if lowest then
        -- Content changed under a shown background: let EUI re-anchor it.
        if lowest ~= bg._lastLowest then
            local eqt = EQT()
            if eqt and eqt.ResizeBGToContent then pcall(eqt.ResizeBGToContent) end
        end
        return
    end
    if confirmPending then return end
    confirmPending = true
    C_Timer.After(CONFIRM_DELAY, function()
        confirmPending = false
        local b = BG()
        if b and b:IsShown() and not LowestContent() then
            b._lastLowest = nil   -- EUI's next pass then hides at once too
            b:Hide()
        end
    end)
end

local queued = false
local function QueueCheck(delay)
    if queued then return end
    queued = true
    C_Timer.After(delay or 0.3, function()
        queued = false
        Check()
    end)
end

local attached = false
local function Attach()
    if attached then return true end
    local bg = BG()
    if not bg then return false end
    attached = true
    hooksecurefunc(bg, "Show", function() QueueCheck(0.3) end)
    C_Timer.NewTicker(TICK, Check)
    QueueCheck(0.5)
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_INDOORS")
f:RegisterEvent("LOADING_SCREEN_DISABLED")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- EUI builds the background in its own PLAYER_LOGIN init (stock
        -- styles never build one: then there is nothing to fix).
        if not Attach() then
            C_Timer.After(1, Attach)
            C_Timer.After(5, Attach)
        end
        return
    end
    if not attached and not Attach() then return end
    C_Timer.After(0.3, Check)
    C_Timer.After(1.0, Check)
    C_Timer.After(2.5, Check)
end)
