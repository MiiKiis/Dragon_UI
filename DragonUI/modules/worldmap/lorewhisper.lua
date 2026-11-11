-- Optional bridge to the VoiceOver API used by LoreWhisper.
-- Only DragonUI's map rows are changed; the normal quest log remains LoreWhisper's.
local addon = select(2, ...)
local WM = addon.WorldMap
local Voice = {}
WM.QuestVoice = Voice

local SIZE, GAP = 16, 2
local TEXTURES = [[Interface\AddOns\LoreWhisper\Textures\]]
local rows = setmetatable({}, { __mode = "k" })
local hookedQueues = setmetatable({}, { __mode = "k" })
local hookedUIs = setmetatable({}, { __mode = "k" })
local playing, available = {}, {}
local dataModules
local refreshRows

local function Text(key)
    local value = addon.L and addon.L[key]
    return type(value) == "string" and value or key
end

local function Environment()
    local vo = _G.VoiceOver
    if type(vo) ~= "table" or type(vo.SoundQueue) ~= "table" or type(vo.DataModules) ~= "table"
        or not (vo.Enums and vo.Enums.SoundEvent and vo.Enums.SoundEvent.QuestAccept) then return end
    local queue = vo.SoundQueue
    if type(queue.AddSoundToQueue) ~= "function" or type(queue.RemoveSoundFromQueue) ~= "function"
        or type(queue.Contains) ~= "function" then return end
    if dataModules ~= vo.DataModules then
        dataModules, available, playing = vo.DataModules, {}, {}
    end
    return vo
end

local function SoundData(vo, questID, title)
    local dm = vo.DataModules
    local giverType, giverID, guid, name
    if type(dm.GetQuestLogQuestGiverTypeAndID) == "function" then
        local ok, kind, id = pcall(dm.GetQuestLogQuestGiverTypeAndID, dm, questID)
        if ok then giverType, giverID = kind, id end
    end
    if giverID and vo.Enums.GUID and type(vo.Enums.GUID.CanHaveID) == "function"
        and vo.Utils and type(vo.Utils.MakeGUID) == "function" then
        local ok, can = pcall(vo.Enums.GUID.CanHaveID, vo.Enums.GUID, giverType)
        if ok and can then
            local made, value = pcall(vo.Utils.MakeGUID, vo.Utils, giverType, giverID)
            if made then guid = value end
        end
    end
    if giverType and giverID and type(dm.GetObjectName) == "function" then
        local ok, value = pcall(dm.GetObjectName, dm, giverType, giverID)
        if ok then name = value end
    end
    return { event = vo.Enums.SoundEvent.QuestAccept, questID = questID,
        name = name or Text("Quest"), title = title, unitGUID = guid }
end

local function HasAudio(vo, questID, title)
    local now = GetTime()
    local cached = available[questID]
    if cached and (cached.found or now < cached.retryAt) then return cached.found end
    local dm, found = vo.DataModules, false
    if type(dm.PrepareSound) == "function" then
        local ok, result = pcall(dm.PrepareSound, dm, SoundData(vo, questID, title))
        found = ok and result and true or false
    end
    if not found and type(dm.DoesQuestSoundExist) == "function" then
        local ok, result = pcall(dm.DoesQuestSoundExist, dm, questID, vo.Enums.SoundEvent.QuestAccept)
        found = ok and result and true or false
    end
    -- A missing pack may be registered after the addon loads; never cache false permanently.
    available[questID] = { found = found, retryAt = now + 2 }
    return found
end

local function IsPlaying(vo, questID)
    local data = playing[questID]
    if not data then return false end
    local ok, result = pcall(vo.SoundQueue.Contains, vo.SoundQueue, data)
    if ok and result then return true end
    playing[questID] = nil
    return false
end

local function EnsureHooks(vo)
    if type(hooksecurefunc) ~= "function" then return end
    local queue = vo.SoundQueue
    if not hookedQueues[queue] then
        local ok = pcall(hooksecurefunc, queue, "AddSoundToQueue", function(_, data)
            -- Also follow audio started from LoreWhisper's normal quest-log button.
            for id in pairs(playing) do IsPlaying(vo, id) end
            local id = type(data) == "table" and tonumber(data.questID)
            if id and id > 0 then playing[id] = data end
            refreshRows()
        end)
        if ok then hookedQueues[queue] = true end
    end
    local ui = vo.SoundQueueUI
    if type(ui) == "table" and type(ui.UpdateSoundQueueDisplay) == "function" and not hookedUIs[ui] then
        local ok = pcall(hooksecurefunc, ui, "UpdateSoundQueueDisplay", function() refreshRows() end)
        if ok then hookedUIs[ui] = true end
    end
end

local watcher = CreateFrame("Frame")
watcher:Hide()
local function Visible(row)
    if row.IsVisible then return row:IsVisible() end
    return row:IsShown()
end

local function SetTexture(button, active)
    local file = TEXTURES .. (active and "QuestLogStopButton.blp" or "QuestLogPlayButton.blp")
    if button.audioTexture == file then return end
    button.audioTexture = file
    button:SetNormalTexture(file)
    button:SetPushedTexture(file)
    button:SetHighlightTexture(file, "ADD")
    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetAlpha(0.6) end
end

function Voice.UpdateRow(row, titleWidth, hasTag)
    if titleWidth ~= nil then
        row.voiceTitleWidth, row.voiceHasTag = titleWidth, hasTag
    end
    if not row.voice or not row.voiceTitleWidth then return end
    local vo, id = Environment(), tonumber(row._questID)
    if vo then EnsureHooks(vo) end
    local show = vo and id and id > 0 and HasAudio(vo, id, row._title) and true or false
    local changed = row.voiceHasAudio ~= show
    row.voiceHasAudio = show
    if show then
        row.voice:ClearAllPoints()
        row.voice:SetPoint("RIGHT", row.voiceHasTag and row.tagButton or row.track, "LEFT", -GAP, 0)
        SetTexture(row.voice, IsPlaying(vo, id))
        row.voice:Show()
    else
        row.voice:Hide()
    end
    row.title:SetWidth(math.max(1, row.voiceTitleWidth - (show and SIZE + GAP or 0)))
    if changed and Visible(row) and WM.RefreshQuestLog then WM.RefreshQuestLog() end
    if Visible(row) then watcher:Show() end
end

refreshRows = function()
    for row in pairs(rows) do
        if Visible(row) then Voice.UpdateRow(row) end
    end
end

local function Click(button)
    local row = button:GetParent()
    local vo, id = Environment(), tonumber(row._questID)
    if not (vo and id and id > 0) then Voice.UpdateRow(row); return end
    local queue = vo.SoundQueue
    if IsPlaying(vo, id) then
        local ok, result = pcall(queue.RemoveSoundFromQueue, queue, playing[id])
        if ok and result ~= false then playing[id] = nil end
    elseif HasAudio(vo, id, row._title) then
        local data = SoundData(vo, id, row._title)
        data.stopCallback = function()
            if playing[id] == data then playing[id] = nil end
            refreshRows()
        end
        if type(queue.RemoveAllSoundsFromQueue) == "function" then
            local ok, result = pcall(queue.RemoveAllSoundsFromQueue, queue)
            if not ok or result == false then return end
        end
        if vo.Addon and vo.Addon.db and vo.Addon.db.char and vo.Addon.db.char.IsPaused
            and type(queue.ResumeQueue) == "function" then pcall(queue.ResumeQueue, queue) end
        local ok, result = pcall(queue.AddSoundToQueue, queue, data)
        if ok and result ~= false then playing[id] = data else playing[id] = nil end
    end
    refreshRows()
end

function Voice.AttachRow(row)
    if row.voice then return end
    rows[row] = true
    local button = CreateFrame("Button", nil, row)
    row.voice = button
    button:SetSize(SIZE, SIZE)
    button:SetHitRectInsets(-2, -2, -2, -2)
    button:SetFrameLevel(row:GetFrameLevel() + 3)
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", Click)
    button:SetScript("OnEnter", function(self)
        local vo = Environment()
        local active = vo and IsPlaying(vo, tonumber(row._questID))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(Text(active and "Stop quest audio" or "Play quest audio"), 1, 1, 1)
        GameTooltip:AddLine("LoreWhisper", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:Hide()
    row:HookScript("OnShow", function() Voice.UpdateRow(row) end)
end

watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("QUEST_LOG_UPDATE")
watcher:SetScript("OnEvent", function()
    available = {}
    refreshRows()
end)
local elapsed = 0
watcher:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.25 then return end
    elapsed = 0
    local visible = false
    for row in pairs(rows) do
        if Visible(row) then visible = true; Voice.UpdateRow(row) end
    end
    if not visible then watcher:Hide() end
end)
