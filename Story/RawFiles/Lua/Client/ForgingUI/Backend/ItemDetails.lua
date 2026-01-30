-- Client/ForgingUI/Backend/ItemDetails.lua
-- Extracts item details for the forging UI panels.

local ItemDetails = {}

---@param options table
function ItemDetails.Create(options)
    local opts = options or {}
    local getContext = opts.getContext
    local state = {}
    local function GetContext()
        return getContext and getContext() or nil
    end
    local function ShouldDebug()
        local ctx = GetContext()
        local tuning = ctx and ctx.LayoutTuning or nil
        return tuning and tuning.DebugSlotDetails == true
    end
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
    if not helpers and Ext and Ext.Print and ShouldDebug() then
        Ext.Print("[ForgingUI][ItemDetails] Falling back to local helpers (ItemHelpers unavailable).")
    end
    local function SafeStatsField(stats, field)
        if helpers and helpers.SafeStatsField then
            return helpers.SafeStatsField(stats, field)
        end
        if not stats then
            return nil
        end
        local ok, value = pcall(function()
            return stats[field]
        end)
        if ok then
            return value
        end
        return nil
    end
    local function GetItemStats(item)
        if helpers and helpers.GetItemStats then
            return helpers.GetItemStats(item)
        end
        if not item then
            return nil
        end
        local okStats, stats = pcall(function()
            return item.Stats
        end)
        if okStats and stats then
            if type(stats) == "string" and Ext and Ext.Stats and Ext.Stats.Get then
                local ok, statsObj = pcall(Ext.Stats.Get, stats)
                if ok and statsObj then
                    return statsObj
                end
            end
            return stats
        end
        local statsId = item.StatsId or item.StatsID
        if statsId and Ext and Ext.Stats and Ext.Stats.Get then
            local ok, statsObj = pcall(Ext.Stats.Get, statsId)
            if ok then
                return statsObj
            end
        end
        return nil
    end
    local function GetStatsIdKey(stats)
        local statsId = SafeStatsField(stats, "Name")
            or SafeStatsField(stats, "StatsId")
            or SafeStatsField(stats, "StatsID")
        if statsId then
            return string.upper(tostring(statsId))
        end
        return nil
    end
    local function IsShieldStats(stats)
        if not stats then
            return false
        end
        if Stats and Stats.GetType then
            local ok, statsType = pcall(Stats.GetType, stats)
            if ok and statsType then
                local normalized = string.lower(tostring(statsType))
                if normalized == "shield" then
                    return true
                end
            end
        end
        local key = GetStatsIdKey(stats)
        if key then
            if key:find("^WPN_SHIELD") ~= nil
                or key:find("^WPN_SHD") ~= nil
                or key:find("^SHD_") ~= nil
                or key:find("^SHIELD_") ~= nil then
                return true
            end
        end
        return false
    end
    local function GetStatsItemType(stats)
        if not stats then
            return nil
        end
        if Stats and Stats.GetType then
            local ok, statsType = pcall(Stats.GetType, stats)
            if ok and statsType then
                local normalized = string.lower(tostring(statsType))
                if normalized == "weapon"
                    or normalized == "armor"
                    or normalized == "shield"
                    or normalized == "equipment" then
                    return normalized
                end
                if normalized == "skilldata" or normalized == "skillbook" then
                    return "skillbook"
                end
            end
        end
        if IsShieldStats(stats) then
            return "shield"
        end
        local key = GetStatsIdKey(stats)
        if key then
            if key:find("^WPN_") ~= nil then
                return "weapon"
            end
            if key:find("^ARM_") ~= nil or key:find("^ARMOR_") ~= nil then
                return "armor"
            end
            if key:find("^EQP_") ~= nil
                or key:find("^RING_") ~= nil
                or key:find("^AMULET_") ~= nil
                or key:find("^BELT_") ~= nil then
                return "equipment"
            end
        end
        return nil
    end
    local DamageLib = nil
    if Damage and Damage.GetDamageTypeDefinition then
        DamageLib = Damage
    elseif Ext and Ext.Require then
        pcall(Ext.Require, "Utilities/Damage/Shared.lua")
        if Damage and Damage.GetDamageTypeDefinition then
            DamageLib = Damage
        end
    end

    local function FormatNumber(value)
        if value == nil then
            return nil
        end
        if type(value) ~= "number" then
            return tostring(value)
        end
        local rounded = math.floor(value + 0.5)
        if math.abs(value - rounded) < 0.01 then
            return tostring(rounded)
        end
        local text = string.format("%.2f", value)
        text = text:gsub("(%..-)0+$", "%1")
        text = text:gsub("%.$", "")
        return text
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
        if DamageLib and DamageLib.GetDamageTypeDefinition then
            local def = DamageLib.GetDamageTypeDefinition(damageType)
            if def then
                if def.TooltipNameHandle and Ext and Ext.L10N then
                    local name = Ext.L10N.GetTranslatedString(def.TooltipNameHandle)
                    if name and name ~= "" then
                        return name
                    end
                end
                if def.StringID then
                    return tostring(def.StringID)
                end
            end
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

    local function NormalizeDamageTypeKey(damageType)
        if damageType == nil then
            return nil
        end
        if DamageLib and DamageLib.GetDamageTypeDefinition then
            local def = DamageLib.GetDamageTypeDefinition(damageType)
            if def and def.StringID then
                return tostring(def.StringID)
            end
        end
        if type(damageType) == "string" then
            return tostring(damageType)
        end
        if Ext and Ext.Enums and Ext.Enums.DamageType then
            for name, value in pairs(Ext.Enums.DamageType) do
                if value == damageType then
                    return tostring(name)
                end
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
        local okSlots, directSlots = pcall(function()
            return item.RuneSlots
        end)
        if okSlots and directSlots ~= nil then
            return directSlots
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

    local DAMAGE_TYPE_ORDER = {
        "Physical",
        "Piercing",
        "Fire",
        "Air",
        "Water",
        "Earth",
        "Poison",
        "Shadow",
        "Magic",
        "Corrosive",
        "Chaos",
    }

    local function ComputeDamageRange(amount, range)
        if amount == nil then
            return nil, nil
        end
        local min = amount
        local max = amount
        if range and range ~= 0 then
            min = amount - range
            max = amount + range
        end
        if min < 0 then
            min = 0
        end
        return min, max
    end

    local function AddDamageTotals(totals, damageType, min, max, order)
        if min == nil or max == nil then
            return false
        end
        min = tonumber(min) or 0
        max = tonumber(max) or min
        if min == 0 and max == 0 then
            return false
        end
        local key = NormalizeDamageTypeKey(damageType) or "Physical"
        local entry = totals[key]
        if not entry then
            entry = {Min = 0, Max = 0}
            totals[key] = entry
            if order then
                table.insert(order, key)
            end
        end
        entry.Min = entry.Min + min
        entry.Max = entry.Max + max
        return true
    end

    local function ParseDamageToken(token)
        if not token or token == "" then
            return nil
        end
        local trimmed = tostring(token):match("^%s*(.-)%s*$")
        local typePart, rangePart = trimmed:match("^(%a+)%s*[:=]%s*(.+)$")
        if not typePart then
            local parts = {}
            for part in trimmed:gmatch("([^,]+)") do
                table.insert(parts, part:match("^%s*(.-)%s*$"))
            end
            if #parts >= 2 then
                typePart = parts[1]
                rangePart = parts[2]
                if #parts >= 3 then
                    rangePart = parts[2] .. "-" .. parts[3]
                end
            end
        end
        if not typePart or not rangePart then
            return nil
        end
        local minVal = nil
        local maxVal = nil
        local minStr, maxStr = rangePart:match("^(%-?[%d%.]+)%s*[-~]%s*(%-?[%d%.]+)$")
        if minStr then
            minVal = tonumber(minStr)
            maxVal = tonumber(maxStr)
        else
            minVal = tonumber(rangePart)
            maxVal = minVal
        end
        if minVal == nil or maxVal == nil then
            return nil
        end
        return typePart, minVal, maxVal
    end

    local function CollectDamageFromList(list, totals, order)
        if not list then
            return 0
        end
        local count = 0
        if type(list) == "string" then
            for token in tostring(list):gmatch("([^;]+)") do
                local damageType, minVal, maxVal = ParseDamageToken(token)
                if damageType and AddDamageTotals(totals, damageType, minVal, maxVal, order) then
                    count = count + 1
                end
            end
        elseif type(list) == "table" then
            for _, entry in pairs(list) do
                if type(entry) == "table" then
                    local damageType = entry.DamageType or entry.Type or entry.DamageTypeID
                    local minVal = entry.Min or entry.MinDamage or entry.Damage or entry.Amount
                    local maxVal = entry.Max or entry.MaxDamage or entry.Damage or entry.Amount
                    if entry.DamageRange and entry.Damage and (entry.Min == nil and entry.Max == nil) then
                        minVal, maxVal = ComputeDamageRange(entry.Damage, entry.DamageRange)
                    end
                    if AddDamageTotals(totals, damageType, minVal, maxVal, order) then
                        count = count + 1
                    end
                end
            end
        end
        return count
    end

    local function CollectDamageFromStats(stats, totals, order)
        if not stats then
            return 0
        end
        local damage = tonumber(SafeStatsField(stats, "Damage") or SafeStatsField(stats, "DamageFromBase") or 0)
        if not damage or damage == 0 then
            return 0
        end
        local range = tonumber(SafeStatsField(stats, "Damage Range") or SafeStatsField(stats, "DamageRange") or 0)
        local minVal, maxVal = ComputeDamageRange(damage, range)
        local damageType = SafeStatsField(stats, "Damage Type") or SafeStatsField(stats, "DamageType")
        if AddDamageTotals(totals, damageType, minVal, maxVal, order) then
            return 1
        end
        return 0
    end

    local function CollectDamageFromDynamicStats(stats, totals, order)
        if not stats or not stats.DynamicStats then
            return 0
        end
        local count = 0
        for _, dyn in ipairs(stats.DynamicStats) do
            count = count + CollectDamageFromList(SafeStatsField(dyn, "DamageList"), totals, order)
            local damage = tonumber(SafeStatsField(dyn, "Damage") or SafeStatsField(dyn, "DamageFromBase") or 0)
            local range = tonumber(SafeStatsField(dyn, "Damage Range") or SafeStatsField(dyn, "DamageRange") or 0)
            local damageType = SafeStatsField(dyn, "Damage Type") or SafeStatsField(dyn, "DamageType")
            if damage and damage ~= 0 then
                local minVal, maxVal = ComputeDamageRange(damage, range)
                if AddDamageTotals(totals, damageType, minVal, maxVal, order) then
                    count = count + 1
                end
            end
        end
        return count
    end

    local function BuildDamageLines(totals, order)
        local lines = {}
        local used = {}
        local ordered = (order and #order > 0) and order or DAMAGE_TYPE_ORDER
        for _, key in ipairs(ordered) do
            local entry = totals[key]
            if entry and entry.Min and entry.Max then
                local name = ResolveDamageTypeName(key)
                local suffix = name and (" " .. name) or ""
                local minText = FormatNumber(entry.Min)
                local maxText = FormatNumber(entry.Max)
                if minText and maxText and minText ~= maxText then
                    table.insert(lines, string.format("%s ~ %s%s", minText, maxText, suffix))
                elseif minText then
                    table.insert(lines, string.format("%s%s", minText, suffix))
                end
                used[key] = true
            end
        end
        local remaining = {}
        for key, _ in pairs(totals) do
            if not used[key] then
                table.insert(remaining, key)
            end
        end
        table.sort(remaining)
        for _, key in ipairs(remaining) do
            local entry = totals[key]
            if entry and entry.Min and entry.Max then
                local name = ResolveDamageTypeName(key)
                local suffix = name and (" " .. name) or ""
                local minText = FormatNumber(entry.Min)
                local maxText = FormatNumber(entry.Max)
                if minText and maxText and minText ~= maxText then
                    table.insert(lines, string.format("%s ~ %s%s", minText, maxText, suffix))
                elseif minText then
                    table.insert(lines, string.format("%s%s", minText, suffix))
                end
            end
        end
        return lines
    end

    local function GetWeaponDamageLines(stats)
        if IsShieldStats(stats) then
            return {}
        end
        local totals = {}
        local order = {}
        local found = CollectDamageFromDynamicStats(stats, totals, order)
        if found == 0 then
            found = CollectDamageFromList(SafeStatsField(stats, "DamageList"), totals, order)
        end
        if found == 0 then
            CollectDamageFromStats(stats, totals, order)
        end
        return BuildDamageLines(totals, order)
    end

    local function GetBaseValueLines(stats)
        if not stats then
            return {}
        end
        local lines = {}
        local statsType = GetStatsItemType(stats)

        if statsType == "weapon" then
            local damageLines = GetWeaponDamageLines(stats)
            for _, line in ipairs(damageLines) do
                table.insert(lines, line)
            end
        elseif statsType == "shield" then
            local armor = SafeStatsField(stats, "Armor Defense Value") or 0
            local magic = SafeStatsField(stats, "Magic Armor Value") or 0
            local blocking = SafeStatsField(stats, "Blocking")
            if armor > 0 then
                table.insert(lines, string.format("Armour: %s", FormatNumber(armor)))
            end
            if magic > 0 then
                table.insert(lines, string.format("Magic Armour: %s", FormatNumber(magic)))
            end
            if blocking and blocking ~= 0 then
                table.insert(lines, string.format("Block Chance: %s%%", FormatNumber(blocking)))
            end
        elseif statsType == "armor" then
            local armor = SafeStatsField(stats, "Armor Defense Value") or 0
            local magic = SafeStatsField(stats, "Magic Armor Value") or 0
            if armor > 0 then
                table.insert(lines, string.format("Armour: %s", FormatNumber(armor)))
            end
            if magic > 0 then
                table.insert(lines, string.format("Magic Armour: %s", FormatNumber(magic)))
            end
        end

        return lines
    end

    local STAT_FIELDS = {
        {Key = "Strength", Label = "Strength", Canonical = "Strength"},
        {Key = "Finesse", Label = "Finesse", Canonical = "Finesse"},
        {Key = "Intelligence", Label = "Intelligence", Canonical = "Intelligence"},
        {Key = "Constitution", Label = "Constitution", Canonical = "Constitution"},
        {Key = "Memory", Label = "Memory", Canonical = "Memory"},
        {Key = "Wits", Label = "Wits", Canonical = "Wits"},
        {Key = "SingleHanded", Label = ResolveAbilityLabel("SingleHanded"), Canonical = "SingleHanded"},
        {Key = "TwoHanded", Label = ResolveAbilityLabel("TwoHanded"), Canonical = "TwoHanded"},
        {Key = "Ranged", Label = ResolveAbilityLabel("Ranged"), Canonical = "Ranged"},
        {Key = "DualWielding", Label = ResolveAbilityLabel("DualWielding"), Canonical = "DualWielding"},
        {Key = "WarriorLore", Label = ResolveAbilityLabel("WarriorLore"), Canonical = "WarriorLore"},
        {Key = "RangerLore", Label = ResolveAbilityLabel("RangerLore"), Canonical = "RangerLore"},
        {Key = "RogueLore", Label = ResolveAbilityLabel("RogueLore"), Canonical = "RogueLore"},
        {Key = "FireSpecialist", Label = ResolveAbilityLabel("FireSpecialist"), Canonical = "FireSpecialist"},
        {Key = "WaterSpecialist", Label = ResolveAbilityLabel("WaterSpecialist"), Canonical = "WaterSpecialist"},
        {Key = "AirSpecialist", Label = ResolveAbilityLabel("AirSpecialist"), Canonical = "AirSpecialist"},
        {Key = "EarthSpecialist", Label = ResolveAbilityLabel("EarthSpecialist"), Canonical = "EarthSpecialist"},
        {Key = "Necromancy", Label = ResolveAbilityLabel("Necromancy"), Canonical = "Necromancy"},
        {Key = "Summoning", Label = ResolveAbilityLabel("Summoning"), Canonical = "Summoning"},
        {Key = "Polymorph", Label = ResolveAbilityLabel("Polymorph"), Canonical = "Polymorph"},
        {Key = "Sourcery", Label = ResolveAbilityLabel("Sourcery"), Canonical = "Sourcery"},
        {Key = "Leadership", Label = ResolveAbilityLabel("Leadership"), Canonical = "Leadership"},
        {Key = "Perseverance", Label = ResolveAbilityLabel("Perseverance"), Canonical = "Perseverance"},
        {Key = "PainReflection", Label = ResolveAbilityLabel("PainReflection"), Canonical = "PainReflection"},
        {Key = "Telekinesis", Label = ResolveAbilityLabel("Telekinesis"), Canonical = "Telekinesis"},
        {Key = "Sneaking", Label = ResolveAbilityLabel("Sneaking"), Canonical = "Sneaking"},
        {Key = "Thievery", Label = ResolveAbilityLabel("Thievery"), Canonical = "Thievery"},
        {Key = "Loremaster", Label = ResolveAbilityLabel("Loremaster"), Canonical = "Loremaster"},
        {Key = "Barter", Label = ResolveAbilityLabel("Barter"), Canonical = "Barter"},
        {Key = "Persuasion", Label = ResolveAbilityLabel("Persuasion"), Canonical = "Persuasion"},
        {Key = "Luck", Label = ResolveAbilityLabel("Luck"), Canonical = "Luck"},
        {Key = "CriticalChance", Label = "Critical Chance", Percent = true, Canonical = "CriticalChance"},
        {Key = "CriticalDamage", Label = "Critical Damage", Percent = true, Canonical = "CriticalDamage"},
        {Key = "AccuracyBoost", Label = "Accuracy", Percent = true, Canonical = "Accuracy"},
        {Key = "ChanceToHitBoost", Label = "Accuracy", Percent = true, Canonical = "Accuracy"},
        {Key = "DodgeBoost", Label = "Dodge", Percent = true, Canonical = "Dodge"},
        {Key = "LifeSteal", Label = "Life Steal", Percent = true, Canonical = "LifeSteal"},
        {Key = "Movement", Label = "Movement", Canonical = "Movement"},
        {Key = "Initiative", Label = "Initiative", Canonical = "Initiative"},
        {Key = "VitalityBoost", Label = "Vitality", Canonical = "Vitality"},
        {Key = "MagicPointsBoost", Label = "Source Points", Canonical = "SourcePoints"},
        {Key = "APMaximum", Label = "Maximum AP", Canonical = "MaxAP"},
        {Key = "APStart", Label = "Starting AP", Canonical = "StartAP"},
        {Key = "APRecovery", Label = "AP Recovery", Canonical = "APRecovery"},
        {Key = "ArmorBoost", Label = "Physical Armour", Canonical = "ArmorBoost"},
        {Key = "MagicArmorBoost", Label = "Magic Armour", Canonical = "MagicArmorBoost"},
        {Key = "DamageBoost", Label = "Damage", Percent = true, Canonical = "DamageBoost"},
        {Key = "Reflection", Label = "Reflection", Percent = true, Canonical = "Reflection"},
    }

    do
        local resistTypes = {"Physical", "Piercing", "Fire", "Air", "Water", "Earth", "Poison", "Shadow"}
        for _, damageType in ipairs(resistTypes) do
            local label = ResolveDamageTypeName(damageType) or tostring(damageType)
            local canonical = "Resist_" .. tostring(damageType)
            table.insert(STAT_FIELDS, {
                Key = damageType,
                Label = label .. " Resistance",
                Percent = true,
                Canonical = canonical,
            })
            table.insert(STAT_FIELDS, {
                Key = damageType .. "Resistance",
                Label = label .. " Resistance",
                Percent = true,
                Canonical = canonical,
            })
        end
    end

    local function GetStatLines(stats)
        if not stats or not stats.DynamicStats then
            return {}
        end
        local totals = {}
        for _, dyn in pairs(stats.DynamicStats) do
            for _, field in ipairs(STAT_FIELDS) do
                local value = SafeStatsField(dyn, field.Key)
                if type(value) == "string" then
                    value = tonumber(value)
                end
                if type(value) == "number" and value ~= 0 then
                    local key = field.Canonical or field.Key
                    totals[key] = (totals[key] or 0) + value
                end
            end
        end
        local lines = {}
        local added = {}
        for _, field in ipairs(STAT_FIELDS) do
            local key = field.Canonical or field.Key
            if not added[key] then
                local value = totals[key]
                if value and value ~= 0 then
                    local sign = value > 0 and "+" or ""
                    local suffix = field.Percent and "%" or ""
                    local valueText = FormatNumber(value)
                    if valueText then
                        table.insert(lines, string.format("%s%s%s %s", sign, valueText, suffix, field.Label))
                    end
                    added[key] = true
                end
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
            table.insert(parts, part:match("^%s*(.-)%s*$"))
        end
        if #parts >= 3 then
            local statusId = parts[1]
            local chance = tonumber(parts[2])
            local turns = tonumber(parts[3])
            if statusId and chance and turns then
                local statusName = ResolveStatusName(statusId)
                local chanceText = FormatNumber(chance) or tostring(chance)
                local turnsText = FormatNumber(turns) or tostring(turns)
                return string.format("Set %s for %s turn(s). %s%% chance to succeed.", statusName, turnsText, chanceText)
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

    local function CollectSkillsFromString(skills, seen, lines)
        if not skills or skills == "" then
            return
        end
        for token in string.gmatch(tostring(skills), "([^;]+)") do
            local trimmed = token:match("^%s*(.-)%s*$")
            if trimmed and trimmed ~= "" and not seen[trimmed] then
                seen[trimmed] = true
                local name = ResolveSkillName(trimmed)
                if name and name ~= "" then
                    table.insert(lines, name)
                end
            end
        end
    end

    local function GetSkillLines(stats)
        if not stats then
            return {}
        end
        local lines = {}
        local seen = {}
        CollectSkillsFromString(SafeStatsField(stats, "Skills"), seen, lines)
        if stats.DynamicStats then
            for _, dyn in pairs(stats.DynamicStats) do
                CollectSkillsFromString(SafeStatsField(dyn, "Skills"), seen, lines)
            end
        end
        return lines
    end

    local function GetItemDetails(item)
        if not item then
            return nil
        end
        local stats = GetItemStats(item)
        if not stats and ShouldDebug() then
            local handle = item.Handle or item.ItemHandle
            state._MissingStatsLogged = state._MissingStatsLogged or {}
            if handle and not state._MissingStatsLogged[handle] then
                state._MissingStatsLogged[handle] = true
                if Ext and Ext.Print then
                    local templateId = item.RootTemplate and item.RootTemplate.Id or nil
                    Ext.Print(string.format(
                        "[ForgingUI][ItemDetails] Missing stats for handle=%s statsId=%s template=%s",
                        tostring(handle),
                        tostring(item.StatsId or item.StatsID),
                        tostring(templateId)
                    ))
                end
            end
        end
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
