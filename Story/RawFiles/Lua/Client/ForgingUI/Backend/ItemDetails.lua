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
        {Keys = {"Strength", "StrengthBoost"}, Label = "Strength", Canonical = "Strength"},
        {Keys = {"Finesse", "FinesseBoost"}, Label = "Finesse", Canonical = "Finesse"},
        {Keys = {"Intelligence", "IntelligenceBoost"}, Label = "Intelligence", Canonical = "Intelligence"},
        {Keys = {"Constitution", "ConstitutionBoost"}, Label = "Constitution", Canonical = "Constitution"},
        {Keys = {"Memory", "MemoryBoost"}, Label = "Memory", Canonical = "Memory"},
        {Keys = {"Wits", "WitsBoost"}, Label = "Wits", Canonical = "Wits"},
        {Keys = {"SingleHanded"}, Label = ResolveAbilityLabel("SingleHanded"), Canonical = "SingleHanded"},
        {Keys = {"TwoHanded"}, Label = ResolveAbilityLabel("TwoHanded"), Canonical = "TwoHanded"},
        {Keys = {"Ranged"}, Label = ResolveAbilityLabel("Ranged"), Canonical = "Ranged"},
        {Keys = {"DualWielding"}, Label = ResolveAbilityLabel("DualWielding"), Canonical = "DualWielding"},
        {Keys = {"WarriorLore"}, Label = ResolveAbilityLabel("WarriorLore"), Canonical = "WarriorLore"},
        {Keys = {"RangerLore"}, Label = ResolveAbilityLabel("RangerLore"), Canonical = "RangerLore"},
        {Keys = {"RogueLore"}, Label = ResolveAbilityLabel("RogueLore"), Canonical = "RogueLore"},
        {Keys = {"FireSpecialist"}, Label = ResolveAbilityLabel("FireSpecialist"), Canonical = "FireSpecialist"},
        {Keys = {"WaterSpecialist"}, Label = ResolveAbilityLabel("WaterSpecialist"), Canonical = "WaterSpecialist"},
        {Keys = {"AirSpecialist"}, Label = ResolveAbilityLabel("AirSpecialist"), Canonical = "AirSpecialist"},
        {Keys = {"EarthSpecialist"}, Label = ResolveAbilityLabel("EarthSpecialist"), Canonical = "EarthSpecialist"},
        {Keys = {"Necromancy"}, Label = ResolveAbilityLabel("Necromancy"), Canonical = "Necromancy"},
        {Keys = {"Summoning"}, Label = ResolveAbilityLabel("Summoning"), Canonical = "Summoning"},
        {Keys = {"Polymorph"}, Label = ResolveAbilityLabel("Polymorph"), Canonical = "Polymorph"},
        {Keys = {"Sourcery"}, Label = ResolveAbilityLabel("Sourcery"), Canonical = "Sourcery"},
        {Keys = {"Leadership"}, Label = ResolveAbilityLabel("Leadership"), Canonical = "Leadership"},
        {Keys = {"Perseverance"}, Label = ResolveAbilityLabel("Perseverance"), Canonical = "Perseverance"},
        {Keys = {"PainReflection"}, Label = ResolveAbilityLabel("PainReflection"), Canonical = "PainReflection"},
        {Keys = {"Telekinesis"}, Label = ResolveAbilityLabel("Telekinesis"), Canonical = "Telekinesis"},
        {Keys = {"Sneaking"}, Label = ResolveAbilityLabel("Sneaking"), Canonical = "Sneaking"},
        {Keys = {"Thievery"}, Label = ResolveAbilityLabel("Thievery"), Canonical = "Thievery"},
        {Keys = {"Loremaster"}, Label = ResolveAbilityLabel("Loremaster"), Canonical = "Loremaster"},
        {Keys = {"Barter"}, Label = ResolveAbilityLabel("Barter"), Canonical = "Barter"},
        {Keys = {"Persuasion"}, Label = ResolveAbilityLabel("Persuasion"), Canonical = "Persuasion"},
        {Keys = {"Luck"}, Label = ResolveAbilityLabel("Luck"), Canonical = "Luck"},
        {Keys = {"CriticalChance"}, Label = "Critical Chance", Percent = true, Canonical = "CriticalChance"},
        -- CriticalDamage is a base weapon stat (often 150%) shown in the tooltip header, not as a blue stat.
        -- It can look doubled when base + dynamic stats are summed, so keep it out of the blue stats section.
        {Keys = {"CriticalDamage"}, Label = "Critical Damage", Percent = true, Canonical = "CriticalDamage", HideInStatsSection = true},
        {Keys = {"AccuracyBoost", "ChanceToHitBoost"}, Label = "Accuracy", Percent = true, Canonical = "Accuracy"},
        {Keys = {"DodgeBoost"}, Label = "Dodge", Percent = true, Canonical = "Dodge"},
        {Keys = {"LifeSteal"}, Label = "Life Steal", Percent = true, Canonical = "LifeSteal"},
        {Keys = {"Movement", "MovementSpeedBoost"}, Label = "Movement", Canonical = "Movement"},
        {Keys = {"Initiative"}, Label = "Initiative", Canonical = "Initiative"},
        {Keys = {"VitalityBoost", "Vitality"}, Label = "Vitality", Canonical = "Vitality"},
        {Keys = {"MagicPointsBoost"}, Label = "Source Points", Canonical = "SourcePoints"},
        {Keys = {"APMaximum"}, Label = "Maximum AP", Canonical = "MaxAP"},
        {Keys = {"APStart"}, Label = "Starting AP", Canonical = "StartAP"},
        {Keys = {"APRecovery"}, Label = "AP Recovery", Canonical = "APRecovery"},
        {Keys = {"ArmorBoost"}, Label = "Physical Armour", Canonical = "ArmorBoost"},
        {Keys = {"MagicArmorBoost"}, Label = "Magic Armour", Canonical = "MagicArmorBoost"},
        -- DamageBoost is hidden base scaling and varies by rarity (e.g. 10/12/15% in Shared Weapon.stats).
        -- Tooltip does not show it as a blue stat, so keep it out of the blue stats section.
        {Keys = {"DamageBoost"}, Label = "Damage", Percent = true, Canonical = "DamageBoost", HideInStatsSection = true},
        {Keys = {"Reflection"}, Label = "Reflection", Percent = true, Canonical = "Reflection"},
    }

    do
        local resistTypes = {"Physical", "Piercing", "Fire", "Air", "Water", "Earth", "Poison", "Shadow"}
        for _, damageType in ipairs(resistTypes) do
            local label = ResolveDamageTypeName(damageType) or tostring(damageType)
            local canonical = "Resist_" .. tostring(damageType)
            table.insert(STAT_FIELDS, {
                Keys = {damageType, damageType .. "Resistance"},
                Label = label .. " Resistance",
                Percent = true,
                Canonical = canonical,
            })
        end
    end

    local function BuildHiddenStatLabelSet()
        local hidden = {}
        for _, field in ipairs(STAT_FIELDS) do
            if field.HideInStatsSection and field.Label then
                hidden[field.Label] = true
            end
        end
        return hidden
    end

    local HIDDEN_STAT_LABELS = BuildHiddenStatLabelSet()

    local function GetStatLines(stats)
        if not stats then
            return {}
        end
        local totals = {}
        local function Accumulate(source)
            if not source then
                return
            end
            for _, field in ipairs(STAT_FIELDS) do
                local keys = field.Keys or (field.Key and {field.Key}) or {}
                for _, keyName in ipairs(keys) do
                    local value = SafeStatsField(source, keyName)
                    if type(value) == "string" then
                        value = tonumber(value)
                    end
                    if type(value) == "number" and value ~= 0 then
                        local key = field.Canonical or keyName
                        totals[key] = (totals[key] or 0) + value
                    end
                end
            end
        end
        Accumulate(stats)
        if stats.DynamicStats then
            for _, dyn in pairs(stats.DynamicStats) do
                Accumulate(dyn)
            end
        end
        local lines = {}
        local added = {}
        for _, field in ipairs(STAT_FIELDS) do
            local key = field.Canonical or field.Key or (field.Keys and field.Keys[1])
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

    local statusNameCache = {}
    local statusTypeNameCache = nil
    local statusTypeNameCacheBuilt = false

    local function TranslateStatusDisplayName(stat)
        if not stat then
            return nil
        end
        if stat.DisplayName and Ext and Ext.L10N then
            local translated = Ext.L10N.GetTranslatedStringFromKey(stat.DisplayName)
            if translated and translated ~= "" then
                return translated
            end
        end
        if stat.DisplayNameRef and stat.DisplayNameRef ~= "" then
            return stat.DisplayNameRef
        end
        return nil
    end

    -- Build cache from game data (dynamic). Prefer Ext.Stats-only so we don't depend on Stats lib.
    local function GetDisplayFromStat(stat)
        if not stat then
            return nil
        end
        if stat.DisplayName and Ext and Ext.L10N then
            local ok, translated = pcall(Ext.L10N.GetTranslatedStringFromKey, stat.DisplayName)
            if ok and translated and translated ~= "" then
                return translated
            end
        end
        if stat.DisplayNameRef and stat.DisplayNameRef ~= "" then
            return stat.DisplayNameRef
        end
        if stat.DisplayName and stat.DisplayName ~= "" then
            local s = tostring(stat.DisplayName):gsub("^|(.-)|$", "%1")
            if s ~= "" then
                return s
            end
        end
        return nil
    end

    local function AddStatusDisplayName(key, display)
        if not key or key == "" or not display or display == "" then
            return
        end
        local cacheKey = tostring(key):upper()
        if statusTypeNameCache[cacheKey] == nil then
            statusTypeNameCache[cacheKey] = display
        end
    end

    local function BuildStatusTypeNameCache()
        if statusTypeNameCacheBuilt then
            return
        end
        statusTypeNameCache = {}

        -- Path 1: Ext.Stats only (no Stats lib). Works in-game when SE is available.
        if Ext and Ext.Stats and Ext.Stats.GetStats and Ext.Stats.Get then
            local ok, ids = pcall(Ext.Stats.GetStats, "StatusData")
            if ok and type(ids) == "table" then
                for _, statId in ipairs(ids) do
                    local pok, stat = pcall(Ext.Stats.Get, statId)
                    if pok and stat then
                        local display = GetDisplayFromStat(stat)
                        AddStatusDisplayName(stat.StatusType, display)
                        AddStatusDisplayName(stat.Name, display)
                        AddStatusDisplayName(stat.StatsId, display)
                        AddStatusDisplayName(statId, display)
                        -- Some StatusData files have multiple entries (e.g. ENRAGED + MUTED in one file).
                        if stat.StatObjects and type(stat.StatObjects) == "table" then
                            for _, sub in ipairs(stat.StatObjects) do
                                if sub then
                                    local subDisplay = GetDisplayFromStat(sub)
                                    AddStatusDisplayName(sub.StatusType, subDisplay)
                                    AddStatusDisplayName(sub.Name, subDisplay)
                                    AddStatusDisplayName(sub.StatsId, subDisplay)
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Path 2: Stats lib (Epic Encounters / StatsEntryAnnotations) if available.
        if (not statusTypeNameCache or next(statusTypeNameCache) == nil) and Stats and Stats.Get then
            local ok, ids = pcall(Ext.Stats.GetStats, "StatusData")
            if ok and type(ids) == "table" and Ext and Ext.Stats then
                for _, statId in ipairs(ids) do
                    local stat = Stats.Get("StatsLib_StatsEntry_StatusData", statId)
                    if stat then
                        local display = TranslateStatusDisplayName(stat)
                        AddStatusDisplayName(stat.StatusType, display)
                        AddStatusDisplayName(stat.Name, display)
                        AddStatusDisplayName(stat.StatsId, display)
                        AddStatusDisplayName(statId, display)
                    end
                end
            end
        end

        if statusTypeNameCache and next(statusTypeNameCache) ~= nil then
            statusTypeNameCacheBuilt = true
        end
    end

    local function ResolveStatusName(statusId)
        if not statusId then
            return ""
        end
        local keyRaw = tostring(statusId)
        local keyUpper = keyRaw:upper()
        local cached = statusNameCache[keyRaw] or statusNameCache[keyUpper]
        if cached then
            return cached
        end
        local name = nil

        if Stats and Stats.GetStatusName then
            local ok, result = pcall(Stats.GetStatusName, {StatusId = keyRaw, StatusType = keyUpper})
            local resultText = ok and result and tostring(result) or ""
            if resultText ~= "" and resultText:upper() ~= keyUpper then
                name = resultText
            end
        end

        if not name and Stats and Stats.Get then
            local stat = Stats.Get("StatsLib_StatsEntry_StatusData", keyRaw)
            name = TranslateStatusDisplayName(stat)
            if not name and stat and stat.StatusType then
                BuildStatusTypeNameCache()
                if statusTypeNameCache then
                    name = statusTypeNameCache[tostring(stat.StatusType):upper()]
                end
            end
        end

        if not name then
            BuildStatusTypeNameCache()
            if statusTypeNameCache then
                name = statusTypeNameCache[keyUpper]
            end
        end

        name = name or keyRaw
        statusNameCache[keyRaw] = name
        statusNameCache[keyUpper] = name
        return name
    end

    local function NormalizeStatusChance(chance)
        local num = tonumber(chance)
        if not num then
            return chance
        end
        if num > 0 and num <= 1 then
            return num * 100
        end
        return num
    end

    local function NormalizeStatusTurns(turns)
        local num = tonumber(turns)
        if not num then
            return turns
        end
        if num > 0 and num >= 6 and math.abs(num % 6) < 0.001 then
            return num / 6
        end
        return num
    end

    local function FormatStatusProperty(statusId, chance, turns)
        if not statusId or statusId == "" then
            return nil
        end
        local statusName = ResolveStatusName(statusId)
        local turnsText = turns ~= nil and (FormatNumber(tonumber(turns)) or tostring(turns)) or nil
        local chanceText = chance ~= nil and (FormatNumber(tonumber(chance)) or tostring(chance)) or nil
        if turnsText and chanceText then
            return string.format("Set %s for %s turn(s). %s%% chance to succeed.", statusName, turnsText, chanceText)
        elseif turnsText then
            return string.format("Set %s for %s turn(s).", statusName, turnsText)
        elseif chanceText then
            return string.format("Set %s. %s%% chance to succeed.", statusName, chanceText)
        end
        return string.format("Set %s.", statusName)
    end

    local function ExtractStatusId(raw)
        if not raw then
            return nil
        end
        local trimmed = tostring(raw):match("^%s*(.-)%s*$")
        if trimmed == "" then
            return nil
        end
        local last = trimmed:match("([^:]+)$")
        return last or trimmed
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
            local statusId = ExtractStatusId(parts[1])
            local chance = tonumber(parts[2])
            local turns = tonumber(parts[3])
            if statusId and chance and turns then
                return FormatStatusProperty(statusId, chance, turns)
            end
        end
        local cleaned = tostring(token):gsub("_", " ")
        cleaned = cleaned:gsub(":", ": ")
        return cleaned
    end

    local function SafePropertyField(prop, field)
        if not prop then
            return nil
        end
        local ok, value = pcall(function()
            return prop[field]
        end)
        if ok then
            return value
        end
        return nil
    end

    local function NormalizePropertyType(prop)
        local typeId = SafePropertyField(prop, "TypeId")
            or SafePropertyField(prop, "Type")
            or SafePropertyField(prop, "TypeID")
            or SafePropertyField(prop, "PropertyType")
        if typeId == nil then
            return nil
        end
        return string.lower(tostring(typeId))
    end

    local function EnumeratePropertyElements(extraProps)
        local props = SafePropertyField(extraProps, "Properties") or extraProps
        local elements = SafePropertyField(props, "Elements")
            or SafePropertyField(extraProps, "Elements")
            or props
        return elements
    end

    local function ForEachPropertyElement(elements, callback)
        if not elements or not callback then
            return false
        end
        local didIterate = false
        local function handle(prop)
            didIterate = true
            callback(prop)
        end
        pcall(function()
            for _, prop in ipairs(elements) do
                handle(prop)
            end
        end)
        if didIterate then
            return true
        end
        local elementType = type(elements)
        if elementType == "table" then
            for _, prop in pairs(elements) do
                handle(prop)
            end
            return didIterate
        end
        if elementType == "userdata" then
            if elements.Iterator then
                local okIter = pcall(function()
                    for prop in elements:Iterator() do
                        handle(prop)
                    end
                end)
                if okIter and didIterate then
                    return true
                end
            end
            local okLen, len = pcall(function()
                return #elements
            end)
            if okLen and type(len) == "number" then
                for i = 1, len do
                    local okVal, prop = pcall(function()
                        return elements[i]
                    end)
                    if okVal then
                        handle(prop)
                    end
                end
                if didIterate then
                    return true
                end
            end
            local okPairs, iter, state, var = pcall(pairs, elements)
            if okPairs then
                for _, prop in iter, state, var do
                    handle(prop)
                end
                if didIterate then
                    return true
                end
            end
        end
        return didIterate
    end

    local function IsStatusProperty(prop, typeId)
        if typeId then
            if typeId == "status" or typeId == "applystatus" or typeId:find("status", 1, true) then
                return true
            end
        end
        return SafePropertyField(prop, "Status") ~= nil
            or SafePropertyField(prop, "StatusId") ~= nil
            or SafePropertyField(prop, "StatusID") ~= nil
    end

    local function IsSurfaceProperty(prop, typeId)
        if typeId then
            if typeId == "surface"
                or typeId == "createsurface"
                or typeId == "targetcreatesurface"
                or typeId:find("surface", 1, true) then
                return true
            end
        end
        return SafePropertyField(prop, "SurfaceType") ~= nil
            or SafePropertyField(prop, "Surface") ~= nil
            or SafePropertyField(prop, "SurfaceName") ~= nil
    end

    local function AppendLine(lines, seen, line)
        if not line or line == "" then
            return
        end
        if seen and seen[line] then
            return
        end
        if seen then
            seen[line] = true
        end
        table.insert(lines, line)
    end

    local function CollectExtraPropertyLinesFromPropertyList(extraProps, lines, seen)
        if not extraProps then
            return
        end
        local elements = EnumeratePropertyElements(extraProps)
        if not elements then
            return
        end
        local didIterate = ForEachPropertyElement(elements, function(prop)
            local typeId = NormalizePropertyType(prop)
            if IsStatusProperty(prop, typeId) then
                local statusId = ExtractStatusId(SafePropertyField(prop, "Status")
                    or SafePropertyField(prop, "StatusId")
                    or SafePropertyField(prop, "StatusID"))
                local chance = SafePropertyField(prop, "Chance")
                    or SafePropertyField(prop, "StatusChance")
                    or SafePropertyField(prop, "Probability")
                local turns = SafePropertyField(prop, "Duration")
                    or SafePropertyField(prop, "Turns")
                    or SafePropertyField(prop, "StatusDuration")
                chance = NormalizeStatusChance(chance)
                turns = NormalizeStatusTurns(turns)
                AppendLine(lines, seen, FormatStatusProperty(statusId, chance, turns))
            elseif IsSurfaceProperty(prop, typeId) then
                local surfaceId = SafePropertyField(prop, "SurfaceType")
                    or SafePropertyField(prop, "Surface")
                    or SafePropertyField(prop, "SurfaceName")
                local chance = SafePropertyField(prop, "Chance")
                    or SafePropertyField(prop, "Probability")
                chance = NormalizeStatusChance(chance)
                local surfaceLabel = surfaceId and tostring(surfaceId) or "surface"
                local line = chance and string.format("Create %s surface. %s%% chance to succeed.", surfaceLabel, FormatNumber(tonumber(chance)) or tostring(chance))
                    or string.format("Create %s surface.", surfaceLabel)
                AppendLine(lines, seen, line)
            end
        end)
        if not didIterate and type(elements) == "table" then
            for _, prop in ipairs(elements) do
                local typeId = NormalizePropertyType(prop)
                if IsStatusProperty(prop, typeId) then
                    local statusId = ExtractStatusId(SafePropertyField(prop, "Status")
                        or SafePropertyField(prop, "StatusId")
                        or SafePropertyField(prop, "StatusID"))
                    local chance = SafePropertyField(prop, "Chance")
                        or SafePropertyField(prop, "StatusChance")
                        or SafePropertyField(prop, "Probability")
                    local turns = SafePropertyField(prop, "Duration")
                        or SafePropertyField(prop, "Turns")
                        or SafePropertyField(prop, "StatusDuration")
                    chance = NormalizeStatusChance(chance)
                    turns = NormalizeStatusTurns(turns)
                    AppendLine(lines, seen, FormatStatusProperty(statusId, chance, turns))
                elseif IsSurfaceProperty(prop, typeId) then
                    local surfaceId = SafePropertyField(prop, "SurfaceType")
                        or SafePropertyField(prop, "Surface")
                        or SafePropertyField(prop, "SurfaceName")
                    local chance = SafePropertyField(prop, "Chance")
                        or SafePropertyField(prop, "Probability")
                    chance = NormalizeStatusChance(chance)
                    local surfaceLabel = surfaceId and tostring(surfaceId) or "surface"
                    local line = chance and string.format("Create %s surface. %s%% chance to succeed.", surfaceLabel, FormatNumber(tonumber(chance)) or tostring(chance))
                        or string.format("Create %s surface.", surfaceLabel)
                    AppendLine(lines, seen, line)
                end
            end
        end
    end

    local function CollectExtraPropertyLinesFromValue(extra, lines, seen)
        if extra == nil then
            return
        end
        if type(extra) == "string" then
            for token in string.gmatch(extra, "([^;]+)") do
                local trimmed = token:match("^%s*(.-)%s*$")
                if trimmed and trimmed ~= "" then
                    AppendLine(lines, seen, FormatExtraProperty(trimmed))
                end
            end
            return
        end
        if type(extra) == "table" then
            for _, entry in pairs(extra) do
                if type(entry) == "string" then
                    AppendLine(lines, seen, FormatExtraProperty(entry))
                end
            end
        end
        if type(extra) == "userdata" then
            local label = SafePropertyField(extra, "Label")
                or SafePropertyField(extra, "LabelText")
                or SafePropertyField(extra, "Text")
                or SafePropertyField(extra, "Value")
            if type(label) == "string" and label ~= "" then
                CollectExtraPropertyLinesFromValue(label, lines, seen)
            end
        end
        CollectExtraPropertyLinesFromPropertyList(extra, lines, seen)
    end

    local function ResolveStatsEntry(statsId)
        if not statsId or statsId == "" then
            return nil
        end
        if Ext and Ext.Stats and Ext.Stats.Get then
            local ok, stat = pcall(Ext.Stats.Get, statsId)
            if ok then
                return stat
            end
        end
        return nil
    end

    local function CollectExtraPropertyLinesFromBoosts(stats, lines, seen)
        if not stats then
            return
        end
        local boosts = SafeStatsField(stats, "Boosts")
        if not boosts then
            return
        end
        local function HandleBoostId(boostId)
            if not boostId or boostId == "" then
                return
            end
            local boostStats = ResolveStatsEntry(boostId)
            if not boostStats then
                return
            end
            CollectExtraPropertyLinesFromValue(SafeStatsField(boostStats, "ExtraProperties"), lines, seen)
            local boostLists = SafeStatsField(boostStats, "PropertyLists")
            if boostLists then
                local boostExtra = SafePropertyField(boostLists, "ExtraProperties")
                CollectExtraPropertyLinesFromPropertyList(boostExtra, lines, seen)
            end
        end
        if type(boosts) == "string" then
            for token in string.gmatch(boosts, "([^;]+)") do
                local trimmed = token:match("^%s*(.-)%s*$")
                if trimmed and trimmed ~= "" then
                    HandleBoostId(trimmed)
                end
            end
        elseif type(boosts) == "table" then
            for _, entry in pairs(boosts) do
                if type(entry) == "string" then
                    HandleBoostId(entry)
                elseif type(entry) == "table" then
                    local id = entry.Name or entry.StatsId or entry.StatsID
                    if id then
                        HandleBoostId(id)
                    end
                end
            end
        end
    end

    local function GetExtraPropertyLines(stats)
        if not stats then
            return {}
        end
        local lines = {}
        local seen = {}
        CollectExtraPropertyLinesFromValue(SafeStatsField(stats, "ExtraProperties"), lines, seen)
        if stats.DynamicStats then
            for _, dyn in pairs(stats.DynamicStats) do
                CollectExtraPropertyLinesFromValue(SafeStatsField(dyn, "ExtraProperties"), lines, seen)
            end
        end
        CollectExtraPropertyLinesFromBoosts(stats, lines, seen)
        local propertyLists = nil
        local listRaw = nil
        if #lines == 0 then
            propertyLists = SafeStatsField(stats, "PropertyLists")
            if propertyLists then
                local extraProps = SafePropertyField(propertyLists, "ExtraProperties")
                CollectExtraPropertyLinesFromPropertyList(extraProps, lines, seen)
                listRaw = extraProps
            end
            if stats.DynamicStats then
                for _, dyn in pairs(stats.DynamicStats) do
                    local dynLists = SafeStatsField(dyn, "PropertyLists")
                    if dynLists then
                        local dynExtra = SafePropertyField(dynLists, "ExtraProperties")
                        CollectExtraPropertyLinesFromPropertyList(dynExtra, lines, seen)
                        if listRaw == nil then
                            listRaw = dynExtra
                        end
                    end
                end
            end
        end
        if ShouldDebug() and Ext and Ext.Print and #lines == 0 then
            local statsId = SafeStatsField(stats, "Name")
                or SafeStatsField(stats, "StatsId")
                or SafeStatsField(stats, "StatsID")
            state._ExtraPropsLogged = state._ExtraPropsLogged or {}
            if statsId and not state._ExtraPropsLogged[statsId] then
                state._ExtraPropsLogged[statsId] = true
                local extraRaw = SafeStatsField(stats, "ExtraProperties")
                Ext.Print(string.format(
                    "[ForgingUI][ItemDetails] ExtraProperties empty stats=%s extraType=%s listType=%s",
                    tostring(statsId),
                    tostring(type(extraRaw)),
                    tostring(type(listRaw))
                ))
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

    local function BuildRawSectionLists(stats)
        return {
            Base = GetBaseValueLines(stats),
            Stats = GetStatLines(stats),
            Extra = GetExtraPropertyLines(stats),
            Skills = GetSkillLines(stats),
        }
    end

    local function CleanSectionLines(sectionId, lines, stats)
        if sectionId == "Stats" then
            local cleaned = {}
            for _, line in ipairs(lines or {}) do
                local keep = true
                for label, _ in pairs(HIDDEN_STAT_LABELS) do
                    if line:sub(-#label) == label then
                        keep = false
                        break
                    end
                end
                if keep then
                    table.insert(cleaned, line)
                end
            end
            return cleaned
        end
        return lines or {}
    end

    local function BuildSectionLists(stats)
        local raw = BuildRawSectionLists(stats)
        local clean = {}
        for sectionId, lines in pairs(raw) do
            clean[sectionId] = CleanSectionLines(sectionId, lines, stats)
        end
        return raw, clean
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
        local rawSections, cleanSections = BuildSectionLists(stats)
        local details = {
            Handle = item.Handle,
            Name = GetItemName(item, stats),
            Rarity = GetItemRarity(item, stats),
            Level = GetItemLevel(item, stats),
            RuneSlots = GetRuneSlots(item, stats),
            SectionLists = {
                Raw = rawSections,
                Clean = cleanSections,
            },
            BaseValues = cleanSections.Base or {},
            Stats = cleanSections.Stats or {},
            ExtraProperties = cleanSections.Extra or {},
            Skills = cleanSections.Skills or {},
        }
        return details
    end

    return {
        GetItemDetails = GetItemDetails,
    }
end

return ItemDetails
