-- ItemLoot art/animations adapted from pretty_lootalert (s0h2x, pretty_wow).
local _, addon = ...
addon.ItemLoot = addon.ItemLoot or {}
local private = addon.ItemLoot
private.defaults = {
    enabled = true,
    scale = 1,
    duration = 4.05,
    interval = 0.30,
    max_toasts = 4,
    spacing = 4,
    anchor = "loot",
    point_x = 0,
    point_y = 0,
    grow_direction = "UP",
    sound = true,
    animations = true,
    qualities = { [0]=true, [1]=true, [2]=true, [3]=true, [4]=true, [5]=true, [6]=true, [7]=true },
    looting = true,
    creating = true,
    rolling = true,
    money = true,
    recipes = true,
    honor = true,
    equipment_only = false,
    minimum_item_level = 0,
    show_quantity = true,
}
function private.GetConfig()
    return addon:GetModuleConfig("itemloot") or private.defaults
end
-- A stable view ensures the rendered template always reads the current profile.
private.config = setmetatable({}, { __index = function(_, key)
    local value = private.GetConfig()[key]
    if value == nil then return private.defaults[key] end
    return value
end })
function private.Number(key, low, high)
    local value = tonumber(private.config[key]) or private.defaults[key]
    return math.max(low, math.min(high, value))
end
function private.IsEnabled()
    return addon:IsModuleEnabled("itemloot")
end
function private.AcceptItem(quality, itemLevel, equipLocation)
    quality = tonumber(quality)
    if quality == nil or quality < 0 or quality > 7 then return false end
    local qualities = private.config.qualities
    if type(qualities) ~= "table" then qualities = private.defaults.qualities end
    local enabled = qualities[quality]
    if enabled == nil then enabled = qualities[tostring(quality)] end
    if enabled == nil then enabled = private.defaults.qualities[quality] end
    if not enabled then return false end
    local equipped = equipLocation and equipLocation ~= "" and equipLocation ~= "INVTYPE_NON_EQUIP_IGNORE"
    if private.config.equipment_only and not equipped then return false end
    if equipped and (tonumber(itemLevel) or 0) < private.Number("minimum_item_level", 0, 1000) then return false end
    return true
end
