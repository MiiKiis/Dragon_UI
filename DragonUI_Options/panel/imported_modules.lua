-- Optional custom modules, presented through DragonUI's native controls.
local addon = DragonUI
if not addon then return end

local C, Panel, LO = addon.PanelControls, addon.OptionsPanel, addon.LO

local function Config(name)
    return C:EnsureModuleTable(name)
end

local function Enabled(name)
    return Config(name).enabled == true
end

local function Refresh(name)
    if addon.ModuleRegistry then addon.ModuleRegistry:Refresh(name) end
end

local function Toggle(parent, name, field, label, description)
    C:AddToggle(parent, {
        label = LO[label],
        desc = description and LO[description],
        getFunc = function() return Config(name)[field] == true end,
        setFunc = function(value) Config(name)[field] = value end,
        callback = function()
            Refresh(name)
            if name == "bnettoast" and field == "show_toast" then Panel:SelectTab("enhancements") end
        end,
        disabled = field ~= "enabled" and function() return not Enabled(name) end or nil,
        requiresReload = false,
    })
end

local function ModuleToggle(parent, name, label, description)
    C:AddToggle(parent, {
        label = LO[label],
        desc = LO[description],
        getFunc = function() return Enabled(name) end,
        setFunc = function(value)
            Config(name).enabled = value
            Refresh(name)
            -- Rebuild dependent controls immediately after enabling/disabling.
            Panel:SelectTab("enhancements")
        end,
        requiresReload = false,
    })
end

local function Slider(parent, name, field, label, minimum, maximum, step, fallback, description)
    local friendPosition = name == "bnettoast" and (field == "x_position" or field == "y_offset")
    C:AddSlider(parent, {
        label = LO[label],
        desc = description and LO[description],
        min = minimum, max = maximum, step = step, width = 200,
        getFunc = function()
            if friendPosition then
                local widget = addon.db.profile.widgets and addon.db.profile.widgets.bnToast
                if widget and widget.custom_position then
                    local position = widget[field == "x_position" and "posX" or "posY"]
                    if position ~= nil then return position end
                end
            end
            local value = Config(name)[field]
            return value ~= nil and value or fallback
        end,
        setFunc = function(value)
            local cfg = Config(name)
            if friendPosition then
                local widget = addon.db.profile.widgets and addon.db.profile.widgets.bnToast
                if widget and widget.custom_position then
                    cfg.x_position = widget.posX or cfg.x_position
                    cfg.y_offset = widget.posY or cfg.y_offset
                end
            end
            cfg[field] = value
            if friendPosition and addon.UpdateBNetToastPosition then addon.UpdateBNetToastPosition() end
        end,
        callback = function() Refresh(name) end,
        disabled = function() return not Enabled(name) end,
        requiresReload = false,
    })
end

local function Dropdown(parent, name, field, label, values, fallback, description)
    C:AddDropdown(parent, {
        label = LO[label],
        desc = description and LO[description],
        values = values, width = 220,
        getFunc = function()
            local value = Config(name)[field]
            return value ~= nil and value or fallback
        end,
        setFunc = function(value) Config(name)[field] = value end,
        callback = function() Refresh(name) end,
        disabled = function() return not Enabled(name) end,
        requiresReload = false,
    })
end

local QUALITY_FALLBACKS = {
    [0] = "Poor (gray)", [1] = "Common (white)", [2] = "Uncommon (green)",
    [3] = "Rare (blue)", [4] = "Epic (purple)", [5] = "Legendary (orange)",
    [6] = "Artifact", [7] = "Heirloom",
}

local function QualityLabel(quality)
    local text = _G["ITEM_QUALITY" .. quality .. "_DESC"] or LO[QUALITY_FALLBACKS[quality]]
    local colors = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if colors and colors.hex then return colors.hex .. text .. "|r" end
    return text
end

local function BuildItemLoot(scroll)
    local section = C:AddSection(scroll, LO["ItemLoot"])
    ModuleToggle(section, "itemloot", "Enable ItemLoot",
        "Show the original loot popups with your own size, filters and layout.")
    Slider(section, "itemloot", "scale", "Loot popup scale", 0.5, 2.5, 0.05, 1)
    Slider(section, "itemloot", "duration", "Display time (seconds)", 1, 15, 0.5, 4.05)
    Slider(section, "itemloot", "max_toasts", "Maximum visible popups", 1, 8, 1, 4)
    Slider(section, "itemloot", "spacing", "Popup spacing", 0, 40, 1, 4)
    Slider(section, "itemloot", "interval", "Delay between popups (seconds)", 0.1, 1, 0.05, 0.3)
    Toggle(section, "itemloot", "animations", "Animate loot popups")
    Toggle(section, "itemloot", "sound", "Loot notification sound")
    Toggle(section, "itemloot", "show_quantity", "Show item quantities")

    C:AddHeading(section, LO["Item qualities"])
    C:AddDescription(section, LO["Choose each quality separately. These filters affect item popups; money and honor have their own switches below."])
    local qualityRow = C:AddRow(section)
    for quality = 0, 7 do
        local selectedQuality = quality
        C:AddToggle(qualityRow, {
            label = QualityLabel(selectedQuality),
            relWidth = 0.5,
            getFunc = function()
                local qualities = Config("itemloot").qualities
                return not qualities or qualities[selectedQuality] ~= false
            end,
            setFunc = function(value)
                local cfg = Config("itemloot")
                cfg.qualities = cfg.qualities or {}
                cfg.qualities[selectedQuality] = value
            end,
            callback = function() Refresh("itemloot") end,
            disabled = function() return not Enabled("itemloot") end,
            requiresReload = false,
        })
    end
    Toggle(section, "itemloot", "equipment_only", "Only equippable items")
    Slider(section, "itemloot", "minimum_item_level", "Minimum equipment item level", 0, 1000, 1, 0,
        "Zero allows every item level. This filter applies to equipment, not crafting materials.")

    C:AddHeading(section, LO["Notification sources"])
    Toggle(section, "itemloot", "looting", "Looted items")
    Toggle(section, "itemloot", "creating", "Crafted items")
    Toggle(section, "itemloot", "rolling", "Items won by rolling")
    Toggle(section, "itemloot", "recipes", "Learned recipes")
    Toggle(section, "itemloot", "money", "Money received")
    Toggle(section, "itemloot", "honor", "Honor received")

    C:AddHeading(section, LO["Loot popup position"])
    Dropdown(section, "itemloot", "anchor", "Position relative to", {
        loot = LO["Loot roll anchor"], screen = LO["Screen center"],
    }, "loot", "Follow the loot roll mover or use a separate position relative to the screen center.")
    Dropdown(section, "itemloot", "grow_direction", "Stack direction", {
        UP = LO["Up"], DOWN = LO["Down"],
    }, "UP")
    Slider(section, "itemloot", "point_x", "Horizontal offset", -2000, 2000, 1, 0)
    Slider(section, "itemloot", "point_y", "Vertical offset", -1200, 1200, 1, 0)

    C:AddHeading(section, LO["Preview"])
    local qualityValues = {}
    for quality = 0, 7 do qualityValues[quality] = QualityLabel(quality) end
    Dropdown(section, "itemloot", "preview_quality", "Preview item quality", qualityValues, 4)
    C:AddDescription(section, LO["The preview ignores quality and equipment filters so you can inspect every popup style."])
    C:AddButton(section, {
        label = LO["Test loot popup"],
        callback = function()
            if addon.TestItemLoot then addon.TestItemLoot(Config("itemloot").preview_quality or 4) end
        end,
        disabled = function() return not Enabled("itemloot") end,
    })
    C:AddSpacer(scroll)
end

local function BuildIconic(scroll)
    local section = C:AddSection(scroll, LO["Iconic"])
    ModuleToggle(section, "iconic", "Enable Iconic",
        "Item icons in chat, merchant tools and item tooltip details.")
    Toggle(section, "iconic", "chat_icons", "Show item icons in chat")
    Slider(section, "iconic", "chat_icon_size", "Chat item icon size", 10, 32, 1, 15)
    Toggle(section, "iconic", "merchant_scroll", "Scroll merchant pages with the mouse wheel")
    Toggle(section, "iconic", "merchant_known", "Highlight already learned merchant items")
    Toggle(section, "iconic", "tooltip_classes", "Format class restrictions in tooltips")
    Toggle(section, "iconic", "tooltip_item_level", "Format item levels in tooltips",
        "Uses the item level supplied by the client and respects its item level display setting.")
    Toggle(section, "iconic", "tooltip_item_tags", "Show custom item tags in tooltips")
    C:AddSpacer(scroll)
end

local function BuildBNetToast(scroll)
    local section = C:AddSection(scroll, LO["BNetToast"])
    ModuleToggle(section, "bnettoast", "Enable BNetToast",
        "Friend and guild online/offline notifications.")
    Toggle(section, "bnettoast", "show_toast", "Show friend notification popups")
    Toggle(section, "bnettoast", "show_chat", "Show friend notifications in chat")
    Toggle(section, "bnettoast", "show_online", "Notify when friends connect")
    Toggle(section, "bnettoast", "show_offline", "Notify when friends disconnect")
    Toggle(section, "bnettoast", "guild_notify", "Include guild members")
    Toggle(section, "bnettoast", "show_toon", "Show character names")
    Toggle(section, "bnettoast", "show_zone", "Show the zone when available")
    Toggle(section, "bnettoast", "sound", "Friend notification sound")
    Slider(section, "bnettoast", "scale", "Friend popup scale", 0.5, 2.5, 0.05, 1)
    Slider(section, "bnettoast", "duration", "Display time (seconds)", 1, 15, 0.5, 5)
    Slider(section, "bnettoast", "max_queue", "Maximum queued friend notifications", 1, 50, 1, 20)
    Slider(section, "bnettoast", "x_position", "Horizontal offset", -2000, 2000, 1, 0)
    Slider(section, "bnettoast", "y_offset", "Vertical offset", -1200, 1200, 1, 200)
    C:AddDescription(section, LO["You can also move the friend popup in Editor Mode. These offsets set its position from the screen center."])
    C:AddButton(section, {
        label = LO["Test friend notification"],
        callback = function() if addon.TestBNetToast then addon.TestBNetToast() end end,
        disabled = function() return not Enabled("bnettoast") or not Config("bnettoast").show_toast end,
    })
    C:AddSpacer(scroll)
end

function addon.BuildImportedModuleOptions(scroll)
    BuildItemLoot(scroll)
    BuildIconic(scroll)
    BuildBNetToast(scroll)
end
