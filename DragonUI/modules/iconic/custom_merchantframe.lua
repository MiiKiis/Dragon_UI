local addon = select(2, ...)
local Module = addon.IconicModule
local wheelOwner, originalWheel, originalWheelEnabled
local colorChanges = {}
local scanTooltip
local merchantHooked = false
local showHooked = {}

local function SameColor(a, b)
    return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

local function RestoreColors()
    for texture, state in pairs(colorChanges) do
        if SameColor({ texture:GetVertexColor() }, state.applied) then
            texture:SetVertexColor(unpack(state.original))
        end
    end
    colorChanges = {}
end

local function CollectTextures(frame, textures)
    if not frame then return end
    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "Texture" and region.GetVertexColor then
                textures[region] = { region:GetVertexColor() }
            end
        end
    end
    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do CollectTextures(child, textures) end
    end
end

local function IsKnown(link)
    if not link or not ITEM_SPELL_KNOWN then return false end
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "DragonUIIconicMerchantScanTooltip", UIParent, "GameTooltipTemplate")
    end
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(link)
    local known = false
    for line = 2, scanTooltip:NumLines() do
        local text = _G[scanTooltip:GetName() .. "TextLeft" .. line]
        if text and text:GetText() == ITEM_SPELL_KNOWN then known = true; break end
    end
    scanTooltip:Hide()
    -- Never retain a negative result: a recipe may be learned while the vendor stays open.
    return known
end

function Module:RefreshKnownMerchant()
    RestoreColors()
    if not self:IsActive("merchant_known") or not MerchantFrame or not MerchantFrame:IsShown()
        or MerchantFrame.selectedTab ~= 1 then return end
    local count = GetMerchantNumItems()
    for i = 1, (MERCHANT_ITEMS_PER_PAGE or 10) do
        local index = ((MerchantFrame.page or 1) - 1) * (MERCHANT_ITEMS_PER_PAGE or 10) + i
        if index <= count and IsKnown(GetMerchantItemLink(index)) then
            local row = _G["MerchantItem" .. i]
            local button = _G["MerchantItem" .. i .. "ItemButton"]
            local textures = {}
            CollectTextures(row, textures)
            CollectTextures(button, textures)
            if row then
                if SetItemButtonNameFrameVertexColor then SetItemButtonNameFrameVertexColor(row, 0.3, 0.3, 0.3) end
                if SetItemButtonSlotVertexColor then SetItemButtonSlotVertexColor(row, 0.3, 0.3, 0.3) end
            end
            if button then
                if SetItemButtonTextureVertexColor then SetItemButtonTextureVertexColor(button, 0.3, 0.3, 0.3) end
                if SetItemButtonNormalTextureVertexColor then SetItemButtonNormalTextureVertexColor(button, 0.3, 0.3, 0.3) end
            end
            for texture, original in pairs(textures) do
                local applied = { texture:GetVertexColor() }
                if not SameColor(original, applied) then colorChanges[texture] = { original = original, applied = applied } end
            end
        end
    end
end

local function Wheel(frame, delta)
    if not Module:IsActive("merchant_scroll") then
        if originalWheel then return originalWheel(frame, delta) end
        return
    end
    if not frame:IsShown() or frame.selectedTab ~= 1 then
        if originalWheel then return originalWheel(frame, delta) end
        return
    end
    if delta > 0 and (frame.page or 1) > 1 then
        if MerchantPrevPageButton then MerchantPrevPageButton:Click() end
    elseif delta < 0 and (frame.page or 1) < math.ceil(GetMerchantNumItems() / (MERCHANT_ITEMS_PER_PAGE or 10)) then
        if MerchantNextPageButton then MerchantNextPageButton:Click() end
    end
end

function Module:RestoreMerchant()
    RestoreColors()
    if wheelOwner and wheelOwner:GetScript("OnMouseWheel") == Wheel then
        wheelOwner:SetScript("OnMouseWheel", originalWheel)
        if originalWheelEnabled ~= nil then wheelOwner:EnableMouseWheel(originalWheelEnabled) end
    end
    wheelOwner, originalWheel, originalWheelEnabled = nil, nil, nil
    if scanTooltip then scanTooltip:Hide() end
end

function Module:ApplyMerchant()
    if not MerchantFrame then return end
    if not merchantHooked and type(MerchantFrame_UpdateMerchantInfo) == "function" then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function() Module:RefreshKnownMerchant() end)
        merchantHooked = true
    end
    if not showHooked[MerchantFrame] then
        MerchantFrame:HookScript("OnShow", function() Module:RefreshKnownMerchant() end)
        MerchantFrame:HookScript("OnHide", RestoreColors)
        showHooked[MerchantFrame] = true
    end
    if self:IsActive("merchant_scroll") and MerchantFrame:GetScript("OnMouseWheel") ~= Wheel then
        wheelOwner = MerchantFrame
        originalWheel = MerchantFrame:GetScript("OnMouseWheel")
        originalWheelEnabled = MerchantFrame.IsMouseWheelEnabled and MerchantFrame:IsMouseWheelEnabled()
        MerchantFrame:EnableMouseWheel(true)
        MerchantFrame:SetScript("OnMouseWheel", Wheel)
    end
    self:RefreshKnownMerchant()
end
