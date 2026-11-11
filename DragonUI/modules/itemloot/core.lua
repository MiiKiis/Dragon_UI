-- ItemLoot art and animation rendering adapted from pretty_lootalert (s0h2x, pretty_wow).
local _,addon = ...
local private = addon.ItemLoot
local config = private.config
local tInsert, tRemove = table.insert, table.remove
local playerFaction = UnitFactionGroup("player") or "Alliance"
local playerName = UnitName("player")
local YOU_RECEIVED_LABEL = private.labels.YOU_RECEIVED_LABEL
local YOU_WON_LABEL = private.labels.YOU_WON_LABEL
local YOU_CREATED_LABEL = private.labels.YOU_CREATED_LABEL
local YOU_EARNED_LABEL = private.labels.YOU_EARNED_LABEL
local NEW_RECIPE_LEARNED_TITLE = private.labels.NEW_RECIPE_LEARNED_TITLE
local LEGENDARY_ITEM_LOOT_LABEL = private.labels.LEGENDARY_ITEM_LOOT_LABEL
local TOAST_PROFESSION_COOKING = private.labels.TOAST_PROFESSION_COOKING
local TOAST_PROFESSION_FIRST_AID = private.labels.TOAST_PROFESSION_FIRST_AID
local TOAST_PROFESSION_FISHING = private.labels.TOAST_PROFESSION_FISHING
local TOAST_PROFESSION_ALCHEMY = private.labels.TOAST_PROFESSION_ALCHEMY
local TOAST_PROFESSION_TAILORING = private.labels.TOAST_PROFESSION_TAILORING
local TOAST_PROFESSION_JEWELCRAFTING = private.labels.TOAST_PROFESSION_JEWELCRAFTING
local TOAST_PROFESSION_ENCHANTING = private.labels.TOAST_PROFESSION_ENCHANTING
local TOAST_PROFESSION_BLACKSMITHING = private.labels.TOAST_PROFESSION_BLACKSMITHING
local TOAST_PROFESSION_ENGINEERING = private.labels.TOAST_PROFESSION_ENGINEERING
local TOAST_PROFESSION_MINING = private.labels.TOAST_PROFESSION_MINING
local TOAST_PROFESSION_LEATHERWORKING = private.labels.TOAST_PROFESSION_LEATHERWORKING
local TOAST_PROFESSION_INSCRIPTION = private.labels.TOAST_PROFESSION_INSCRIPTION
local ITEM_TYPE_RECIPE = private.labels.ITEM_TYPE_RECIPE
local ITEM_TYPE_PLANS = private.labels.ITEM_TYPE_PLANS
local ITEM_TYPE_FORMULA = private.labels.ITEM_TYPE_FORMULA
local ITEM_TYPE_SCHEMATIC = private.labels.ITEM_TYPE_SCHEMATIC
local ITEM_TYPE_MANUAL = private.labels.ITEM_TYPE_MANUAL
local ITEM_TYPE_TECHNIQUE = private.labels.ITEM_TYPE_TECHNIQUE
local ITEM_TYPE_DESIGN = private.labels.ITEM_TYPE_DESIGN
local ITEM_TYPE_PATTERN = private.labels.ITEM_TYPE_PATTERN
local ITEM_TYPE_MOUNT = private.labels.ITEM_TYPE_MOUNT
local ITEM_TYPE_MOUNTS = private.labels.ITEM_TYPE_MOUNTS

-- /* assets */
local assets = [[Interface\AddOns\DragonUI\modules\itemloot\assets\]];
local picn = assets.."UI-TradeSkill-Circle";
local SOUNDKIT = {
	UI_EPICLOOT_TOAST = assets.."ui_epicloot_toast_01.ogg",
	UI_GARRISON_FOLLOWER_LEARN_TRAIT = assets.."ui_garrison_follower_trait_learned_02.ogg",
	UI_LEGENDARY_LOOT_TOAST = assets.."ui_legendary_item_toast.ogg",
	UI_RAID_LOOT_TOAST_LESSER_ITEM_WON = assets.."ui_loot_toast_lesser_item_won_01.ogg",
};

-- /* consts */
local LE_ITEM_QUALITY_COMMON = 1;
local LE_ITEM_QUALITY_EPIC = 4;
local LE_ITEM_QUALITY_HEIRLOOM = 7;
local LE_ITEM_QUALITY_LEGENDARY = 5;
local LE_ITEM_QUALITY_POOR = 0;
local LE_ITEM_QUALITY_RARE = 3;
local LE_ITEM_QUALITY_UNCOMMON = 2;
local LE_ITEM_QUALITY_WOW_TOKEN = 8;
local LE_ITEM_QUALITY_ARTIFACT = 6;

local LOOT_ROLL_TYPE_NEED = 1;
local LOOT_ROLL_TYPE_GREED = 2;
local LOOT_ROLL_TYPE_DISENCHANT = 3;

local LOOT_BORDER_BY_QUALITY = {
	[LE_ITEM_QUALITY_UNCOMMON] = {0.34082, 0.397461, 0.53125, 0.644531},
	[LE_ITEM_QUALITY_RARE] = {0.272461, 0.329102, 0.785156, 0.898438},
	[LE_ITEM_QUALITY_EPIC] = {0.34082, 0.397461, 0.882812, 0.996094},
	[LE_ITEM_QUALITY_LEGENDARY] = {0.34082, 0.397461, 0.765625, 0.878906},
	[LE_ITEM_QUALITY_HEIRLOOM] = {0.34082, 0.397461, 0.648438, 0.761719},
	[LE_ITEM_QUALITY_ARTIFACT] = {0.272461, 0.329102, 0.667969, 0.78125},
};
local HONOR_BACKGROUND_TCOORDS = {
	["Alliance"] = {277, 113, 0.001953, 0.542969, 0.460938, 0.902344},
	["Horde"] = {281, 115, 0.001953, 0.550781, 0.003906, 0.453125},
};
local SUB_COORDS = HONOR_BACKGROUND_TCOORDS[playerFaction] or HONOR_BACKGROUND_TCOORDS.Alliance;
local HONOR_BADGE = {SUB_COORDS[3], SUB_COORDS[4], SUB_COORDS[5], SUB_COORDS[6]};

local PROFESSION_ICON_TCOORDS = {
	[TOAST_PROFESSION_ENCHANTING]		= {0, 0.25, 0, 0.25},
	[TOAST_PROFESSION_ALCHEMY]		= {0.25, 0.49609375, 0, 0.25},
	[TOAST_PROFESSION_BLACKSMITHING]		= {0.49609375, 0.7421875, 0, 0.25},
	[TOAST_PROFESSION_COOKING]		= {0.7421875, 0.98828125, 0, 0.25},
	[TOAST_PROFESSION_ENGINEERING]		= {0, 0.25, 0.25, 0.5},
	[TOAST_PROFESSION_FIRST_AID]	 	= {0.25, 0.49609375, 0.25, 0.5},
	[TOAST_PROFESSION_FISHING]		= {0.49609375, 0.7421875, 0.25, 0.5},
	[TOAST_PROFESSION_TAILORING]		= {0.7421875, 0.98828125, 0.25, 0.5},
	[TOAST_PROFESSION_INSCRIPTION]		= {0, 0.25, 0.5, 0.75},
	[TOAST_PROFESSION_JEWELCRAFTING]	= {0.25, .5, 0.5, .75},
	[TOAST_PROFESSION_LEATHERWORKING]		= {0.5, 0.73828125, 0.5, .75},
	-- [TOAST_PROFESSION_MINING]	= {0.7421875, 0.98828125, 0.5, 0.75},
};


-- The queue owns only ItemLoot frames; no Blizzard LootAlert globals are replaced.
local MAX_BUTTONS, MAX_QUEUE, MAX_PENDING = 8, 100, 100
private.buttons, private.alertQueue, private.pending = {}, {}, {}
local seenRolls, awardedBattleground = {}, nil
local rollAge = 0
local elapsedQueue, elapsedPending = 0, 0

local function settingOn(name) return config[name] ~= false end
local function stopEffects(button)
    for _,key in ipairs({"glow","shine","legendaryGlow","legendaryShine","recipeGlow","recipeShine"}) do
        local region = button[key]
        if region then if region.animIn then region.animIn:Stop() end; region:Hide() end
    end
end
-- Lua is the only owner of a toast's alpha and lifetime. Wrath's native XML Alpha
-- delay/OnFinished chain could fade and hide it before the requested readable hold.
local FADE_IN_SECONDS, FADE_OUT_SECONDS = 0.2, 1.5
function private.UpdateToastAppearance(button)
    if button.stickyPreview then button:SetAlpha(1); return end
    local age = button.age or 0
    local hold = private.Number("duration",1,15)
    if not settingOn("animations") then
        if age >= hold then button:Hide() else button:SetAlpha(1) end
    elseif age < FADE_IN_SECONDS then
        button:SetAlpha(age / FADE_IN_SECONDS)
    elseif age < FADE_IN_SECONDS + hold then
        button:SetAlpha(1)
    elseif age < FADE_IN_SECONDS + hold + FADE_OUT_SECONDS then
        button:SetAlpha(1 - (age - FADE_IN_SECONDS - hold) / FADE_OUT_SECONDS)
    else
        button:Hide()
    end
end
private.StopEffects = stopEffects
function private.HideAllToasts()
    private.clearing = true
    for _, button in ipairs(private.buttons) do
        stopEffects(button)
        button:Hide()
        button.data,button.preview,button.stickyPreview = nil,nil,nil
    end
    private.alertQueue, private.pending = {}, {}
    seenRolls = {}
    private.clearing = nil
end
function private.AdjustAnchors()
    local previous
    local anchor = config.anchor == "loot" and (_G.DragonUI_LootRollAnchor
        or (addon.LootRollModule and addon.LootRollModule.anchorFrame)) or UIParent
    anchor = anchor or UIParent
    for _, button in ipairs(private.buttons) do
        if button:IsShown() then
            button:ClearAllPoints()
            if previous then
                if config.grow_direction == "DOWN" then
                    button:SetPoint("TOP", previous, "BOTTOM", 0, -private.Number("spacing",0,80))
                else
                    button:SetPoint("BOTTOM", previous, "TOP", 0, private.Number("spacing",0,80))
                end
            else
                button:SetPoint("CENTER", anchor, "CENTER", private.Number("point_x",-4000,4000), private.Number("point_y",-4000,4000))
            end
            previous = button
        end
    end
end
local function shouldDisplay(data)
    if data.preview then return true end
    local category = data.category
    if category and not settingOn(category) then return false end
    if category == "looting" or category == "creating" or category == "rolling" then
        return private.AcceptItem(data.quality,data.itemLevel,data.equipLocation)
    end
    return true
end
private.ShouldDisplay = shouldDisplay
local function addAlert(data)
    if not private.IsEnabled() or #private.alertQueue >= MAX_QUEUE then return false end
    private.alertQueue[#private.alertQueue+1] = data
    return true
end
private.AddAlert = addAlert
local function toastFor(quality, level, subtype)
    if subtype == (private.labels.ITEM_TYPE_MOUNT or "Mount") or subtype == private.labels.ITEM_TYPE_MOUNTS then return "mounttoast" end
    if subtype == PET or subtype == PETS then return "pettoast" end
    if quality == 5 then return "legendarytoast" end
    if quality <= 1 then return "commontoast" end
    if level and level >= 271 then return "heroictoast" end
    return "defaulttoast"
end
local function itemAlert(item)
    local name,link,quality,level,_,_,subtype,_,equip,texture = GetItemInfo(item.link)
    if not name or not link or quality == nil then return false end
    if not settingOn(item.category) then return true end
    if not private.AcceptItem(quality,level,equip) then return true end
    local label = item.label
    if quality == 5 then label = LEGENDARY_ITEM_LOOT_LABEL end
    addAlert({name=name,link=link,quality=quality,texture=texture,count=item.count,label=label,
        toast=toastFor(quality,level,subtype),rollType=item.rollType,rollLink=item.roll,
        category=item.category,itemLevel=level,equipLocation=equip})
    return true
end
function private.QueueItem(link,count,category,label,rollType,roll)
    if not private.IsEnabled() or not link or not settingOn(category) then return end
    local item = {link=link,count=tonumber(count) or 1,category=category,label=label,rollType=rollType,roll=roll,tries=0}
    if not itemAlert(item) and #private.pending < MAX_PENDING then private.pending[#private.pending+1] = item end
end
-- Learning messages contain a recipe/spell name, not necessarily a recipe item.
-- Resolve that exact recipe; never use the whole profession icon atlas as an icon.
local function recipeIcon(skill)
    local name = skill:match("|h%[(.-)%]|h") or skill
    if GetNumTradeSkills and GetTradeSkillInfo and GetTradeSkillIcon then
        for i = 1, GetNumTradeSkills() do
            local recipeName, kind = GetTradeSkillInfo(i)
            if recipeName == name and kind ~= "header" then
                local icon = GetTradeSkillIcon(i)
                if icon then return icon end
            end
        end
    end
    -- Enchanting and other craft-style profession windows use the Craft API in Wrath.
    if GetNumCrafts and GetCraftInfo and GetCraftIcon then
        for i = 1, GetNumCrafts() do
            local recipeName, _, kind = GetCraftInfo(i)
            if recipeName == name and kind ~= "header" then
                local icon = GetCraftIcon(i)
                if icon then return icon end
            end
        end
    end
    if GetSpellInfo then
        local spellID = skill:match("spell:(%d+)")
        local _, _, icon = GetSpellInfo(tonumber(spellID) or name)
        if icon then return icon end
    end
    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(name)
    return icon or "Interface\\Icons\\INV_Scroll_04"
end
private.GetLearnedRecipeIcon = recipeIcon
local function recipeAlert(skill)
    local function enqueue()
        local _,link,quality = GetItemInfo(skill)
        addAlert({name=skill,link=link,quality=quality or 1,texture=recipeIcon(skill),toast="recipetoast",label=NEW_RECIPE_LEARNED_TITLE,
            tip=(ERR_LEARN_RECIPE_S and ERR_LEARN_RECIPE_S:gsub("%%s",function() return skill end)) or skill,category="recipes"})
    end
    -- Let the profession list catch up with the learn message before looking up its icon.
    if addon.After then addon:After(0.1, enqueue) else enqueue() end
end
local function lootMessage(message)
    if type(message) ~= "string" then return end
    local wonLink = private.Match(message,LOOT_ROLL_YOU_WON)
    if wonLink then seenRolls[wonLink] = seenRolls[wonLink] or {}; return end
    for kind,fmt in pairs({[1]=LOOT_ROLL_YOU_WON_NO_SPAM_NEED,[2]=LOOT_ROLL_YOU_WON_NO_SPAM_GREED,[3]=LOOT_ROLL_YOU_WON_NO_SPAM_DE}) do
        local roll,link = private.Match(message,fmt)
        if link then seenRolls[link]={kind=kind,value=roll};return end
    end
    local name,count = private.Match(message,LOOT_ITEM_CREATED_SELF_MULTIPLE)
    if not name then name = private.Match(message,LOOT_ITEM_CREATED_SELF) end
    if name then return private.QueueItem(name,count,"creating",YOU_CREATED_LABEL) end
    -- Group winners can be announced before the normal self-loot line. The self-loot line is the
    -- reliable source of the actual quantity and is emitted exactly once per item received.
    name,count = private.Match(message,LOOT_ITEM_SELF_MULTIPLE)
    if not name then name = private.Match(message,LOOT_ITEM_SELF) end
    if name then
        local roll = seenRolls[name]
        seenRolls[name] = nil
        local category = roll and "rolling" or "looting"
        private.QueueItem(name,count,category,roll and YOU_WON_LABEL or YOU_RECEIVED_LABEL,roll and roll.kind,roll and roll.value)
        return
    end
    for kind, fmt in pairs({[1]=LOOT_ROLL_ROLLED_NEED,[2]=LOOT_ROLL_ROLLED_GREED,[3]=LOOT_ROLL_ROLLED_DE}) do
        local roll,link,who = private.Match(message,fmt)
        if link and who == playerName then
            if not seenRolls[link] then seenRolls[link] = {} end
            seenRolls[link].kind,seenRolls[link].value = kind,roll
        end
    end
end
local function moneyMessage(message)
    if not settingOn("money") then return end
    local amount = private.Match(message,YOU_LOOT_MONEY)
    if not amount then amount = private.Match(message,LOOT_MONEY_SPLIT) end
    if not amount then return end
    -- Money formats are combined ("1 Gold, 2 Silver"); isolate each localized coin suffix.
    local function coin(fmt)
        if type(fmt) ~= "string" then return 0 end
        local pattern = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])","%%%1"):gsub("%%d","(%%d+)")
        return tonumber(amount:match(pattern)) or 0
    end
    local copper = coin(GOLD_AMOUNT)*10000+coin(SILVER_AMOUNT)*100+coin(COPPER_AMOUNT)
    if copper <= 0 then return end
    addAlert({name=GetMoneyString(copper,true),quality=6,toast="moneytoast",money=copper,label=YOU_RECEIVED_LABEL,category="money"})
end
local function battlefieldAlert()
    if not settingOn("honor") or not GetBattlefieldWinner or IsActiveBattlefieldArena and IsActiveBattlefieldArena() then return end
    local winner = GetBattlefieldWinner()
    if winner == nil then awardedBattleground = nil; return end
    if awardedBattleground then return end
    if not GetNumBattlefieldScores or not GetBattlefieldScore then return end
    for i=1,GetNumBattlefieldScores() do
        local name,_,_,_,honor = GetBattlefieldScore(i)
        if name == playerName or name and name:match("^[^-]+") == playerName then
            if (tonumber(honor) or 0) > 0 then
                addAlert({name=HONOR_POINTS or "Honor",quality=6,texture=assets.."PVPCurrency-Honor-"..playerFaction,
                    count=honor,label=YOU_EARNED_LABEL,toast="battlefieldtoast",tip=TOOLTIP_HONOR_POINTS,category="honor"})
                awardedBattleground = true
            end
            return
        end
    end
end
function DragonUIItemLootFrame_OnLoad(self)
    private.frame = self
    self.elapsedQueue = 0
    if addon.RefreshItemLootSystem then addon.RefreshItemLootSystem() end
end
function DragonUIItemLootFrame_OnEvent(self,event,...)
    if not private.IsEnabled() then return end
    local message = ...
    if event == "CHAT_MSG_LOOT" then lootMessage(message)
    elseif event == "CHAT_MSG_MONEY" then moneyMessage(message)
    elseif event == "CHAT_MSG_SYSTEM" and settingOn("recipes") then
        local skill = private.Match(message,ERR_LEARN_RECIPE_S)
        if skill then recipeAlert(skill) end
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        if RequestBattlefieldScoreData then RequestBattlefieldScoreData() end
        battlefieldAlert()
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then battlefieldAlert() end
end
local function present(button,data,preview,sticky)
    button.data,button.preview,button.stickyPreview = data,preview,sticky
    button:SetScale(private.Number("scale",0.5,2.5))
    button.age = 0
    button:SetAlpha(settingOn("animations") and not sticky and 0 or 1)
    button:Show()
    private.AdjustAnchors()
end
function DragonUIItemLootFrame_OnUpdate(self,elapsed)
    if not private.IsEnabled() then return end
    for _,button in ipairs(private.buttons) do
        if button:IsShown() and not button.stickyPreview then
            button.age = (button.age or 0)+elapsed
            private.UpdateToastAppearance(button)
        end
    end
    rollAge = rollAge + elapsed
    if rollAge >= 60 then seenRolls = {}; rollAge = 0 end
    elapsedPending = elapsedPending + elapsed
    if elapsedPending >= 0.2 then
        elapsedPending = 0
        local i = 1
        while i <= #private.pending do
            local item = private.pending[i]
            item.tries = item.tries+1
            if itemAlert(item) or item.tries >= 25 then
                table.remove(private.pending,i)
            else
                i = i+1
            end
        end
    end
    elapsedQueue = elapsedQueue + elapsed
    if elapsedQueue >= private.Number("interval",0.1,1) and #private.alertQueue > 0 then
        elapsedQueue = 0
        local limit = math.floor(private.Number("max_toasts",1,8))
        for i=1,limit do
            local button = private.buttons[i]
            if button and not button:IsShown() then
                local data
                repeat
                    data = table.remove(private.alertQueue,1)
                until not data or shouldDisplay(data)
                if data then present(button,data) end
                break
            end
        end
    end
end
function DragonUIItemLootButtonTemplate_OnLoad(self)
    self:RegisterForClicks("LeftButtonUp","RightButtonUp")
    private.buttons[#private.buttons+1] = self
end
function private.ShowPreview(quality,sticky)
    if not private.IsEnabled() then return false end
    quality = math.floor(math.max(0,math.min(7,tonumber(quality) or 4)))
    local button
    local maxToasts = math.floor(private.Number("max_toasts",1,8))
    for i=1,maxToasts do
        local candidate = private.buttons[i]
        if candidate and not candidate:IsShown() then button=candidate;break end
    end
    if not button then return false end
    present(button,{name="DragonUI — "..((ITEM_QUALITY_DESC and ITEM_QUALITY_DESC[quality]) or _G["ITEM_QUALITY"..quality.."_DESC"] or tostring(quality)),
        quality=quality,texture="Interface\\Icons\\INV_Misc_Gem_01",count=3,label=(addon.L and addon.L["Loot Toast Preview"]) or "Loot Toast Preview",
        toast=toastFor(quality,100)},true,sticky)
    return true
end

-- [[ NewRecipeLearnedAlertFrame ]] --
local function NewRecipeLearnedAlertFrame_GetStarTextureFromRank(quality)
	if quality == 2 then
		return "|T"..assets.."toast-star:12:12:0:0:32:32:0:21:0:21|t";
	elseif quality == 3 then
		return "|T"..assets.."toast-star-2:12:24:0:0:64:32:0:42:0:21|t";
	elseif quality == 4 then
		return "|T"..assets.."toast-star-3:12:36:0:0:64:32:0:64:0:21|t";
	end
	return nil;
end

function DragonUIItemLootButtonTemplate_OnShow(self)
	if not self.data then
		self:Hide();
		return;
	end

	local data = self.data;
	if data.name then
		local defaultToast 		= data.toast == "defaulttoast";
		local recipeToast 		= data.toast == "recipetoast";
		local battlefieldToast  = data.toast == "battlefieldtoast";
		local moneyToast 		= data.toast == "moneytoast";
		local legendaryToast 	= data.toast == "legendarytoast";
		local commonToast 		= data.toast == "commontoast";
		local qualityColor 		= ITEM_QUALITY_COLORS[data.quality] or nil;
		local averageToast		= not recipeToast and not moneyToast and not commonToast;

		if data.count and config.show_quantity then
			self.Count:SetText(data.count);
		else
			self.Count:SetText(" ");
		end

		self.Icon:SetTexture(data.texture);
		private.SetShown(self.Icon, averageToast);
		private.SetShown(self.IconBorder, averageToast);
		self.LessIcon:SetTexture(data.texture);
		self.ItemName:SetText(data.name);
		private.SetShown(self.ItemName, averageToast);
		self.LessItemName:SetText(data.name);
		self.Label:SetText(data.label);
		private.SetShown(self.Label, averageToast);
		private.SetShown(self.RollWon, data.rollLink);
		private.SetShown(self.MoneyLabel, moneyToast);
        self.MoneyLabel:SetText(data.label or YOU_RECEIVED_LABEL);
		private.SetShown(self.Amount, moneyToast);
		self.Amount:SetText(data.name);

		private.SetShown(self.Background, defaultToast);
		private.SetShown(self.HeroicBackground, data.toast == "heroictoast");
		private.SetShown(self.PvPBackground, battlefieldToast);
		self.PvPBackground:SetSize(SUB_COORDS[1], SUB_COORDS[2]);
		self.PvPBackground:SetTexCoord(unpack(HONOR_BADGE));
		private.SetShown(self.RecipeBackground, recipeToast);
		private.SetShown(self.RecipeTitle, recipeToast);
		private.SetShown(self.RecipeName, recipeToast);
		private.SetShown(self.RecipeIcon, recipeToast);
		private.SetShown(self.LessBackground, commonToast);
		private.SetShown(self.LessItemName, commonToast);
		private.SetShown(self.LessIcon, commonToast);
		private.SetShown(self.LegendaryBackground, legendaryToast);
		private.SetShown(self.RollWonTitle, data.rollLink);
		private.SetShown(self.MoneyBackground, moneyToast);
		private.SetShown(self.MoneyLabel, moneyToast);
		private.SetShown(self.MoneyBackground, moneyToast);
		private.SetShown(self.MoneyIconBorder, moneyToast);
		private.SetShown(self.MoneyIcon, moneyToast);
		private.SetShown(self.MountToastBackground, data.toast == "mounttoast");
		private.SetShown(self.PetToastBackground, data.toast == "pettoast");

		if data.rollLink then
			if data.rollType == LOOT_ROLL_TYPE_NEED then
				self.RollWonTitle:SetTexture([[Interface\Buttons\UI-GroupLoot-Dice-Up]]);
			elseif data.rollType == LOOT_ROLL_TYPE_GREED then
				self.RollWonTitle:SetTexture([[Interface\Buttons\UI-GroupLoot-Coin-Up]]);
			else
				self.RollWonTitle:Hide();
			end
			self.RollWon:SetText(data.rollLink);
		end

		if recipeToast then
			self.RecipeIcon:SetTexture(data.texture);
            -- These frames are pooled: reset any texcoords left by an earlier atlas icon.
            self.RecipeIcon:SetTexCoord(0, 1, 0, 1);
            local craftIcon = data.texture == picn and PROFESSION_ICON_TCOORDS[data.subType];
			if craftIcon then
				self.RecipeIcon:SetTexCoord(unpack(craftIcon));
			end

			local rankTexture = NewRecipeLearnedAlertFrame_GetStarTextureFromRank(data.quality);
			if rankTexture then
				self.RecipeName:SetFormattedText("%s %s", data.name, rankTexture);
			else
				self.RecipeName:SetText(data.name);
			end
			self.RecipeTitle:SetText(data.label);
		end

		if qualityColor then
			self.ItemName:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b);
            self.LessItemName:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b);
		end

		if LOOT_BORDER_BY_QUALITY[data.quality] then
			self.IconBorder:SetTexCoord(unpack(LOOT_BORDER_BY_QUALITY[data.quality]));
		end

		if config.sound then
			if legendaryToast then
				PlaySoundFile(SOUNDKIT.UI_LEGENDARY_LOOT_TOAST);
			elseif commonToast then
				PlaySoundFile(SOUNDKIT.UI_RAID_LOOT_TOAST_LESSER_ITEM_WON);
			elseif recipeToast then
				PlaySoundFile(SOUNDKIT.UI_GARRISON_FOLLOWER_LEARN_TRAIT);
			else
				PlaySoundFile(SOUNDKIT.UI_EPICLOOT_TOAST);
			end
		end

		if config.animations then
			if legendaryToast then
				self.legendaryGlow.animIn:Play();
				self.legendaryShine.animIn:Play();
			elseif recipeToast then
				self.recipeGlow.animIn:Play();
				self.recipeShine.animIn:Play();
			else
				self.glow.animIn:Play();
				self.shine.animIn:Play();
			end
		end

		self.hyperLink 		= data.link;
		self.tip 			= data.tip;
		self.name 			= data.name;
		self.money			= data.money;
	end
end

function DragonUIItemLootButtonTemplate_OnHide(self)
    stopEffects(self)
    self.data,self.preview,self.stickyPreview = nil,nil,nil
    self.hyperLink,self.tip,self.name,self.money = nil,nil,nil,nil
    if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    if not private.clearing then private.AdjustAnchors() end
end

function DragonUIItemLootButtonTemplate_OnClick(self, button)
	if button == "RightButton" then
		self:Hide();
	else
		if self.hyperLink and HandleModifiedItemClick(self.hyperLink) then
			return;
		end
	end
end

function DragonUIItemLootButtonTemplate_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -14, -6);
	if self.tip then
		GameTooltip:SetText(self.name, 1, 1, 1);
		GameTooltip:AddLine(self.tip, nil, nil, nil, 1);
	elseif self.money then
		GameTooltip:AddLine(YOU_RECEIVED_LABEL);
		SetTooltipMoney(GameTooltip, self.money, nil);
	elseif self.hyperLink then
		GameTooltip:SetHyperlink(self.hyperLink);
    else
        GameTooltip:SetText(self.name or "DragonUI",1,1,1);
	end
	GameTooltip:Show();
end
