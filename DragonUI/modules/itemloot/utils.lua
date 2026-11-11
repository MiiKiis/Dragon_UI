-- Helpers for ItemLoot; keep localized chat matching private to this module.
local _, addon = ...
local private = addon.ItemLoot
function private.Mixin(object, ...)
    for i = 1, select("#", ...) do
        for key, value in pairs(select(i, ...)) do object[key] = value end
    end
    return object
end
-- WotLK has Show/Hide but no native SetShown on these regions.
function private.SetShown(region,visible)
    if visible then region:Show() else region:Hide() end
end
local cache = {}
local function escape(text)
    return (text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end
function private.Match(message, formatString)
    if type(message) ~= "string" or type(formatString) ~= "string" then return end
    local entry = cache[formatString]
    if not entry then
        local pieces, indexes, pos, count, highest = {"^"}, {}, 1, 0, 0
        while pos <= #formatString do
            local a, b, explicit, kind = formatString:find("%%(%d+)%$([sd])", pos)
            local c, d, plain = formatString:find("%%([sd])", pos)
            if c and (not a or c < a) then a,b,explicit,kind = c,d,nil,plain end
            if not a then pieces[#pieces+1] = escape(formatString:sub(pos)); break end
            pieces[#pieces+1] = escape(formatString:sub(pos,a-1))
            pieces[#pieces+1] = kind == "d" and "(%d+)" or "(.-)"
            count = count + 1
            indexes[count] = tonumber(explicit) or count
            highest = math.max(highest,indexes[count])
            pos = b + 1
        end
        pieces[#pieces+1] = "$"
        entry = {table.concat(pieces), indexes, highest}
        cache[formatString] = entry
    end
    local captures = {message:match(entry[1])}
    if #captures == 0 then return end
    local result = {}
    for index, capture in ipairs(captures) do result[entry[2][index]] = capture end
    return unpack(result,1,entry[3])
end
function private.GetAmountBattlefieldBonus()
    local won, honor, arena
    if not GetNumBattlegroundTypes or not GetBattlegroundInfo then return end
    for i=1, GetNumBattlegroundTypes() do
        local _, _, holiday, random = GetBattlegroundInfo(i)
        if random and GetRandomBGHonorCurrencyBonuses then
            won,honor,arena = GetRandomBGHonorCurrencyBonuses()
        elseif holiday and GetHolidayBGHonorCurrencyBonuses then
            won,honor,arena = GetHolidayBGHonorCurrencyBonuses()
        end
    end
    return won,honor,arena
end
