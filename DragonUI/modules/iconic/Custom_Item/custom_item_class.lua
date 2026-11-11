local addon = select(2, ...)
local Module = addon.IconicModule

local CLASS_COLORS = {
    Warrior = "c69b6d", Guerrero = "c69b6d", ["Воин"] = "c69b6d",
    Paladin = "f48cba", ["Paladín"] = "f48cba", ["Паладин"] = "f48cba",
    Hunter = "aad372", Cazador = "aad372", ["Охотник"] = "aad372",
    Rogue = "fff468", ["Pícaro"] = "fff468", ["Разбойник"] = "fff468",
    Priest = "ffffff", Sacerdote = "ffffff", ["Жрец"] = "ffffff",
    ["Death Knight"] = "c41e3a", ["Caballero de la Muerte"] = "c41e3a", ["Рыцарь смерти"] = "c41e3a",
    Shaman = "0070de", ["Chamán"] = "0070de", ["Шаман"] = "0070de",
    Mage = "69ccf0", Mago = "69ccf0", ["Маг"] = "69ccf0",
    Warlock = "9482c9", Brujo = "9482c9", ["Чернокнижник"] = "9482c9",
    Druid = "ff7d0a", Druida = "ff7d0a", ["Друид"] = "ff7d0a",
}

local function Plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function ColorFor(name)
    for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {}, LOCALIZED_CLASS_NAMES or {} }) do
        for token, localized in pairs(names) do
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
            if localized == name and color then
                return string.format("%02x%02x%02x", math.floor(color.r * 255 + 0.5),
                    math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5))
            end
        end
    end
    return CLASS_COLORS[name]
end

local function ClassesPrefix()
    local format = ITEM_CLASSES_ALLOWED
    if type(format) == "string" then
        local at = format:find("%s", 1, true)
        if at and at > 1 then return format:sub(1, at - 1) end
    end
end

Module:RegisterTooltipDecorator("tooltip_classes", function(tooltip)
    local name = tooltip:GetName()
    if not name then return end
    for i = 1, tooltip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        local text = line and line:GetText()
        if text then
            local plain = Plain(text)
            local prefix = ClassesPrefix()
            if not prefix or plain:sub(1, #prefix) ~= prefix then
                prefix = plain:match("^(Classes:%s*)") or plain:match("^(Clases:%s*)") or plain:match("^(Классы:%s*)")
            end
            if prefix and plain:sub(1, #prefix) == prefix then
                local classes = {}
                for entry in plain:sub(#prefix + 1):gmatch("[^,]+") do
                    local label = entry:match("^%s*(.-)%s*$")
                    local color = ColorFor(label)
                    classes[#classes + 1] = color and ("|cff" .. color .. label .. "|r") or label
                end
                -- Keep names unknown to the stock client (CoA/custom classes).
                if #classes > 0 then Module:WriteTooltip(tooltip, line, prefix .. table.concat(classes, ", ")) end
            end
        end
    end
end)
