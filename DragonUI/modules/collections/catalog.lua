-- Mount data is loaded into DragonUI's private addon table before the journal.
local _, addon = ...
local catalog = { mounts = {} }
addon.MountCatalog = catalog

local MAX_ID = 2147483647
local MAX_NAME, MAX_MODEL = 200, 250
local MODEL_ROOTS = { creature = true, character = true, world = true }

local function validID(value)
    return type(value) == "number" and value > 0 and value <= MAX_ID and value == math.floor(value)
end

local function cleanName(value)
    if type(value) ~= "string" or #value > MAX_NAME or value:find("%c") or not value:find("%S") then return nil end
    return (value:gsub("|", "||"))
end

local function cleanModel(value)
    if type(value) ~= "string" or #value > MAX_MODEL or value:find("[%c|/:]") then return nil end
    local lower = value:lower()
    local root, path = lower:match("^([^\\]+)\\(.+)$")
    if not root or not MODEL_ROOTS[root] or path:sub(1, 1) == "\\" or path:find("\\\\", 1, true) then return nil end
    if not (path:match("[^\\]+%.m2$") or path:match("[^\\]+%.mdx$")) then return nil end
    for part in path:gmatch("[^\\]+") do
        if part == "." or part == ".." then return nil end
    end
    return value
end

local function mergeSource(source)
    if type(source) ~= "table" then return end
    for spellID, row in pairs(source) do
        if validID(spellID) and type(row) == "table" then
            local creatureID = validID(row[1]) and row[1] or nil
            local displayID = validID(row[4]) and row[4] or nil
            local model = cleanModel(row[5])
            if creatureID or displayID or model then
                local previous = catalog.mounts[spellID]
                local sameCreature = previous and previous.creatureID == creatureID
                catalog.mounts[spellID] = {
                    creatureID = creatureID,
                    name = cleanName(row[2]) or (previous and previous.name),
                    custom = row[3] == true,
                    displayID = displayID or (sameCreature and previous.displayID) or nil,
                    model = model or (sameCreature and (not displayID or displayID == previous.displayID)
                        and previous.model) or nil,
                }
            end
        end
    end
end

mergeSource(addon.BaseCatalog)
mergeSource(addon.ClientCatalog)
mergeSource(addon.RealmCatalog)

local textureModels = {}
if type(addon.TextureModels) == "table" then
    for displayID, path in pairs(addon.TextureModels) do
        if validID(displayID) then textureModels[displayID] = cleanModel(path) end
    end
end

function catalog.Stop(model)
    local timer = model._mountPreviewTimer
    if timer then
        timer:SetScript("OnUpdate", nil)
        timer:Hide()
    end
end

function catalog.Show(model, entry, callback)
    catalog.Stop(model)
    local timer = model._mountPreviewTimer
    if not timer then
        timer = CreateFrame("Frame", nil, model)
        model._mountPreviewTimer = timer
        model:HookScript("OnHide", catalog.Stop)
    end
    local methods = {}
    local function add(method, value)
        if value and type(model[method]) == "function" then methods[#methods + 1] = { method, value } end
    end
    add("SetDisplayInfo", entry.displayID)
    add("SetCreature", entry.creatureID)
    add("SetModel", textureModels[entry.displayID])
    add("SetModel", entry.model)

    local attempt, remaining = 0, 0
    local function tryNext()
        model:ClearModel()
        attempt = attempt + 1
        local option = methods[attempt]
        if not option then
            catalog.Stop(model)
            callback(false)
            return
        end
        local ok = pcall(model[option[1]], model, option[2])
        remaining = ok and 0.45 or 0
    end
    timer:SetScript("OnUpdate", function(_, elapsed)
        local path = model:GetModel()
        if type(path) == "string" and path ~= "" then
            catalog.Stop(model)
            callback(true)
            return
        end
        remaining = remaining - elapsed
        if remaining <= 0 then tryNext() end
    end)
    timer:Show()
    tryNext()
end
