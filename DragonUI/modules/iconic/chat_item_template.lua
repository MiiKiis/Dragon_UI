local addon = select(2, ...)
local Module = addon.IconicModule

local CHAT_EVENTS = {
    "CHAT_MSG_LOOT", "CHAT_MSG_CHANNEL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_SAY",
    "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_SYSTEM",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
}
local filtersAdded = false

function Module:FilterChat(_, _, message, ...)
    if not self:IsActive("chat_icons") or type(message) ~= "string" then return false, message, ... end
    local size = math.max(10, math.min(32, tonumber(self:Config().chat_icon_size) or 15))
    -- WotLK item links contain a display-name |h segment and a closing |h|r.
    -- Capture the preceding texture escape too, making a repeated filter pass idempotent.
    local result = message:gsub("()(|c%x%x%x%x%x%x%x%x|Hitem:.-|h.-|h|r)", function(at, link)
        local prefix = message:sub(1, at - 1)
        if prefix:match("|T[^|]-|t$") then return link end
        local icon = GetItemIcon and GetItemIcon(link)
        if not icon and GetItemInfo then icon = select(10, GetItemInfo(link)) end
        if icon then return string.format("|T%s:%d|t%s", icon, size, link) end
        return link
    end)
    return false, result, ...
end

local function Filter(...)
    return Module:FilterChat(...)
end

function Module:RemoveChatFilters()
    if not filtersAdded then return end
    for _, event in ipairs(CHAT_EVENTS) do ChatFrame_RemoveMessageEventFilter(event, Filter) end
    filtersAdded = false
end

function Module:RefreshChatFilters()
    self:RemoveChatFilters()
    if not self:IsActive("chat_icons") then return end
    for _, event in ipairs(CHAT_EVENTS) do ChatFrame_AddMessageEventFilter(event, Filter) end
    filtersAdded = true
end
