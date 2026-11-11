-- Iconic extensions imported from the user's DragonUI edition.
-- Lifecycle and configuration adapted to NeticSoul DragonUI 3.3.5a.
local addon = select(2, ...)
local Module = {
    initialized = false,
    applied = false,
    decorators = {},
    tooltipHooks = {},
    tooltipChanges = {},
    pendingTooltips = {},
}
addon.IconicModule = Module

local function T(key)
    return addon.L and addon.L[key] or key
end

function Module:Config()
    return addon:GetModuleConfig("iconic") or {}
end

function Module:IsActive(feature)
    return self.applied and addon:IsModuleEnabled("iconic")
        and (not feature or self:Config()[feature] ~= false)
end

function addon:IsIconicEnabled()
    return Module:IsActive()
end

-- Remember only text written by Iconic. Other addons remain free to replace it.
function Module:WriteTooltip(tooltip, fontString, text)
    if not fontString or text == nil then return end
    local changes = self.tooltipChanges[tooltip]
    if not changes then changes = {}; self.tooltipChanges[tooltip] = changes end
    local change = changes[fontString]
    if not change then
        change = { original = fontString:GetText() }
        changes[fontString] = change
    end
    change.last = text
    fontString:SetText(text)
end

function Module:RestoreTooltip(tooltip)
    local changes = self.tooltipChanges[tooltip]
    if not changes then return end
    for fontString, change in pairs(changes) do
        if fontString:GetText() == change.last then fontString:SetText(change.original) end
    end
    self.tooltipChanges[tooltip] = nil
end

function Module:RegisterTooltipDecorator(feature, decorate)
    self.decorators[#self.decorators + 1] = { feature = feature, decorate = decorate }
end

function Module:DecorateTooltip(tooltip)
    self:RestoreTooltip(tooltip)
    if not self:IsActive() or not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    if not link then return end
    for _, entry in ipairs(self.decorators) do
        if self:IsActive(entry.feature) then entry.decorate(tooltip, link) end
    end
    if tooltip:IsShown() then tooltip:Show() end
end

local deferred = CreateFrame("Frame")
Module.deferredFrame = deferred
function Module:QueueTooltip(tooltip)
    if not self:IsActive() then return end
    local _, link = tooltip:GetItem()
    if not link then return end
    self.pendingTooltips[tooltip] = link
    deferred:SetScript("OnUpdate", function(frame)
        frame:SetScript("OnUpdate", nil)
        local pending = Module.pendingTooltips
        Module.pendingTooltips = {}
        if not Module:IsActive() then return end
        for target, expected in pairs(pending) do
            local _, current = target:GetItem()
            if target:IsShown() and current == expected then Module:DecorateTooltip(target) end
        end
    end)
end

local TOOLTIP_NAMES = {
    "GameTooltip", "ItemRefTooltip", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2",
    "ItemRefShoppingTooltip3", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3",
}

function Module:InstallTooltipHooks()
    for _, name in ipairs(TOOLTIP_NAMES) do
        local tooltip = _G[name]
        if tooltip and tooltip.HookScript and not self.tooltipHooks[tooltip] then
            self.tooltipHooks[tooltip] = true
            tooltip:HookScript("OnTooltipSetItem", function(target)
                if not Module:IsActive() then return end
                Module:DecorateTooltip(target)
                Module:QueueTooltip(target)
            end)
            tooltip:HookScript("OnTooltipCleared", function(target)
                Module.tooltipChanges[target] = nil
                Module.pendingTooltips[target] = nil
            end)
        end
    end
end

function addon.ApplyIconicSystem()
    Module.applied = true
    Module.initialized = true
    Module:InstallTooltipHooks()
    if Module.RefreshChatFilters then Module:RefreshChatFilters() end
    if Module.ApplyMerchant then Module:ApplyMerchant() end
    for tooltip in pairs(Module.tooltipHooks) do
        if tooltip:IsShown() then Module:DecorateTooltip(tooltip) end
    end
end

function addon.RestoreIconicSystem()
    Module.applied = false
    Module.pendingTooltips = {}
    deferred:SetScript("OnUpdate", nil)
    if Module.RemoveChatFilters then Module:RemoveChatFilters() end
    if Module.RestoreMerchant then Module:RestoreMerchant() end
    for tooltip in pairs(Module.tooltipChanges) do
        Module:RestoreTooltip(tooltip)
        if tooltip:IsShown() then tooltip:Show() end
    end
end

function addon.RefreshIconicSystem()
    addon.RestoreIconicSystem()
    if addon:IsModuleEnabled("iconic") then addon.ApplyIconicSystem() end
end

if addon.RegisterModule then
    addon:RegisterModule("iconic", Module, T("Iconic"),
        T("Item icons in chat, merchant improvements, and enhanced item tooltips."), {
            lifecyclePrefix = "Iconic",
            lifecycle = {
                apply = "ApplyIconicSystem",
                restore = "RestoreIconicSystem",
                refresh = "RefreshIconicSystem",
            },
        })
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_ENTERING_WORLD" or (event == "ADDON_LOADED" and name == "DragonUI") then
        addon.RefreshIconicSystem()
    elseif Module:IsActive() then
        Module:InstallTooltipHooks()
        if Module.ApplyMerchant then Module:ApplyMerchant() end
    end
end)
