-- Friend notifications imported from the WoW-Hollow DragonUI edition.
-- Uses a private toast and queue: Blizzard's Battle.net APIs and broadcast box are left intact.

local addon = select(2, ...)
local Module = { initialized = false, applied = false, frames = {} }
addon.BNetToastModule = Module

local function Text(key)
    local value = addon.L and addon.L[key]
    return type(value) == "string" and value or key
end

if addon.RegisterModule then
    addon:RegisterModule("bnettoast", Module, Text("BNet Toast"),
        Text("Friend online/offline notifications with Battle.net toasts and chat messages"), {
            lifecycle = {
                apply = "ApplyBNetToast",
                restore = "RestoreBNetToast",
                refresh = "RefreshBNetToastSystem",
            },
        })
end

local function Config()
    return addon:GetModuleConfig("bnettoast") or {}
end

local function Enabled()
    return addon:IsModuleEnabled("bnettoast")
end

local function Number(value, fallback, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= value then value = fallback end
    return math.max(minimum, math.min(maximum, value))
end

-- Escape format text before replacing its %s placeholders. The old pattern
-- accidentally matched a literal dot instead of a friend's name.
local function MessagePattern(formatString)
    if type(formatString) ~= "string" then return nil end
    local parts, position = {}, 1
    while position <= #formatString do
        local first, last = formatString:find("%%[0-9]*%$?s", position)
        local literal = first and formatString:sub(position, first - 1) or formatString:sub(position)
        parts[#parts + 1] = (literal:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
        if not first then break end
        parts[#parts + 1] = "(.-)"
        position = last + 1
    end
    return "^" .. table.concat(parts) .. "$"
end

local onlinePattern = MessagePattern(ERR_FRIEND_ONLINE_SS)
local offlinePattern = MessagePattern(ERR_FRIEND_OFFLINE_S)
local friends, guild, accounts = {}, {}, {}
local recent = {}
local queue, current, elapsed = {}, nil, 0
local toast, anchor, eventFrame
local filterInstalled = false
local ANCHORS = {CENTER=true, TOP=true, BOTTOM=true, LEFT=true, RIGHT=true, TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true}

local function CleanName(name)
    if type(name) ~= "string" or name == "" then return nil end
    return name:match("|h%[(.-)%]|h") or name:match("^%[(.-)%]$") or name
end

local function NameKey(name)
    name = CleanName(name)
    return name and name:lower()
end

local function RebuildFriends()
    friends = {}
    if not GetNumFriends or not GetFriendInfo then return end
    for i = 1, GetNumFriends() do
        local name, level, class, area, connected = GetFriendInfo(i)
        if name then
            local toon = type(area) == "string" and area:match("Added as:%s*%((.-)%)")
            local info = { name = name, online = connected }
            if toon then
                -- Ascension puts the account ID in level and the toon in area.
                info.toon = toon
            else
                info.wowName = name
                info.zone = type(area) == "string" and area ~= "" and area or nil
                info.level = tonumber(level)
                info.class = class
            end
            friends[NameKey(name)] = info
            if toon then friends[NameKey(toon)] = info end
        end
    end
end

local function RefreshGuild()
    if not IsInGuild or not IsInGuild() then guild = {}; return end
    if not GetNumGuildMembers or not GetGuildRosterInfo then return end
    -- Keep known members during this session: custom servers may only enumerate
    -- online guildmates, so a later offline broadcast must still resolve them.
    for i = 1, GetNumGuildMembers() do
        local name, _, _, level, class, zone = GetGuildRosterInfo(i)
        if name then guild[NameKey(name)] = { name = name, wowName = name, zone = zone, level = level, class = class } end
    end
end

local function MatchMessage(message)
    if type(message) ~= "string" then return nil end
    local function match(pattern)
        if not pattern then return nil end
        local captures = { message:match(pattern) }
        for i = #captures, 1, -1 do
            local name = CleanName(captures[i])
            if name and name ~= "" then return name end
        end
    end
    local name = match(onlinePattern)
    if name then return name, true end
    name = match(offlinePattern)
    if name then return name, false end
end

local function ResolveMessage(message)
    local name, online = MatchMessage(message)
    if not name then return nil end
    local cfg = Config()
    if (online and cfg.show_online == false) or (not online and cfg.show_offline == false) then return nil end
    local info = friends[NameKey(name)]
    if not info and cfg.guild_notify == true then info = guild[NameKey(name)] end
    if not info then return nil end
    return info, online
end

local function WidgetConfig()
    local profile = addon.db and addon.db.profile
    if not profile then return nil end
    profile.widgets = profile.widgets or {}
    profile.widgets.bnToast = profile.widgets.bnToast or {}
    return profile.widgets.bnToast
end

local function InEditor()
    return addon.EditorMode and addon.EditorMode.IsActive and addon.EditorMode:IsActive()
end

local function ApplyPosition()
    if not anchor then return end
    if InEditor() then return end
    local widget, cfg = WidgetConfig(), Config()
    local point = widget and ANCHORS[widget.anchor] and widget.anchor or "CENTER"
    local x = widget and widget.custom_position and widget.posX or cfg.x_position
    local y = widget and widget.custom_position and widget.posY or cfg.y_offset
    anchor:ClearAllPoints()
    anchor:SetPoint(point, UIParent, point, Number(x, 0, -4000, 4000), Number(y, 200, -4000, 4000))
end

local function PersistPosition()
    if not anchor then return end
    local cx, cy = anchor:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (cx and cy and ux and uy) then return end
    local widget, cfg = WidgetConfig(), Config()
    if not widget then return end
    widget.anchor, widget.custom_position = "CENTER", true
    widget.posX, widget.posY = math.floor(cx - ux + 0.5), math.floor(cy - uy + 0.5)
    cfg.x_position, cfg.y_offset = widget.posX, widget.posY
end

local function ClearPresentation()
    queue, current, elapsed = {}, nil, 0
    if toast then
        toast:Hide()
        toast:SetAlpha(1)
        toast:SetScript("OnUpdate", nil)
    end
end

local ShowNext
local function AdvanceToast(_, delta)
    if not Module.applied or not Enabled() then ClearPresentation(); return end
    if current and current.preview and InEditor() then return end
    elapsed = elapsed + delta
    local duration = Number(Config().duration, 5, 1, 20)
    if elapsed >= duration then
        current = nil
        toast:Hide()
        ShowNext()
    else
        toast:SetAlpha(math.min(1, (duration - elapsed) / 0.5))
    end
end

local function BuildToast()
    if toast then return end
    anchor = addon.CreateUIFrame and addon.CreateUIFrame(260, 66, "bnToast") or CreateFrame("Frame", nil, UIParent)
    anchor:SetSize(260, 66)
    anchor:Hide()
    Module.frames.anchor = anchor
    if addon.CreateUIFrame and addon.RegisterEditableFrame then
        addon:RegisterEditableFrame({
            name = "bnToast", frame = anchor, configPath = {"widgets", "bnToast"}, module = Module,
            showTest = function()
                anchor:Show()
                addon.TestBNetToast()
            end,
            onHide = function()
                if anchor.DragonUI_WasDragged or anchor.DragonUI_WasAdjustedByEditor then PersistPosition() end
                anchor.DragonUI_WasDragged, anchor.DragonUI_WasAdjustedByEditor = nil, nil
                anchor:Hide()
                if current and current.preview then ClearPresentation() end
                ApplyPosition()
            end,
        })
    end
    if anchor.HookScript then anchor:HookScript("OnDragStop", PersistPosition) end
    if anchor.editorText then anchor.editorText:SetText(Text("BNet Toast")) end

    toast = CreateFrame("Button", "DragonUI_BNetFriendToast", UIParent)
    Module.frames.toast = toast
    toast:SetSize(260, 66)
    toast:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    toast:SetFrameStrata("DIALOG")
    toast:SetClampedToScreen(true)
    toast:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 14, insets = {left=3,right=3,top=3,bottom=3}})
    toast:SetBackdropColor(0.025, 0.055, 0.10, 0.96)
    toast:SetBackdropBorderColor(0.30, 0.65, 0.92, 1)
    local icon = toast:CreateTexture(nil, "ARTWORK")
    icon:SetSize(38, 38)
    icon:SetPoint("LEFT", 11, 0)
    icon:SetTexture("Interface\\FriendsFrame\\Battlenet-Portrait")
    toast.icon = icon
    local title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 58, -12)
    title:SetWidth(187)
    title:SetJustifyH("LEFT")
    title:SetTextColor(0.51, 0.773, 1)
    toast.title = title
    local detail = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    detail:SetWidth(187)
    detail:SetJustifyH("LEFT")
    toast.detail = detail
    toast:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    toast:SetScript("OnClick", function(_, button)
        if current and not current.preview and button == "LeftButton" and ChatFrame_SendTell then
            local target = current.info.toon or current.info.wowName
            if target then ChatFrame_SendTell(target) end
        end
        current = nil
        toast:Hide()
        ShowNext()
    end)
    toast:Hide()
end

local function DisplayName(info, cfg)
    local name = info.name or "?"
    if cfg.show_toon ~= false and info.toon and info.toon ~= name then name = name .. " (" .. info.toon .. ")" end
    return name
end

ShowNext = function()
    if not Module.applied or not Enabled() or current or #queue == 0 then
        if toast and not current then toast:SetScript("OnUpdate", nil) end
        return
    end
    current, elapsed = table.remove(queue, 1), 0
    local cfg, info = Config(), current.info
    toast.title:SetText(DisplayName(info, cfg))
    local status = Text(current.online and "Online" or "Offline")
    if cfg.show_zone ~= false and current.online and info.zone and info.zone ~= "" then status = status .. " - " .. info.zone end
    toast.detail:SetText(status)
    toast.detail:SetTextColor(current.online and 0.35 or 1, current.online and 1 or 0.35, 0.35)
    toast.icon:SetDesaturated(not current.online)
    toast:SetAlpha(1)
    toast:SetScript("OnUpdate", AdvanceToast)
    toast:Show()
end

local function Notify(info, online, preview)
    if not Module.applied or not Enabled() then return end
    local cfg = Config()
    if not preview and ((online and cfg.show_online == false) or (not online and cfg.show_offline == false)) then return end
    if not preview then
        local key = (info.name or "") .. (online and ":online" or ":offline")
        local now = GetTime()
        if recent[key] and now - recent[key] < 2 then return end
        recent[key] = now
        -- Keep this session's deduplication map bounded during long raids.
        for id, at in pairs(recent) do if now - at > 10 then recent[id] = nil end end
        if cfg.show_chat ~= false and DEFAULT_CHAT_FRAME then
            local icon = online and "Interface\\FriendsFrame\\StatusIcon-Online" or "Interface\\FriendsFrame\\StatusIcon-Offline"
            local status = Text(online and "Online" or "Offline")
            local message = "|T" .. icon .. ":14:14|t |cff82c5ff" .. DisplayName(info, cfg) .. "|r - " .. status
            if cfg.show_zone ~= false and online and info.zone and info.zone ~= "" then message = message .. " (" .. info.zone .. ")" end
            DEFAULT_CHAT_FRAME:AddMessage(message)
        end
        if cfg.sound == true and PlaySound then PlaySound("TellMessage") end
    end
    if preview or cfg.show_toast ~= false then
        BuildToast()
        while #queue >= math.floor(Number(cfg.max_queue, 20, 1, 50)) do table.remove(queue, 1) end
        queue[#queue + 1] = { info = info, online = online, preview = preview }
        ShowNext()
    end
end

local function NativeAccount(id, online)
    if not BNGetFriendInfoByID then return end
    local _, givenName, surname, toonName, _, _, connected = BNGetFriendInfoByID(id)
    if givenName then
        local fullName = givenName .. ((surname and surname ~= "") and (" " .. surname) or "")
        accounts[id] = { name = fullName, toon = toonName, online = connected }
    end
    if accounts[id] then Notify(accounts[id], online) end
end

local function OnEvent(_, event, arg)
    if not Module.applied or not Enabled() then return end
    if event == "FRIENDLIST_UPDATE" then RebuildFriends()
    elseif event == "GUILD_ROSTER_UPDATE" then RefreshGuild()
    elseif event == "CHAT_MSG_SYSTEM" then
        local info, online = ResolveMessage(arg)
        if info then Notify(info, online) end
    elseif event == "BN_FRIEND_ACCOUNT_ONLINE" then NativeAccount(arg, true)
    elseif event == "BN_FRIEND_ACCOUNT_OFFLINE" then NativeAccount(arg, false) end
end

local function SystemMessageFilter(_, _, message)
    if not Module.applied or not Enabled() then return end
    local cfg = Config()
    if cfg.show_chat == false and cfg.show_toast == false then return end
    if ResolveMessage(message) then return true end
end

function addon.ApplyBNetToast()
    if not Enabled() then return end
    BuildToast()
    if not Module.applied then
        Module.applied, Module.initialized = true, true
        if not eventFrame then
            eventFrame = CreateFrame("Frame")
            eventFrame:SetScript("OnEvent", OnEvent)
            Module.frames.events = eventFrame
        end
        for _, name in ipairs({"CHAT_MSG_SYSTEM", "FRIENDLIST_UPDATE", "GUILD_ROSTER_UPDATE"}) do eventFrame:RegisterEvent(name) end
        -- The native BNet events do not exist on every 3.3.5a server/client.
        if not BNToastFrame then
            pcall(eventFrame.RegisterEvent, eventFrame, "BN_FRIEND_ACCOUNT_ONLINE")
            pcall(eventFrame.RegisterEvent, eventFrame, "BN_FRIEND_ACCOUNT_OFFLINE")
        end
        if ChatFrame_AddMessageEventFilter and not filterInstalled then
            ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", SystemMessageFilter)
            filterInstalled = true
        end
    end
    RebuildFriends()
    RefreshGuild()
    addon.UpdateBNetToastScale()
    ApplyPosition()
end

function addon.RestoreBNetToast()
    Module.applied = false
    if eventFrame then eventFrame:UnregisterAllEvents() end
    if filterInstalled and ChatFrame_RemoveMessageEventFilter then
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", SystemMessageFilter)
        filterInstalled = false
    end
    ClearPresentation()
    if anchor then anchor:Hide() end
    friends, guild, accounts, recent = {}, {}, {}, {}
end

function addon.RefreshBNetToastSystem()
    -- Profile changes must not carry the previous profile's queued notices.
    addon.RestoreBNetToast()
    if Enabled() then addon.ApplyBNetToast() end
end

function addon.UpdateBNetToastScale()
    if toast and Module.applied then toast:SetScale(Number(Config().scale, 1, 0.5, 2.5)) end
end

function addon.UpdateBNetToastPosition()
    local widget, cfg = WidgetConfig(), Config()
    if widget then
        widget.anchor, widget.custom_position = "CENTER", true
        widget.posX, widget.posY = Number(cfg.x_position, 0, -4000, 4000), Number(cfg.y_offset, 200, -4000, 4000)
    end
    ApplyPosition()
end

function addon.TestBNetToast()
    if not Enabled() then return false end
    addon.ApplyBNetToast()
    ClearPresentation()
    Notify({name = Text("Example Friend"), toon = Text("Example Character"), zone = Text("Example Zone")}, true, true)
    return true
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_ENTERING_WORLD")
init:SetScript("OnEvent", function()
    addon.RefreshBNetToastSystem()
end)
