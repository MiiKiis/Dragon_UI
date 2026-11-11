-- DragonUI's module registry owns ItemLoot activation and profile changes.
local _,addon = ...
local private = addon.ItemLoot
local module = { initialized=false, applied=false }
addon.ItemLootModule = module
local events = {"CHAT_MSG_LOOT","CHAT_MSG_SYSTEM","CHAT_MSG_MONEY","UPDATE_BATTLEFIELD_STATUS","UPDATE_BATTLEFIELD_SCORE"}
function addon.RestoreItemLootSystem()
    module.applied = false
    if private.frame then
        private.frame:UnregisterAllEvents()
        private.frame:Hide()
    end
    private.HideAllToasts()
end
function addon.RefreshItemLootSystem()
    if not private.IsEnabled() then addon.RestoreItemLootSystem(); return end
    module.initialized,module.applied = true,true
    if private.frame then
        for _,event in ipairs(events) do private.frame:RegisterEvent(event) end
        private.frame:Show()
    end
    for i=#private.alertQueue,1,-1 do
        if not private.ShouldDisplay(private.alertQueue[i]) then table.remove(private.alertQueue,i) end
    end
    local maxToasts = math.floor(private.Number("max_toasts",1,8))
    for i,button in ipairs(private.buttons) do
        button:SetScale(private.Number("scale",0.5,2.5))
        if not button.preview and (i>maxToasts or button.data and not private.ShouldDisplay(button.data)) then button:Hide() end
        if button:IsShown() then
            if private.config.animations == false then
                private.StopEffects(button)
            end
            private.UpdateToastAppearance(button)
        end
    end
    private.AdjustAnchors()
end
addon.ApplyItemLootSystem = addon.RefreshItemLootSystem
function addon.TestItemLoot(quality) return private.ShowPreview(quality,false) end
function private.ShowEditorPreview() return private.ShowPreview(4,true) end
function private.HideEditorPreview()
    for _,button in ipairs(private.buttons) do if button.stickyPreview then button:Hide() end end
end
if addon.RegisterModule then
    addon:RegisterModule("itemloot",module,
        (addon.L and addon.L["Loot Toast"]) or "Loot Toast",
        (addon.L and addon.L["Pretty loot toast alert notifications with custom textures."]) or "Pretty loot toast alert notifications with custom textures.",
        { lifecycle={apply="ApplyItemLootSystem",restore="RestoreItemLootSystem",refresh="RefreshItemLootSystem"} })
end
