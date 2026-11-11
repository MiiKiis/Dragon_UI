local _, addon = ...
local catalog = { mounts = {} }
MountPreviewCatalog = catalog

for _, source in ipairs({ addon.BaseCatalog, addon.ClientCatalog, addon.RealmCatalog }) do
    for spellID, row in pairs(source) do
        local previous = catalog.mounts[spellID]
        local sameCreature = previous and previous.creatureID == row[1]
        catalog.mounts[spellID] = {
            creatureID = row[1], name = row[2], custom = row[3],
            displayID = row[4] or (sameCreature and previous.displayID),
            model = row[5] or (sameCreature and (not row[4] or row[4] == previous.displayID) and previous.model),
        }
    end
end

function catalog.Stop(model)
    if model._mountPreviewTimer then
        model._mountPreviewTimer:SetScript("OnUpdate", nil)
        model._mountPreviewTimer:Hide()
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
    local function add(method, value, baseModel)
        if value and model[method] then methods[#methods + 1] = { method, value, baseModel } end
    end
    add("SetCreature", entry.ownedCreature)
    add("SetDisplayInfo", entry.displayID)
    if entry.creatureID ~= entry.ownedCreature then add("SetCreature", entry.creatureID) end
    add("SetModel", addon.TextureModels and addon.TextureModels[entry.displayID])
    add("SetModel", entry.model, true)

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
            callback(true, methods[attempt][3])
            return
        end
        remaining = remaining - elapsed
        if remaining <= 0 then tryNext() end
    end)
    timer:Show()
    tryNext()
end
