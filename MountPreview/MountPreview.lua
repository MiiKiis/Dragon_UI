local _, addon = ...
local catalog = MountPreviewCatalog
local ROW_COUNT = 10
local icons = "Interface\\Icons\\"
local defaultIcon = icons .. "Ability_Mount_Charger"
local frame, search, model, heading, modelStatus, pageLabel, prev, nextPage, sourceButton
local rows, entries, matches = {}, {}, {}
local selected, page, source = nil, 1, 1
local sources = { "Todas", "Blizzlike", "Custom", "Aprendidas" }
local accent = { ["á"]="a", ["é"]="e", ["í"]="i", ["ó"]="o", ["ú"]="u", ["ü"]="u", ["ñ"]="n",
    ["Á"]="a", ["É"]="e", ["Í"]="i", ["Ó"]="o", ["Ú"]="u", ["Ü"]="u", ["Ñ"]="n" }

local function normalize(value)
    return (value:lower():gsub("\195[\128-\191]", accent))
end

local function rebuildEntries()
    local bySpell = {}
    for spellID, data in pairs(catalog.mounts) do
        local name, _, icon = GetSpellInfo(spellID)
        bySpell[spellID] = {
            spellID = spellID, creatureID = data.creatureID, custom = data.custom,
            name = (data.custom and data.name) or name or data.name or ("Hechizo " .. spellID),
            icon = icon or defaultIcon, displayID = data.displayID, model = data.model,
        }
    end
    for i = 1, GetNumCompanions("MOUNT") or 0 do
        local creatureID, name, spellID, icon = GetCompanionInfo("MOUNT", i)
        if spellID then
            local entry = bySpell[spellID] or {
                spellID = spellID, name = name or ("Hechizo " .. spellID), icon = icon or defaultIcon,
            }
            entry.owned = true
            entry.ownedCreature = creatureID and creatureID > 0 and creatureID
            bySpell[spellID] = entry
        end
    end
    wipe(entries)
    for _, entry in pairs(bySpell) do
        entry.searchName = normalize(entry.name)
        entries[#entries + 1] = entry
    end
    table.sort(entries, function(a, b)
        if a.searchName == b.searchName then return a.spellID < b.spellID end
        return a.searchName < b.searchName
    end)
end

local function loadPreview(entry)
    catalog.Stop(model)
    model:ClearModel()
    model:Hide()
    heading:SetText(entry and entry.name or "")
    modelStatus:SetText(entry and "Cargando modelo…" or "No hay monturas para mostrar.")
    if not entry then return end

    model:Show()
    addon:ResetModelView(model)
    addon:ResetModelRotation(model, 0.5)
    catalog.Show(model, entry, function(loaded, baseModel)
        if not loaded then
            model:Hide()
            modelStatus:SetText("Modelo no disponible en este cliente.")
            return
        end
        addon:ApplyModelView(model)
        modelStatus:SetText(baseModel and "Modelo base · el color puede variar" or "")
    end)
end

local function renderRows()
    local pages = math.max(1, math.ceil(#matches / ROW_COUNT))
    for i, row in ipairs(rows) do
        local entry = matches[(page - 1) * ROW_COUNT + i]
        row.entry = entry
        if entry then
            row.icon:SetTexture(entry.icon)
            row.label:SetText(entry.name)
            row.tag:SetText(entry.owned and "Aprendida" or (entry.custom and "Custom" or ""))
            if entry.spellID == selected then row:LockHighlight() else row:UnlockHighlight() end
            row:Show()
        else
            row:Hide()
        end
    end
    pageLabel:SetText(string.format("%d / %d  ·  %d monturas", page, pages, #matches))
    if page > 1 then prev:Enable() else prev:Disable() end
    if page < pages then nextPage:Enable() else nextPage:Disable() end
end

local function filterEntries()
    local query = normalize(search:GetText()):match("^%s*(.-)%s*$")
    local selectedIndex
    wipe(matches)
    for _, entry in ipairs(entries) do
        local sourceMatches = source == 1 or (source == 2 and entry.custom == false)
            or (source == 3 and entry.custom) or (source == 4 and entry.owned)
        if sourceMatches and (entry.searchName:find(query, 1, true) or tostring(entry.spellID) == query) then
            matches[#matches + 1] = entry
            if entry.spellID == selected then selectedIndex = #matches end
        end
    end
    local entry = matches[selectedIndex or 1]
    selected = entry and entry.spellID
    page = math.ceil((selectedIndex or 1) / ROW_COUNT)
    renderRows()
    loadPreview(entry)
end

local function button(parent, label, width)
    local widget = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    widget:SetSize(width, 22)
    widget:SetText(label)
    return widget
end

local function build()
    frame = CreateFrame("Frame", "MountPreviewFrame", UIParent)
    frame:SetSize(650, 414)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    tinsert(UISpecialFrames, frame:GetName())

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 16, -8)
    titleBar:SetPoint("TOPRIGHT", -40, -8)
    titleBar:SetHeight(26)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT")
    title:SetText("Visor de monturas")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    search = CreateFrame("EditBox", "MountPreviewSearch", frame, "InputBoxTemplate")
    search:SetSize(188, 22)
    search:SetPoint("TOPLEFT", 21, -43)
    search:SetAutoFocus(false)
    search:SetMaxLetters(100)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 2, 0)
    hint:SetText("Buscar por nombre o ID")
    search:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" then hint:Show() else hint:Hide() end
        filterEntries()
    end)
    sourceButton = button(frame, sources[source], 88)
    sourceButton:SetPoint("LEFT", search, "RIGHT", 8, 0)
    sourceButton:SetScript("OnClick", function(self)
        source = source % #sources + 1
        self:SetText(sources[source])
        filterEntries()
    end)

    for i = 1, ROW_COUNT do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(288, 28)
        row:SetPoint("TOPLEFT", 16, -73 - (i - 1) * 29)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(23, 23)
        row.icon:SetPoint("LEFT", 4, 0)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
        row.label:SetWidth(186)
        row.label:SetJustifyH("LEFT")
        row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.tag:SetPoint("RIGHT", -5, 0)
        row:SetScript("OnClick", function(self)
            if self.entry.spellID == selected then return end
            selected = self.entry.spellID
            search:ClearFocus()
            renderRows()
            loadPreview(self.entry)
        end)
        rows[i] = row
    end

    prev = button(frame, "<", 33)
    prev:SetPoint("BOTTOMLEFT", 16, 18)
    prev:SetScript("OnClick", function() page = page - 1; renderRows() end)
    nextPage = button(frame, ">", 33)
    nextPage:SetPoint("BOTTOMLEFT", 269, 18)
    nextPage:SetScript("OnClick", function() page = page + 1; renderRows() end)
    pageLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pageLabel:SetPoint("CENTER", prev, "CENTER", 126, 0)

    heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 320, -45)
    heading:SetPoint("TOPRIGHT", -16, -45)
    heading:SetHeight(32)
    model = CreateFrame("PlayerModel", nil, frame)
    model:SetPoint("TOPLEFT", 320, -80)
    model:SetPoint("BOTTOMRIGHT", -16, 65)
    addon:WireModelView(model, { facing = 0.5, pivot = addon.ModelPivot.creature })
    modelStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    modelStatus:SetPoint("BOTTOM", model, "BOTTOM", 0, -12)
    local controls = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    controls:SetPoint("BOTTOM", model, "BOTTOM", 0, -38)
    controls:SetText("Izq. girar · der. mover · rueda zoom · centro reiniciar")

    frame:SetScript("OnShow", function() rebuildEntries(); filterEntries() end)
    frame:SetScript("OnHide", function()
        frame:StopMovingOrSizing()
        search:ClearFocus()
        catalog.Stop(model)
    end)
    frame:RegisterEvent("COMPANION_LEARNED")
    frame:RegisterEvent("COMPANION_UNLEARNED")
    frame:SetScript("OnEvent", function(self)
        if self:IsShown() then rebuildEntries(); filterEntries() end
    end)
end

SLASH_MOUNTPREVIEW1 = "/monturas"
SLASH_MOUNTPREVIEW2 = "/mountpreview"
SlashCmdList.MOUNTPREVIEW = function()
    local collections = DragonUI and DragonUI.Collections
    if collections and collections.Toggle and collections:Enabled() then
        if collections.IsShown() and collections.Kind ~= "MOUNT" then
            collections.SelectKind("MOUNT")
        else
            collections.Toggle("MOUNT")
        end
        return
    end
    if not frame then build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
