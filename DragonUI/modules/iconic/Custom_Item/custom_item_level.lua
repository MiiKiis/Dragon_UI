local addon = select(2, ...)
local Module = addon.IconicModule

local function Plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function IsItemLevelLine(text)
    if not text then return false end
    local plain = Plain(text)
    local format = ITEM_LEVEL
    if type(format) == "string" then
        local at = format:find("%d", 1, true)
        if at and at > 1 then
            local prefix = format:sub(1, at - 1)
            if plain:sub(1, #prefix) == prefix and plain:sub(#prefix + 1):match("^%s*%d+") then return true end
        end
    end
    return plain:match("^%s*Item Level%s+%d+") or plain:match("^%s*Nivel de objeto%s+%d+")
        or plain:match("^%s*Уровень предмета:%s*%d+")
end

Module:RegisterTooltipDecorator("tooltip_item_level", function(tooltip)
    local name = tooltip:GetName()
    local title = name and _G[name .. "TextLeft1"]
    local text = title and title:GetText()
    if not text then return end
    -- Use only the client's existing item-level line. Do not force its CVar or add stale GetItemInfo data.
    for i = 2, tooltip:NumLines() do
        for _, side in ipairs({ "Left", "Right" }) do
            local line = _G[name .. "Text" .. side .. i]
            local lineText = line and line:GetText()
            if IsItemLevelLine(lineText) then
                Module:WriteTooltip(tooltip, line, "")
                Module:WriteTooltip(tooltip, title, text .. "\n|cffffd100" .. Plain(lineText) .. "|r")
                return
            end
        end
    end
end)
