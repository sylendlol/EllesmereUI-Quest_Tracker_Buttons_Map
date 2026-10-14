-------------------------------------------------------------------------------
--  EllesmereUI Quest Log Track Buttons
--
--  * Every zone header in the world map quest log (QuestScrollFrame) gets a
--    small "Track" / "Untrack" button left of its collapse (-/+) button.
--      - If every quest in that zone is tracked  -> "Untrack" (untracks them all)
--      - Otherwise                               -> "Track"   (tracks them all)
--  * An "Untrack All" button sits at the top of the quest log.
--
--  Taint notes: nothing is written onto Blizzard frames (all state lives in
--  local tables), Blizzard functions are only post-hooked with
--  hooksecurefunc, and the quest-watch API is called from our own click
--  handlers only.
-------------------------------------------------------------------------------
local ADDON_NAME = ...

local ACCENT_R, ACCENT_G, ACCENT_B = 0.047, 0.824, 0.624   -- fallback: EllesmereUI teal (#0cd29f)
local FONT = "Fonts\\FRIZQT__.TTF"

local CQL = C_QuestLog
local headerButtons = {}      -- [headerFrame] = our track button
local untrackAllBtn
local busy = false            -- guards the expand/collapse round trip

-- UI Accent Color (Global Settings), live.
local function Accent()
    local eg = _G.EllesmereUI and _G.EllesmereUI.ELLESMERE_GREEN
    if eg and eg.r then return eg.r, eg.g, eg.b end
    return ACCENT_R, ACCENT_G, ACCENT_B
end

-- On/off switch: Quest Tracker > EXTRAS > "Quest Log Track Buttons".
-- Stored in the EllesmereUI Quest Tracker profile (key questLogTrackButtons,
-- nil = on), so it follows EUI profiles. Without the Quest Tracker module the
-- buttons simply stay on.
local SETTING_KEY = "questLogTrackButtons"
local function Settings()
    local eqt = _G.EllesmereUIQuestTracker
    local d = _G._EQT_DB
    if d and d.profile and d.profile.questTracker then return d.profile.questTracker end
    if eqt and eqt.DB then return eqt.DB() end
end
local function Enabled()
    local s = Settings()
    return not (s and s[SETTING_KEY] == false)
end

-------------------------------------------------------------------------------
--  Quest log API wrappers (retail C_QuestLog first, legacy globals as fallback)
-------------------------------------------------------------------------------
local function NumEntries()
    if CQL and CQL.GetNumQuestLogEntries then
        return CQL.GetNumQuestLogEntries() or 0
    end
    return (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
end

local function GetInfo(i)
    if CQL and CQL.GetInfo then return CQL.GetInfo(i) end
    if not GetQuestLogTitle then return nil end
    local title, _, _, isHeader, isCollapsed, _, _, questID = GetQuestLogTitle(i)
    if not title then return nil end
    return { title = title, isHeader = isHeader, isCollapsed = isCollapsed, questID = questID }
end

local useQuestIDApi = CQL and CQL.GetQuestWatchType and CQL.AddQuestWatch and CQL.RemoveQuestWatch

local function IsWatched(questID, index)
    if useQuestIDApi then return CQL.GetQuestWatchType(questID) ~= nil end
    if IsQuestWatched then return IsQuestWatched(index) and true or false end
    return false
end

local function SetWatched(questID, index, on)
    if useQuestIDApi then
        if on then CQL.AddQuestWatch(questID) else CQL.RemoveQuestWatch(questID) end
    else
        if on then AddQuestWatch(index) else RemoveQuestWatch(index) end
    end
end

local function Eligible(info)
    return info and not info.isHeader and not info.isHidden
        and not info.isTask and not info.isBounty
        and info.questID and info.questID > 0
end

-------------------------------------------------------------------------------
--  Header -> zone quests
-------------------------------------------------------------------------------
local function HeaderText(hdr)
    local fs = hdr.ButtonText
        or (hdr.GetName and hdr:GetName() and _G[hdr:GetName() .. "ButtonText"])
        or hdr.Text
    if fs and fs.GetText then return fs:GetText() end
    if hdr.GetText then return hdr:GetText() end
end

local function FindHeaderIndex(hdr)
    local idx = hdr.questLogIndex
    if type(idx) == "number" then
        local info = GetInfo(idx)
        if info and info.isHeader then return idx, info end
    end
    local text = HeaderText(hdr)
    if not text then return end
    for i = 1, NumEntries() do
        local info = GetInfo(i)
        if info and info.isHeader and info.title == text then return i, info end
    end
end

local function CollectZone(headerIndex)
    local list = {}
    for i = headerIndex + 1, NumEntries() do
        local info = GetInfo(i)
        if not info or info.isHeader then break end
        if Eligible(info) then list[#list + 1] = { id = info.questID, idx = i } end
    end
    return list
end

local function CountTracked(list)
    local n = 0
    for _, q in ipairs(list) do
        if IsWatched(q.id, q.idx) then n = n + 1 end
    end
    return n
end

-- Runs fn(list) on the zone's quests. If the header is collapsed and the API
-- hides its children, it is expanded for the duration and collapsed again.
local function WithZone(hdr, fn)
    local hIdx, hInfo = FindHeaderIndex(hdr)
    if not hIdx then return end
    local list = CollectZone(hIdx)
    if #list == 0 and hInfo.isCollapsed and ExpandQuestHeader and CollapseQuestHeader then
        busy = true
        ExpandQuestHeader(hIdx)
        local ok, err = pcall(fn, CollectZone(hIdx))
        CollapseQuestHeader(hIdx)
        busy = false
        if not ok then geterrorhandler()(err) end
        return
    end
    fn(list)
end

-------------------------------------------------------------------------------
--  Flat EllesmereUI-style button
-------------------------------------------------------------------------------
local function CreateFlatButton(parent, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.45)

    local function Edge(p1, p2, horiz)
        local t = b:CreateTexture(nil, "BORDER")
        t:SetColorTexture(1, 1, 1, 0.18)
        t:SetPoint(p1); t:SetPoint(p2)
        if horiz then t:SetHeight(1) else t:SetWidth(1) end
        return t
    end
    Edge("TOPLEFT", "TOPRIGHT", true)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Edge("TOPLEFT", "BOTTOMLEFT", false)
    Edge("TOPRIGHT", "BOTTOMRIGHT", false)

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.12)

    local text = b:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 10, "")
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetPoint("CENTER", 0, 0)
    b.label = text

    b:RegisterForClicks("LeftButtonUp")
    return b
end

local function SetLabel(b, str, r, g, bl)
    b.label:SetText(str)
    b.label:SetTextColor(r, g, bl)
end

-------------------------------------------------------------------------------
--  Per-zone button
-------------------------------------------------------------------------------
local RefreshAll -- forward

local function ZoneButton_OnClick(self)
    local hdr = self.header
    if not hdr then return end
    WithZone(hdr, function(list)
        if #list == 0 then return end
        local allTracked = CountTracked(list) == #list
        for _, q in ipairs(list) do
            local w = IsWatched(q.id, q.idx)
            if allTracked and w then
                SetWatched(q.id, q.idx, false)
            elseif not allTracked and not w then
                SetWatched(q.id, q.idx, true)
            end
        end
    end)
    RefreshAll()
end

local function ZoneButton_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(HeaderText(self.header) or "Zone", 1, 1, 1)
    if self.total then
        GameTooltip:AddLine(("%d / %d quest tracked"):format(self.tracked or 0, self.total), 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine(self.allTracked and "Click: untrack every quest in this zone"
        or "Click: track every quest in this zone", Accent())
    GameTooltip:Show()
end

local function GetZoneButton(hdr)
    local b = headerButtons[hdr]
    if b then return b end
    b = CreateFlatButton(hdr, 52, 16)
    b.header = hdr
    local collapse = hdr.CollapseButton
    if collapse and collapse.GetObjectType then
        b:SetPoint("RIGHT", collapse, "LEFT", -6, 0)
    else
        b:SetPoint("RIGHT", hdr, "RIGHT", -28, 0)
    end
    b:SetFrameLevel(hdr:GetFrameLevel() + 5)
    b:SetScript("OnClick", ZoneButton_OnClick)
    b:SetScript("OnEnter", ZoneButton_OnEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    headerButtons[hdr] = b
    return b
end

local function UpdateZoneButton(hdr)
    local b = GetZoneButton(hdr)
    local hIdx, hInfo = FindHeaderIndex(hdr)
    if not hIdx then b:Hide() return end
    local list = CollectZone(hIdx)
    if #list == 0 and not hInfo.isCollapsed then b:Hide() return end
    local tracked = CountTracked(list)
    b.total = #list > 0 and #list or nil
    b.tracked = tracked
    b.allTracked = #list > 0 and tracked == #list
    if b.allTracked then
        SetLabel(b, "Untrack", 1, 0.45, 0.45)
    else
        SetLabel(b, "Track", Accent())
    end
    b:Show()
end

-------------------------------------------------------------------------------
--  Untrack All
-------------------------------------------------------------------------------
local function UntrackAll()
    if CQL and CQL.GetNumQuestWatches and CQL.GetQuestIDForQuestWatchIndex and CQL.RemoveQuestWatch then
        local ids = {}
        for i = 1, CQL.GetNumQuestWatches() or 0 do
            local id = CQL.GetQuestIDForQuestWatchIndex(i)
            if id then ids[#ids + 1] = id end
        end
        for _, id in ipairs(ids) do CQL.RemoveQuestWatch(id) end
    else
        for i = NumEntries(), 1, -1 do
            local info = GetInfo(i)
            if Eligible(info) and IsWatched(info.questID, i) then
                SetWatched(info.questID, i, false)
            end
        end
    end
    RefreshAll()
end

local AnchorFilterButtons -- forward (Show only Elite / Dungeon section)

local function AnchorUntrackAll()
    if not untrackAllBtn then return end
    if AnchorFilterButtons then C_Timer.After(0, AnchorFilterButtons) end
    local qs = _G.QuestScrollFrame
    local settings = qs and qs.SettingsDropdown
    untrackAllBtn:ClearAllPoints()
    if settings and settings:IsShown() and settings:GetLeft() then
        -- Leatrix Maps moves the settings (gear) button into its title bar:
        -- sit right beside it there.
        untrackAllBtn:SetPoint("RIGHT", settings, "LEFT", -6, 0)
        untrackAllBtn:SetFrameStrata(settings:GetFrameStrata())
        untrackAllBtn:SetFrameLevel(settings:GetFrameLevel() + 1)
    elseif qs then
        untrackAllBtn:SetPoint("BOTTOMRIGHT", qs, "TOPRIGHT", -4, 3)
        untrackAllBtn:SetFrameStrata("HIGH")
    end
end

local function CreateUntrackAll()
    if untrackAllBtn or not _G.QuestMapFrame then return end
    untrackAllBtn = CreateFlatButton(_G.QuestMapFrame, 74, 18)
    SetLabel(untrackAllBtn, "Untrack All", 1, 0.82, 0)
    untrackAllBtn:SetScript("OnClick", UntrackAll)
    untrackAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Untrack All", 1, 1, 1)
        GameTooltip:AddLine("Removes every quest from the tracker.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    untrackAllBtn:SetScript("OnLeave", GameTooltip_Hide)
    _G.QuestMapFrame:HookScript("OnShow", function() C_Timer.After(0, AnchorUntrackAll) end)
    AnchorUntrackAll()
end

-------------------------------------------------------------------------------
--  Track by kind: Elite / Dungeon
--
--  Two buttons left of "Untrack All". They work like the zone buttons, but
--  for every quest of one kind in the whole log:
--    * click        -> track every Elite (or Dungeon) quest; if they are all
--                      tracked already, untrack them
--    * shift-click  -> track ONLY those: every other quest is untracked
--  The quest log list itself is never changed.
--  Kind = the "(Elite)" / "(Dungeon)" tag on the quest's row in the log (read
--  from the row's text, cached per quest); quests without a row (collapsed
--  zone) fall back to C_QuestLog.GetQuestTagInfo.
-------------------------------------------------------------------------------
local kindBtns = {}
local tagCache = {}          -- [questID] = { elite = bool, dungeon = bool } (read from rows)

local function KindsFromText(s, out)
    if type(s) ~= "string" or s == "" then return end
    if issecretvalue and issecretvalue(s) then return end
    local l = s:lower()
    if l:find("%(elite%)") then out.elite = true end
    if l:find("%(dungeon%)") then out.dungeon = true end
    -- Elite level marker in the title: "[30+]" / "[42+]".
    if l:find("%[%d+%+%]") then out.elite = true end
end

-- Only text that is actually SHOWN counts: the rows are pooled, and the
-- "(Elite)" / "(Dungeon)" tag string is just hidden (not cleared) on a row
-- whose new quest has no tag -- it keeps the previous quest's text. Reading
-- it anyway mixed up quests once zones were expanded/collapsed (1.3.1 bug).
local function Visible(obj)
    if obj.IsShown and not obj:IsShown() then return false end
    if obj.GetAlpha then
        local a = obj:GetAlpha()
        if type(a) == "number" and not (issecretvalue and issecretvalue(a)) and a <= 0 then return false end
    end
    return true
end

local function ScanText(frame, out, depth)
    for _, r in ipairs({ frame:GetRegions() }) do
        if r and r.GetObjectType and r:GetObjectType() == "FontString" and Visible(r) then
            local ok, t = pcall(r.GetText, r)
            if ok then KindsFromText(t, out) end
        end
    end
    if depth > 0 then
        for _, c in ipairs({ frame:GetChildren() }) do
            if Visible(c) then ScanText(c, out, depth - 1) end
        end
    end
end

-- Read the tags off the rows currently shown in the quest log. A row is the
-- final word for its quest: no "(Elite)" / "(Dungeon)" / "[NN+]" on the row
-- means it is NOT that kind (1.3.0 still asked the API for untagged rows, and
-- WoW Forever's tag data marked plain quests as elite).
local function ScanVisibleRows()
    local qs = _G.QuestScrollFrame
    local pool = qs and qs.titleFramePool
    if not (pool and pool.EnumerateActive) then return end
    for row in pool:EnumerateActive() do
        local qid = row.questID
        if qid then
            local k = { elite = false, dungeon = false, src = "row" }
            ScanText(row, k, 1)
            tagCache[qid] = k
        end
    end
end

local function QuestKinds(questID)
    local k = tagCache[questID]
    if k then return k end
    -- Never seen on a row (collapsed zone): strict API fallback -- only an
    -- explicit "Elite" / "Dungeon" tag name, or the Dungeon tag ID.
    local api = { elite = false, dungeon = false, src = "api" }
    if CQL and CQL.GetQuestTagInfo then
        local ok, info = pcall(CQL.GetQuestTagInfo, questID)
        if ok and type(info) == "table" then
            local name = type(info.tagName) == "string" and info.tagName:lower() or ""
            if name == "elite" then api.elite = true end
            if name == "dungeon" or info.tagID == 81 then api.dungeon = true end
            api.tagName, api.tagID = info.tagName, info.tagID
        end
    end
    return api
end

-- Every trackable quest in the log: { all = {...}, kind = {...} }
local function CollectKind(kind)
    ScanVisibleRows()
    local all, match = {}, {}
    for i = 1, NumEntries() do
        local info = GetInfo(i)
        if Eligible(info) then
            local q = { id = info.questID, idx = i }
            all[#all + 1] = q
            if QuestKinds(info.questID)[kind] then match[#match + 1] = q end
        end
    end
    return all, match
end

local function KindButton_OnClick(self)
    local all, match = CollectKind(self.kind)
    if #match == 0 then return end
    if IsShiftKeyDown() then
        -- Only these: untrack everything else, track every match.
        local isMatch = {}
        for _, q in ipairs(match) do isMatch[q.id] = true end
        for _, q in ipairs(all) do
            local w = IsWatched(q.id, q.idx)
            if isMatch[q.id] and not w then SetWatched(q.id, q.idx, true)
            elseif not isMatch[q.id] and w then SetWatched(q.id, q.idx, false) end
        end
    else
        local allTracked = CountTracked(match) == #match
        for _, q in ipairs(match) do
            local w = IsWatched(q.id, q.idx)
            if allTracked and w then SetWatched(q.id, q.idx, false)
            elseif not allTracked and not w then SetWatched(q.id, q.idx, true) end
        end
    end
    RefreshAll()
end

local function KindButton_OnEnter(self)
    local _, match = CollectKind(self.kind)
    local tracked = CountTracked(match)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(self.title .. " quests", 1, 1, 1)
    GameTooltip:AddLine(("%d / %d tracked"):format(tracked, #match), 0.8, 0.8, 0.8)
    if #match == 0 then
        GameTooltip:AddLine("No " .. self.title .. " quest in your log.", 0.6, 0.6, 0.6)
    elseif tracked == #match then
        GameTooltip:AddLine("Click: untrack every " .. self.title .. " quest", 1, 0.45, 0.45)
    else
        GameTooltip:AddLine("Click: track every " .. self.title .. " quest", Accent())
    end
    if #match > 0 then
        GameTooltip:AddLine("Shift-click: track ONLY " .. self.title .. " quests", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function UpdateKindButton(b)
    local _, match = CollectKind(b.kind)
    local tracked = CountTracked(match)
    if #match == 0 then
        b.label:SetTextColor(0.5, 0.5, 0.5)
        b:SetAlpha(0.5)
    elseif tracked == #match then
        b.label:SetTextColor(1, 0.45, 0.45)       -- next click untracks
        b:SetAlpha(1)
    else
        b.label:SetTextColor(Accent())            -- next click tracks
        b:SetAlpha(1)
    end
end

function AnchorFilterButtons()
    local d, e = kindBtns.dungeon, kindBtns.elite
    if not (d and e and untrackAllBtn) then return end
    d:ClearAllPoints()
    d:SetPoint("RIGHT", untrackAllBtn, "LEFT", -4, 0)
    e:ClearAllPoints()
    e:SetPoint("RIGHT", d, "LEFT", -4, 0)
    for _, b in pairs(kindBtns) do
        b:SetFrameStrata(untrackAllBtn:GetFrameStrata())
        b:SetFrameLevel(untrackAllBtn:GetFrameLevel())
    end
end

local function CreateKindButtons()
    if kindBtns.elite or not _G.QuestMapFrame then return end
    for _, def in ipairs({
        { kind = "dungeon", title = "Dungeon", w = 58 },
        { kind = "elite",   title = "Elite",   w = 42 },
    }) do
        local b = CreateFlatButton(_G.QuestMapFrame, def.w, 18)
        b.kind, b.title = def.kind, def.title
        b.label:SetText(def.title)
        b:SetScript("OnClick", KindButton_OnClick)
        b:SetScript("OnEnter", KindButton_OnEnter)
        b:SetScript("OnLeave", GameTooltip_Hide)
        kindBtns[def.kind] = b
    end
    AnchorFilterButtons()
end

-------------------------------------------------------------------------------
--  Refresh
-------------------------------------------------------------------------------
local function EnumerateHeaders(cb)
    local qs = _G.QuestScrollFrame
    if not qs then return end
    for _, key in ipairs({ "headerFramePool", "campaignHeaderFramePool", "campaignHeaderMinimalFramePool" }) do
        local pool = qs[key]
        if pool and pool.EnumerateActive then
            for hdr in pool:EnumerateActive() do cb(hdr, key) end
        end
    end
end

function RefreshAll()
    if busy then return end
    -- Switched off in the options: hide everything we own and stop here.
    if not Enabled() then
        for _, b in pairs(headerButtons) do b:Hide() end
        if untrackAllBtn then untrackAllBtn:Hide() end
        for _, b in pairs(kindBtns) do b:Hide() end
        return
    end
    if untrackAllBtn and not untrackAllBtn:IsShown() then
        untrackAllBtn:Show()
        for _, b in pairs(kindBtns) do b:Show() end
        AnchorUntrackAll()
    end
    local qm = _G.QuestMapFrame
    if not qm or not qm:IsVisible() then return end
    -- Hide everything first (pooled headers get reused for other zones).
    for _, b in pairs(headerButtons) do b:Hide() end
    EnumerateHeaders(function(hdr, key)
        -- Campaign (big story) headers are left alone; zone headers only.
        if key == "headerFramePool" then
            local ok, err = pcall(UpdateZoneButton, hdr)
            if not ok then geterrorhandler()(err) end
        end
    end)
    if untrackAllBtn then
        local any = CQL and CQL.GetNumQuestWatches and (CQL.GetNumQuestWatches() or 0) > 0
        untrackAllBtn:SetAlpha((any == false) and 0.5 or 1)
    end
    for _, b in pairs(kindBtns) do
        local ok, err = pcall(UpdateKindButton, b)
        if not ok then geterrorhandler()(err) end
    end
end

local pending = false
local function QueueRefresh()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        RefreshAll()
    end)
end

-------------------------------------------------------------------------------
--  Init
-------------------------------------------------------------------------------
local installed = false
local function Install()
    if installed or not _G.QuestMapFrame or not _G.QuestScrollFrame then return end
    installed = true
    CreateUntrackAll()
    CreateKindButtons()
    -- v1.2.0 (list filter) left these keys behind; the list is never filtered now.
    local s = Settings()
    if s then s.questLogFilterElite = nil; s.questLogFilterDungeon = nil end
    if type(_G.QuestLogQuests_Update) == "function" then
        hooksecurefunc("QuestLogQuests_Update", QueueRefresh)
    end
    _G.QuestMapFrame:HookScript("OnShow", QueueRefresh)
    QueueRefresh()
end

-- Small public API for the options row (QuestLogTrack_Options.lua).
_G.EUIQuestLogTrack = {
    SETTING_KEY = SETTING_KEY,
    Settings    = Settings,
    IsEnabled   = Enabled,
    SetEnabled  = function(on)
        local s = Settings()
        -- nil = on (default), false = off. (Not "(not on) and false or nil":
        -- that always yields nil in Lua.)
        if s then
            if on then s[SETTING_KEY] = nil else s[SETTING_KEY] = false end
        end
        if installed then RefreshAll() end
    end,
    Refresh     = function() if installed then RefreshAll() end end,
    -- /qltrack kinds: how every quest in the log was classified.
    DumpKinds   = function()
        ScanVisibleRows()
        print("|cff0cd29fQLTrack kinds|r (E = elite, D = dungeon, src row/api)")
        for i = 1, NumEntries() do
            local info = GetInfo(i)
            if Eligible(info) then
                local k = QuestKinds(info.questID)
                print(("  %s%s %s  [%s%s]"):format(k.elite and "E" or "-", k.dungeon and "D" or "-",
                    tostring(info.title), k.src or "?",
                    k.src == "api" and (" tag=" .. tostring(k.tagName) .. "/" .. tostring(k.tagID)) or ""))
            end
        end
    end,
}

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" then
        Install()
    elseif installed then
        QueueRefresh()
    end
end)

-------------------------------------------------------------------------------
--  Options toggle (was QuestLogTrack_Options.lua; lives here so a /reload is
--  enough -- WoW only re-reads .toc file lists on a full client restart).
--
--  Adds "Quest Log Track Buttons" to EllesmereUI > Quest Tracker > EXTRAS, in
--  the empty right half of the "Quest Item Hotkey" row. EllesmereUIOptions
--  loads on demand; once it has, W.DualRow is wrapped. The wrapper passes every
--  row through except one: while the Quest Tracker page is being built
--  (EllesmereUI._buildingModule) the hotkey row is DualRow(label "", label "")
--  and its right half gets our toggle. No EllesmereUI file is edited.
--  If a later EllesmereUI changes that row, the toggle doesn't appear (the
--  buttons stay on by default); /qltrack on|off still works.
-------------------------------------------------------------------------------
do
local EllesmereUI = _G.EllesmereUI
local API = _G.EUIQuestLogTrack
if EllesmereUI and API then


local QT_MODULE = "EllesmereUIQuestTracker"

local function ToggleCfg()
    return { type = "toggle", text = "Quest Log Track Buttons",
        tooltip = "Shows a Track / Untrack button on every zone header of the world map quest log, and an Untrack All button at the top of it.",
        getValue = function() return API.IsEnabled() end,
        setValue = function(v) API.SetEnabled(v) end }
end

local function IsHotkeyRow(left, right)
    return type(left) == "table" and type(right) == "table"
        and left.type == "label" and right.type == "label"
        and left.text == "" and right.text == ""
end

-- Diagnostics for /qltrack debug.
local dbg = { installed = false, rows = 0, hotkeySeen = 0, injected = 0,
              lastModule = "-", lastHotkeyModule = "-", lastHeader = "-", err = nil }

-- Last section header drawn on each page parent (a second way to recognise
-- the Quest Tracker EXTRAS block when _buildingModule isn't set).
local lastHeader = setmetatable({}, { __mode = "k" })

local function ShouldInject(parent, left, right)
    if not IsHotkeyRow(left, right) then return false end
    dbg.hotkeySeen = dbg.hotkeySeen + 1
    local m = EllesmereUI._buildingModule
    dbg.lastHotkeyModule = tostring(m)
    if m == QT_MODULE then return true end
    return lastHeader[parent] == "EXTRAS" and (m == nil or m == QT_MODULE)
end

local installed = false
local function Install()
    if installed then return true end
    local W = EllesmereUI.Widgets
    if not (W and type(W.DualRow) == "function") then return false end
    installed = true
    dbg.installed = true
    local origDualRow = W.DualRow
    W.DualRow = function(self, parent, y, left, right, ...)
        dbg.rows = dbg.rows + 1
        dbg.lastModule = tostring(EllesmereUI._buildingModule)
        if ShouldInject(parent, left, right) then
            local ok, a, b = pcall(origDualRow, self, parent, y, left, ToggleCfg(), ...)
            if ok then dbg.injected = dbg.injected + 1; return a, b end
            dbg.err = tostring(a)
            geterrorhandler()(a)
        end
        return origDualRow(self, parent, y, left, right, ...)
    end
    local origHeader = W.SectionHeader
    if type(origHeader) == "function" then
        W.SectionHeader = function(self, parent, text, ...)
            if parent then lastHeader[parent] = text; dbg.lastHeader = tostring(text) end
            return origHeader(self, parent, text, ...)
        end
    end
    return true
end

local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

-- Why Install hasn't worked yet (for /qltrack debug).
local function InstallState()
    local EUI = _G.EllesmereUI
    local W = EUI and EUI.Widgets
    return "EUI=" .. tostring(EUI ~= nil) .. " Widgets=" .. tostring(W ~= nil)
        .. " DualRow=" .. type(W and W.DualRow)
end

-- Keep trying until it works: on every ADDON_LOADED, at login, and once a
-- second (a single table lookup) until hooked -- the options addon can load
-- at any time, and v1.1.1 gave up after one early attempt.
local function TryInstall()
    if installed then return true end
    -- EllesmereUI may have replaced its global table since our file loaded.
    if _G.EllesmereUI and _G.EllesmereUI ~= EllesmereUI then EllesmereUI = _G.EllesmereUI end
    local ok, res = pcall(Install)
    if not ok then dbg.err = tostring(res) end
    return installed
end

-- EUI 9.5.4 builds EllesmereUI.Widgets in a DEFERRED init that only runs on
-- the first panel open (EllesmereUI:EnsureLoaded), well after the options
-- addon's ADDON_LOADED -- that is why v1.1.1 never hooked. Post-hook
-- EnsureLoaded so we attach right after those inits and before the first
-- page is built (the first open builds the panel on the next frame).
if type(EllesmereUI.EnsureLoaded) == "function" then
    hooksecurefunc(EllesmereUI, "EnsureLoaded", function() TryInstall() end)
end

if not TryInstall() then
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        if TryInstall() then self:UnregisterAllEvents() end
    end)
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        if TryInstall() and ticker then ticker:Cancel(); f:UnregisterAllEvents() end
    end)
end

-- Fallback switch without the panel, plus diagnostics.
SLASH_QLTRACK1 = "/qltrack"
SlashCmdList.QLTRACK = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "debug" then
        TryInstall()
        print("|cff0cd29fQLTrack state|r", InstallState())
        local W = EllesmereUI.Widgets
        print("|cff0cd29fQLTrack debug|r",
            "optionsLoaded=" .. tostring(IsLoaded and IsLoaded("EllesmereUIOptions")),
            "hooked=" .. tostring(dbg.installed),
            "wrapperActive=" .. tostring(W and W.DualRow ~= nil and dbg.installed and true),
            "rows=" .. dbg.rows,
            "hotkeyRows=" .. dbg.hotkeySeen,
            "injected=" .. dbg.injected,
            "lastModule=" .. dbg.lastModule,
            "hotkeyModule=" .. dbg.lastHotkeyModule,
            "lastHeader=" .. dbg.lastHeader,
            "err=" .. tostring(dbg.err))
        return
    end
    if msg == "kinds" then
        if API.DumpKinds then API.DumpKinds() end
        return
    end
    if msg == "on" then API.SetEnabled(true)
    elseif msg == "off" then API.SetEnabled(false)
    else API.SetEnabled(not API.IsEnabled()) end
    print("|cff0cd29fQuest Log Track Buttons|r: " .. (API.IsEnabled() and "ON" or "OFF"))
end
end
end
