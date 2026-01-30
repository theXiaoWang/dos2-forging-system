-- Client/ForgingUI/Backend/ItemDetails.lua
-- Extracts item details for the forging UI panels.

local ItemDetails = {}

---@param options table
function ItemDetails.Create(options)
    local opts = options or {}
    local getContext = opts.getContext
    local state = {}
    local ItemHelpers = Ext.Require("Client/ForgingUI/Backend/PreviewInventory/ItemHelpers.lua")
    local helpers = nil
    if ItemHelpers and ItemHelpers.Create then
        local ok, result = pcall(ItemHelpers.Create, state)
        if ok then
            helpers = result
        elseif Ext and Ext.Print then
            Ext.Print(string.format("[ForgingUI] ItemDetails: ItemHelpers.Create failed: %s", tostring(result)))
        end
    elseif Ext and Ext.Print then
        Ext.Print("[ForgingUI] ItemDetails: ItemHelpers module missing or invalid.")
    end
    if not helpers then
        return {
            GetItemDetails = function()
                return nil
            end,
        }
    end
    local SafeStatsField = helpers.SafeStatsField
    local GetItemStats = helpers.GetItemStats
    local GetStatsItemType = helpers.GetStatsItemType

    local function GetContext()
        return getContext and getContext() or nil
    end

    local function ResolveAbilityLabel(key)
        local charLib = (Game and Game.Character) or Character
        local names = charLib and charLib.ABILITY_ENGLISH_NAMES or nil
        if names and names[key] then
            return names[key]
        end
        return key
    end

    local function ResolveDamageTypeName(damageType)
        if damageType == nil then
            return nil
        end
        if type(damageType) == "string" then
            return tostring(damageType)
        end
        if Ext and Ext.Enums and Ext.Enums.DamageType then
            local enum = Ext.Enums.DamageType
            for name, value in pairs(enum) do
                if value == damageType then
                    return tostring(name)
                end
            end
        end
        if Game and Game.Damage and Game.Damage.GetDamageTypeDefinition then
            local def = Game.Damage.GetDamageTypeDefinition(damageType)
            if def and def.TooltipNameHandle and Ext and Ext.L10N then
                return Ext.L10N.GetTranslatedString(def.TooltipNameHandle)
            end
        end
        return tostring(damageType)
    end

    local function GetItemName(item, stats)
        if not item then
            return ""
        end
        if Item and Item.GetDisplayName then
            local ok, name = pcall(Item.GetDisplayName, item)
            if ok and name and name ~= "" then
                return name
            end
        end
        local displayName = item.DisplayName
        if displayName and displayName ~= "" then
            return displayName
        end
        local statsId = item.StatsId or (stats and SafeStatsField(stats, "Name")) or ""
        return tostring(statsId or "")
    end

    local function GetItemRarity(item, stats)
        if Item and Item.GetRarityName then
            local ok, name = pcall(Item.GetRarityName, item)
            if ok and name then
                return name
            end
        end
        local rarity = nil
        if item then
            local ok, value = pcall(function()
                return item.Rarity
            end)
            if ok then
                rarity = value
            end
        end
        if rarity == nil and stats then
            rarity = SafeStatsField(stats, "Rarity")
        end
        return rarity and tostring(rarity) or ""
    end

    local function GetItemLevel(item, stats)
        if not item then
            return nil
        end
        if Item and Item.GetLevel then
            local ok, level = pcall(Item.GetLevel, item)
            if ok and level then
                return level
            end
        end
        if stats then
            local level = SafeStatsField(stats, "Level")
            if level ~= nil then
                return level
            end
        end
        return nil
    end

    local function GetRuneSlots(item, stats)
        if not item then
            return nil
        end
        if Item and Item.GetRuneSlots then
            local ok, slots = pcall(Item.GetRuneSlots, item)
            if ok and slots then
                return slots
            end
        end
        if stats and stats.DynamicStats then
            local total = 0
            for _, v in pairs(stats.DynamicStats) do
                local slots = v.RuneSlots or 0
                if type(slots) == "number" then
                    total = total + slots
                end
            end
            return total
        end
        local slots = SafeStatsField(stats, "RuneSlots")
        if slots ~= nil then
            return slots
        end
        return nil
    end

    local function GetBaseValueLines(stats)
        if not stats then
            return {}
        end
        local lines = {}
        local statsType = nil
        if Stats and Stats.GetType then
            local ok, statsTypeValue = pcall(Stats.GetType, stats)
            if ok and statsTypeValue then
                statsType = string.lower(tostring(statsTypeValue))
            end
        end
        if not statsType then
            statsType = GetStatsItemType(stats)
        end

        if statsType == "weapon" then
            local damage = SafeStatsField(stats, "Damage") or 0
            local damageRange = SafeStatsField(stats, "Damage Range")
                or SafeStatsField(stats, "DamageRange")
                or 0
            if damage <= 0 then
                damage = SafeStatsField(stats, "DamageFromBase") or 0
            end
            if damage > 0 then
                local min = damage
                local max = damage
                if damageRange and damageRange ~= 0 then
                    min = math.floor(damage - damageRange)
                    max = math.floor(damage + damageRange)
                    if min < 0 then
                        min = 0
                    end
                end
                local damageType = SafeStatsField(stats, "Damage Type") or SafeStatsField(stats, "DamageType")
                local typeName = ResolveDamageTypeName(damageType)
                local suffix = typeName and (" " .. typeName) or ""
                if min ~= max then
                    table.insert(lines, string.format("%s - %s%s", tostring(min), tostring(max), suffix))
                else
                    table.insert(lines, string.format("%s%s", tostring(min), suffix))
                end
            end
        elseif statsType == "shield" then
            local armor = SafeStatsField(stats, "Armor Defense Value") or 0
            local magic = SafeStatsField(stats, "Magic Armor Value") or 0
            local blocking = SafeStatsField(stats, "Blocking")
            if armor > 0 then
                table.insert(lines, string.format("Armour: %s", tostring(armor)))
            end
            if magic > 0 then
                table.insert(lines, string.format("Magic Armour: %s", tostring(magic)))
            end
            if blocking and blocking ~= 0 then
                table.insert(lines, string.format("Block Chance: %s%%", tostring(blocking)))
            end
        elseif statsType == "armor" or statsType == "equipment" then
            local armor = SafeStatsField(stats, "Armor Defense Value") or 0
            local magic = SafeStatsField(stats, "Magic Armor Value") or 0
            if armor > 0 then
                table.insert(lines, string.format("Armour: %s", tostring(armor)))
            end
            if magic > 0 then
                table.insert(lines, string.format("Magic Armour: %s", tostring(magic)))
            end
        end

        return lines
    end

    local STAT_FIELDS = {
        {Key = "Strength", Label = "Strength"},
        {Key = "Finesse", Label = "Finesse"},
        {Key = "Intelligence", Label = "Intelligence"},
        {Key = "Constitution", Label = "Constitution"},
        {Key = "Memory", Label = "Memory"},
        {Key = "Wits", Label = "Wits"},
        {Key = "SingleHanded", Label = ResolveAbilityLabel("SingleHanded")},
        {Key = "TwoHanded", Label = ResolveAbilityLabel("TwoHanded")},
        {Key = "Ranged", Label = ResolveAbilityLabel("Ranged")},
        {Key = "DualWielding", Label = ResolveAbilityLabel("DualWielding")},
        {Key = "WarriorLore", Label = ResolveAbilityLabel("WarriorLore")},
        {Key = "RangerLore", Label = ResolveAbilityLabel("RangerLore")},
        {Key = "RogueLore", Label = ResolveAbilityLabel("RogueLore")},
        {Key = "FireSpecialist", Label = ResolveAbilityLabel("FireSpecialist")},
        {Key = "WaterSpecialist", Label = ResolveAbilityLabel("WaterSpecialist")},
        {Key = "AirSpecialist", Label = ResolveAbilityLabel("AirSpecialist")},
        {Key = "EarthSpecialist", Label = ResolveAbilityLabel("EarthSpecialist")},
        {Key = "Necromancy", Label = ResolveAbilityLabel("Necromancy")},
        {Key = "Summoning", Label = ResolveAbilityLabel("Summoning")},
        {Key = "Polymorph", Label = ResolveAbilityLabel("Polymorph")},
        {Key = "Sourcery", Label = ResolveAbilityLabel("Sourcery")},
        {Key = "Leadership", Label = ResolveAbilityLabel("Leadership")},
        {Key = "Perseverance", Label = ResolveAbilityLabel("Perseverance")},
        {Key = "PainReflection", Label = ResolveAbilityLabel("PainReflection")},
        {Key = "Telekinesis", Label = ResolveAbilityLabel("Telekinesis")},
        {Key = "Sneaking", Label = ResolveAbilityLabel("Sneaking")},
        {Key = "Thievery", Label = ResolveAbilityLabel("Thievery")},
        {Key = "Loremaster", Label = ResolveAbilityLabel("Loremaster")},
        {Key = "Barter", Label = ResolveAbilityLabel("Barter")},
        {Key = "Persuasion", Label = ResolveAbilityLabel("Persuasion")},
        {Key = "Luck", Label = ResolveAbilityLabel("Luck")},
        {Key = "CriticalChance", Label = "Critical Chance", Percent = true},
        {Key = "CriticalDamage", Label = "Critical Damage", Percent = true},
        {Key = "AccuracyBoost", Label = "Accuracy", Percent = true},
        {Key = "DodgeBoost", Label = "Dodge", Percent = true},
        {Key = "LifeSteal", Label = "Life Steal", Percent = true},
    }

    local function GetStatLines(stats)
        if not stats or not stats.DynamicStats then
            return {}
        end
        local totals = {}
        for _, dyn in pairs(stats.DynamicStats) do
            for _, field in ipairs(STAT_FIELDS) do
                local value = dyn[field.Key]
                if type(value) == "number" and value ~= 0 then
                    totals[field.Key] = (totals[field.Key] or 0) + value
                end
            end
        end
        local lines = {}
        for _, field in ipairs(STAT_FIELDS) do
            local value = totals[field.Key]
            if value and value ~= 0 then
                local sign = value > 0 and "+" or ""
                local suffix = field.Percent and "%" or ""
                table.insert(lines, string.format("%s%s%s %s", sign, tostring(value), suffix, field.Label))
            end
        end
        return lines
    end

    local function ResolveStatusName(statusId)
        if not statusId then
            return ""
        end
        if Stats and Stats.Get then
            local stat = Stats.Get("StatsLib_StatsEntry_StatusData", statusId)
            if stat and stat.DisplayName and Ext and Ext.L10N then
                return Ext.L10N.GetTranslatedStringFromKey(stat.DisplayName)
            end
        end
        return tostring(statusId)
    end

    local function FormatExtraProperty(token)
        if not token or token == "" then
            return nil
        end
        local parts = {}
        for part in string.gmatch(token, "([^,]+)") do
            table.insert(parts, part)
        end
        if #parts >= 3 then
            local statusId = parts[1]
            local chance = tonumber(parts[2])
            local turns = tonumber(parts[3])
            if statusId and chance and turns then
                local statusName = ResolveStatusName(statusId)
                return string.format("%d%% chance to set %s for %d turn(s).", chance, statusName, turns)
            end
        end
        local cleaned = tostring(token):gsub("_", " ")
        cleaned = cleaned:gsub(":", ": ")
        return cleaned
    end

    local function GetExtraPropertyLines(stats)
        if not stats then
            return {}
        end
        local extra = SafeStatsField(stats, "ExtraProperties")
        if not extra or extra == "" then
            return {}
        end
        local tokens = {}
        for token in string.gmatch(tostring(extra), "([^;]+)") do
            local trimmed = token:match("^%s*(.-)%s*$")
            if trimmed and trimmed ~= "" then
                table.insert(tokens, trimmed)
            end
        end
        local lines = {}
        for _, token in ipairs(tokens) do
            local formatted = FormatExtraProperty(token)
            if formatted and formatted ~= "" then
                table.insert(lines, formatted)
            end
        end
        return lines
    end

    local function ResolveSkillName(skillId)
        if not skillId or skillId == "" then
            return nil
        end
        local stat = nil
        if Stats and Stats.Get then
            stat = Stats.Get("SkillData", skillId)
        elseif Ext and Ext.Stats and Ext.Stats.Get then
            local ok, value = pcall(Ext.Stats.Get, skillId)
            if ok then
                stat = value
            end
        end
        if stat then
            if stat.DisplayName and Ext and Ext.L10N then
                return Ext.L10N.GetTranslatedStringFromKey(stat.DisplayName)
            end
            if stat.DisplayNameRef and Ext and Ext.L10N then
                return Ext.L10N.GetTranslatedStringFromKey(stat.DisplayNameRef)
            end
        end
        return tostring(skillId)
    end

    local function GetSkillLines(stats)
        if not stats then
            return {}
        end
        local skills = SafeStatsField(stats, "Skills")
        if not skills or skills == "" then
            return {}
        end
        local ids = {}
        for token in string.gmatch(tostring(skills), "([^;]+)") do
            local trimmed = token:match("^%s*(.-)%s*$")
            if trimmed and trimmed ~= "" then
                table.insert(ids, trimmed)
            end
        end
        local lines = {}
        for _, skillId in ipairs(ids) do
            local name = ResolveSkillName(skillId)
            if name and name ~= "" then
                table.insert(lines, name)
            end
        end
        return lines
    end

    local function GetItemDetails(item)
        if not item then
            return nil
        end
        local stats = GetItemStats(item)
        local details = {
            Handle = item.Handle,
            Name = GetItemName(item, stats),
            Rarity = GetItemRarity(item, stats),
            Level = GetItemLevel(item, stats),
            RuneSlots = GetRuneSlots(item, stats),
            BaseValues = GetBaseValueLines(stats),
            Stats = GetStatLines(stats),
            ExtraProperties = GetExtraPropertyLines(stats),
            Skills = GetSkillLines(stats),
        }
        return details
    end

    return {
        GetItemDetails = GetItemDetails,
    }
end

return ItemDetails
