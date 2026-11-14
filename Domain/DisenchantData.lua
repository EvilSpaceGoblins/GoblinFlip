-- Disenchant data tables for WoW Forever (1.60.1).
-- Pure game mechanics data: material IDs, DE probabilities, reagent tables.
-- No external dependencies. All data derived from public game mechanics.

local _, GF = ...

GF.Domain = GF.Domain or {}
local DisenchantData = {}
GF.Domain.DisenchantData = DisenchantData

-- Material item IDs (vanilla through MoP)
DisenchantData.Materials = {
    -- Classic / Vanilla
    [10940] = "Strange Dust",
    [11083] = "Soul Dust",
    [11137] = "Vision Dust",
    [11176] = "Dream Dust",
    [16204] = "Illusion Dust",
    [16202] = "Greater Eternal Essence",
    [16203] = "Lesser Eternal Essence",
    [11082] = "Greater Astral Essence",
    [10998] = "Lesser Astral Essence",
    [10938] = "Lesser Magic Essence",
    [10939] = "Greater Magic Essence",
    [11174] = "Lesser Nether Essence",
    [11175] = "Greater Nether Essence",
    [14343] = "Small Brilliant Shard",
    [14344] = "Large Brilliant Shard",
    [20725] = "Nexus Crystal",
    -- TBC
    [22445] = "Arcane Dust",
    [22446] = "Greater Planar Essence",
    [22447] = "Lesser Planar Essence",
    [22448] = "Small Prismatic Shard",
    [22449] = "Large Prismatic Shard",
    [22450] = "Void Crystal",
    -- WotLK
    [34054] = "Infinite Dust",
    [34055] = "Greater Cosmic Essence",
    [34056] = "Lesser Cosmic Essence",
    [34052] = "Dream Shard",
    [34053] = "Abyss Crystal",
    -- Cata
    [52718] = "Hypnotic Dust",
    [52719] = "Greater Celestial Essence",
    [52720] = "Lesser Celestial Essence",
    [52721] = "Heavenly Shard",
    [52722] = "Maelstrom Crystal",
    -- MoP
    [74248] = "Spirit Dust",
    [74249] = "Mysterious Essence",
    [74250] = "Ethereal Shard",
    [74251] = "Sha Crystal",
}

-- Inverse lookup: name -> itemID
DisenchantData.MaterialIDs = {}
for id, name in pairs(DisenchantData.Materials) do
    DisenchantData.MaterialIDs[name] = id
end

-- DE probability tables by expansion, quality, and item level range
-- Format: { minILvl, maxILvl, { { materialID, minQty, maxQty, chance }, ... } }
DisenchantData.Tables = {
    -- Classic (Vanilla)
    classic = {
        uncommon = {
            -- iLvl 1-25: Strange Dust (1-2) + Lesser Magic Essence
            { 1, 25, {
                { 10940, 1, 2, 0.75 },  -- Strange Dust
                { 10938, 1, 1, 0.20 },  -- Lesser Magic Essence
                { 10939, 1, 1, 0.05 },  -- Greater Magic Essence
            }},
            -- iLvl 26-30: Strange Dust (2-3) + Lesser/Greater Magic Essence
            { 26, 30, {
                { 10940, 2, 3, 0.70 },
                { 10938, 1, 1, 0.20 },
                { 10939, 1, 1, 0.10 },
            }},
            -- iLvl 31-35: Soul Dust (1-2) + Astral Essence
            { 31, 35, {
                { 11083, 1, 2, 0.75 },
                { 10998, 1, 1, 0.20 },
                { 11082, 1, 1, 0.05 },
            }},
            -- iLvl 36-40: Soul Dust (2-3) + Astral Essence
            { 36, 40, {
                { 11083, 2, 3, 0.70 },
                { 10998, 1, 1, 0.20 },
                { 11082, 1, 1, 0.10 },
            }},
            -- iLvl 41-45: Vision Dust (1-2) + Nether Essence
            { 41, 45, {
                { 11137, 1, 2, 0.75 },
                { 11174, 1, 1, 0.20 },
                { 11175, 1, 1, 0.05 },
            }},
            -- iLvl 46-50: Vision Dust (2-3) + Nether Essence
            { 46, 50, {
                { 11137, 2, 3, 0.70 },
                { 11174, 1, 1, 0.20 },
                { 11175, 1, 1, 0.10 },
            }},
            -- iLvl 51-55: Dream Dust (1-2) + Eternal Essence
            { 51, 55, {
                { 11176, 1, 2, 0.75 },
                { 16203, 1, 1, 0.20 },
                { 16202, 1, 1, 0.05 },
            }},
            -- iLvl 56-60: Dream Dust (2-3) + Eternal Essence
            { 56, 60, {
                { 11176, 2, 3, 0.70 },
                { 16203, 1, 1, 0.20 },
                { 16202, 1, 1, 0.10 },
            }},
            -- iLvl 61-65: Illusion Dust (1-2) + Eternal Essence
            { 61, 65, {
                { 16204, 1, 2, 0.75 },
                { 16203, 1, 1, 0.20 },
                { 16202, 1, 1, 0.05 },
            }},
            -- iLvl 66-70: Illusion Dust (2-3) + Eternal Essence + Brilliant Shard
            { 66, 70, {
                { 16204, 2, 3, 0.60 },
                { 16203, 1, 1, 0.20 },
                { 16202, 1, 1, 0.15 },
                { 14343, 1, 1, 0.05 },
            }},
            -- iLvl 71-80: Illusion Dust (2-3) + Brilliant Shard
            { 71, 80, {
                { 16204, 2, 3, 0.55 },
                { 14343, 1, 1, 0.30 },
                { 14344, 1, 1, 0.10 },
                { 16202, 1, 1, 0.05 },
            }},
        },
        rare = {
            -- iLvl 1-25: Lesser/Greater Magic Essence
            { 1, 25, {
                { 10938, 1, 1, 0.50 },
                { 10939, 1, 1, 0.40 },
                { 10940, 1, 2, 0.10 },
            }},
            -- iLvl 26-30: Lesser/Greater Astral Essence
            { 26, 30, {
                { 10998, 1, 1, 0.50 },
                { 11082, 1, 1, 0.40 },
                { 11083, 1, 2, 0.10 },
            }},
            -- iLvl 31-35: Lesser/Greater Nether Essence
            { 31, 35, {
                { 11174, 1, 1, 0.50 },
                { 11175, 1, 1, 0.40 },
                { 11137, 1, 2, 0.10 },
            }},
            -- iLvl 36-40: Lesser/Greater Eternal Essence
            { 36, 40, {
                { 16203, 1, 1, 0.50 },
                { 16202, 1, 1, 0.40 },
                { 11176, 1, 2, 0.10 },
            }},
            -- iLvl 41-50: Illusion Dust + Brilliant Shard
            { 41, 50, {
                { 16204, 1, 2, 0.40 },
                { 14343, 1, 1, 0.35 },
                { 14344, 1, 1, 0.15 },
                { 16202, 1, 1, 0.10 },
            }},
            -- iLvl 51-60: Illusion Dust + Brilliant Shard
            { 51, 60, {
                { 16204, 2, 3, 0.35 },
                { 14343, 1, 1, 0.30 },
                { 14344, 1, 1, 0.25 },
                { 16202, 1, 1, 0.10 },
            }},
            -- iLvl 61-70: Brilliant Shard + Nexus Crystal chance
            { 61, 70, {
                { 14344, 1, 1, 0.40 },
                { 14343, 1, 2, 0.30 },
                { 20725, 1, 1, 0.20 },
                { 16204, 1, 2, 0.10 },
            }},
            -- iLvl 71-80: Nexus Crystal + Brilliant Shard
            { 71, 80, {
                { 20725, 1, 1, 0.40 },
                { 14344, 1, 1, 0.35 },
                { 14343, 1, 2, 0.20 },
                { 16204, 1, 2, 0.05 },
            }},
        },
        epic = {
            -- iLvl 40-50: Large Brilliant Shard + Nexus Crystal
            { 40, 50, {
                { 14344, 1, 1, 0.60 },
                { 14343, 1, 1, 0.30 },
                { 20725, 1, 1, 0.10 },
            }},
            -- iLvl 51-60: Large Brilliant Shard + Nexus Crystal
            { 51, 60, {
                { 14344, 1, 1, 0.50 },
                { 20725, 1, 1, 0.35 },
                { 14343, 1, 1, 0.15 },
            }},
            -- iLvl 61-70: Nexus Crystal
            { 61, 70, {
                { 20725, 1, 1, 0.70 },
                { 14344, 1, 1, 0.30 },
            }},
            -- iLvl 71-80: Nexus Crystal (multiple)
            { 71, 80, {
                { 20725, 1, 2, 0.70 },
                { 14344, 1, 1, 0.30 },
            }},
        },
    },

    -- Burning Crusade (Outland)
    tbc = {
        uncommon = {
            { 80, 90, {
                { 22445, 1, 2, 0.75 },  -- Arcane Dust
                { 22447, 1, 1, 0.20 },  -- Lesser Planar Essence
                { 22446, 1, 1, 0.05 },  -- Greater Planar Essence
            }},
            { 91, 100, {
                { 22445, 2, 3, 0.70 },
                { 22447, 1, 1, 0.20 },
                { 22446, 1, 1, 0.10 },
            }},
            { 101, 115, {
                { 22445, 2, 3, 0.65 },
                { 22446, 1, 1, 0.25 },
                { 22447, 1, 1, 0.10 },
            }},
            { 116, 120, {
                { 22445, 2, 4, 0.60 },
                { 22446, 1, 1, 0.30 },
                { 22448, 1, 1, 0.10 },  -- Small Prismatic Shard
            }},
        },
        rare = {
            { 80, 100, {
                { 22447, 1, 1, 0.50 },
                { 22446, 1, 1, 0.40 },
                { 22445, 1, 2, 0.10 },
            }},
            { 101, 115, {
                { 22446, 1, 1, 0.50 },
                { 22447, 1, 1, 0.40 },
                { 22448, 1, 1, 0.10 },
            }},
            { 116, 120, {
                { 22448, 1, 1, 0.40 },  -- Small Prismatic Shard
                { 22449, 1, 1, 0.35 },  -- Large Prismatic Shard
                { 22446, 1, 1, 0.25 },
            }},
        },
        epic = {
            { 95, 115, {
                { 22449, 1, 1, 0.60 },  -- Large Prismatic Shard
                { 22448, 1, 1, 0.30 },  -- Small Prismatic Shard
                { 22450, 1, 1, 0.10 },  -- Void Crystal
            }},
            { 116, 120, {
                { 22450, 1, 1, 0.70 },  -- Void Crystal
                { 22449, 1, 1, 0.30 },  -- Large Prismatic Shard
            }},
        },
    },

    -- Wrath of the Lich King
    wotlk = {
        uncommon = {
            { 130, 150, {
                { 34054, 1, 2, 0.75 },  -- Infinite Dust
                { 34056, 1, 1, 0.20 },  -- Lesser Cosmic Essence
                { 34055, 1, 1, 0.05 },  -- Greater Cosmic Essence
            }},
            { 151, 165, {
                { 34054, 2, 3, 0.70 },
                { 34056, 1, 1, 0.20 },
                { 34055, 1, 1, 0.10 },
            }},
            { 166, 180, {
                { 34054, 2, 4, 0.65 },
                { 34055, 1, 1, 0.25 },
                { 34052, 1, 1, 0.10 },  -- Dream Shard
            }},
            { 181, 200, {
                { 34054, 3, 5, 0.60 },
                { 34055, 1, 1, 0.30 },
                { 34052, 1, 1, 0.10 },
            }},
        },
        rare = {
            { 130, 165, {
                { 34056, 1, 1, 0.50 },
                { 34055, 1, 1, 0.40 },
                { 34054, 1, 2, 0.10 },
            }},
            { 166, 180, {
                { 34052, 1, 1, 0.40 },  -- Dream Shard
                { 34055, 1, 1, 0.35 },
                { 34056, 1, 1, 0.25 },
            }},
            { 181, 200, {
                { 34053, 1, 1, 0.40 },  -- Abyss Crystal
                { 34052, 1, 1, 0.35 },  -- Dream Shard
                { 34055, 1, 1, 0.25 },
            }},
        },
        epic = {
            { 166, 180, {
                { 34053, 1, 1, 0.60 },  -- Abyss Crystal
                { 34052, 1, 1, 0.30 },  -- Dream Shard
                { 34055, 1, 1, 0.10 },
            }},
            { 181, 200, {
                { 34053, 1, 2, 0.70 },  -- Abyss Crystal
                { 34052, 1, 1, 0.30 },
            }},
        },
    },

    -- Cataclysm
    cata = {
        uncommon = {
            { 200, 250, {
                { 52718, 1, 2, 0.75 },  -- Hypnotic Dust
                { 52720, 1, 1, 0.20 },  -- Lesser Celestial Essence
                { 52719, 1, 1, 0.05 },  -- Greater Celestial Essence
            }},
            { 251, 300, {
                { 52718, 2, 4, 0.70 },
                { 52720, 1, 1, 0.20 },
                { 52719, 1, 1, 0.10 },
            }},
            { 301, 350, {
                { 52718, 3, 5, 0.65 },
                { 52719, 1, 1, 0.25 },
                { 52721, 1, 1, 0.10 },  -- Heavenly Shard
            }},
        },
        rare = {
            { 200, 275, {
                { 52720, 1, 1, 0.50 },
                { 52719, 1, 1, 0.40 },
                { 52718, 1, 2, 0.10 },
            }},
            { 276, 325, {
                { 52721, 1, 1, 0.40 },  -- Heavenly Shard
                { 52719, 1, 1, 0.35 },
                { 52720, 1, 1, 0.25 },
            }},
            { 326, 350, {
                { 52722, 1, 1, 0.40 },  -- Maelstrom Crystal
                { 52721, 1, 1, 0.35 },  -- Heavenly Shard
                { 52719, 1, 1, 0.25 },
            }},
        },
        epic = {
            { 300, 325, {
                { 52722, 1, 1, 0.60 },  -- Maelstrom Crystal
                { 52721, 1, 1, 0.30 },  -- Heavenly Shard
                { 52719, 1, 1, 0.10 },
            }},
            { 326, 350, {
                { 52722, 1, 2, 0.70 },  -- Maelstrom Crystal
                { 52721, 1, 1, 0.30 },
            }},
        },
    },

    -- Mists of Pandaria
    mop = {
        uncommon = {
            { 350, 400, {
                { 74248, 1, 2, 0.75 },  -- Spirit Dust
                { 74249, 1, 1, 0.20 },  -- Mysterious Essence
                { 74250, 1, 1, 0.05 },  -- Ethereal Shard
            }},
            { 401, 450, {
                { 74248, 2, 4, 0.70 },
                { 74249, 1, 1, 0.20 },
                { 74250, 1, 1, 0.10 },
            }},
            { 451, 500, {
                { 74248, 3, 5, 0.65 },
                { 74250, 1, 1, 0.25 },
                { 74251, 1, 1, 0.10 },  -- Sha Crystal
            }},
        },
        rare = {
            { 350, 425, {
                { 74249, 1, 1, 0.50 },
                { 74248, 1, 2, 0.10 },
                { 74250, 1, 1, 0.40 },
            }},
            { 426, 475, {
                { 74251, 1, 1, 0.40 },  -- Sha Crystal
                { 74250, 1, 1, 0.35 },  -- Ethereal Shard
                { 74249, 1, 1, 0.25 },
            }},
            { 476, 500, {
                { 74251, 1, 2, 0.50 },  -- Sha Crystal
                { 74250, 1, 1, 0.35 },
                { 74249, 1, 1, 0.15 },
            }},
        },
        epic = {
            { 450, 475, {
                { 74251, 1, 1, 0.60 },  -- Sha Crystal
                { 74250, 1, 1, 0.30 },
                { 74249, 1, 1, 0.10 },
            }},
            { 476, 500, {
                { 74251, 1, 2, 0.70 },
                { 74250, 1, 1, 0.30 },
            }},
        },
    },
}

-- Determine expansion from item level (rough heuristic for Forever)
DisenchantData.ExpansionForItemLevel = function(itemLevel)
    if itemLevel <= 80 then return "classic" end
    if itemLevel <= 120 then return "tbc" end
    if itemLevel <= 200 then return "wotlk" end
    if itemLevel <= 350 then return "cata" end
    return "mop"
end

-- Quality name from numeric quality
DisenchantData.QualityName = function(quality)
    if quality == 2 then return "uncommon" end  -- Green
    if quality == 3 then return "rare" end      -- Blue
    if quality == 4 then return "epic" end      -- Purple
    return nil
end

-- Get DE table for expansion/quality/itemLevel
DisenchantData.GetTable = function(expansion, quality, itemLevel)
    local expData = DisenchantData.Tables[expansion]
    if not expData then return nil end
    local qualityName = DisenchantData.QualityName(quality)
    if not qualityName then return nil end
    local qualityData = expData[qualityName]
    if not qualityData then return nil end
    for _, entry in ipairs(qualityData) do
        if itemLevel >= entry[1] and itemLevel <= entry[2] then
            return entry[3]  -- the materials array
        end
    end
    return nil
end

-- Calculate expected value per disenchant (in copper)
-- Returns: avgCopper, materialsList, avgMaterialCount
DisenchantData.CalculateExpectedValue = function(itemId, itemLevel, quality, materialPrices)
    local expansion = DisenchantData.ExpansionForItemLevel(itemLevel)
    local matTable = DisenchantData.GetTable(expansion, quality, itemLevel)
    if not matTable then return nil end

    local totalExpected = 0
    local materials = {}
    local totalQty = 0

    for _, mat in ipairs(matTable) do
        local matId, minQty, maxQty, chance = mat[1], mat[2], mat[3], mat[4]
        local avgQty = (minQty + maxQty) / 2
        local price = materialPrices and materialPrices[matId] or 0
        local expected = avgQty * chance * price
        totalExpected = totalExpected + expected
        totalQty = totalQty + avgQty * chance
        materials[#materials + 1] = {
            itemId = matId,
            name = DisenchantData.Materials[matId] or ("Item #" .. matId),
            minQty = minQty,
            maxQty = maxQty,
            chance = chance,
            avgQty = avgQty,
            price = price,
            expectedValue = expected,
        }
    end

    return math.floor(totalExpected + 0.5), materials, totalQty
end

-- Get estimate for an item (for UI/tooltip)
-- Returns table matching DisenchantStrategy contract
DisenchantData.GetEstimate = function(itemId, itemLevel, quality, materialPrices)
    if not itemId or not itemLevel or not quality then return nil end
    if quality < 2 or quality > 4 then return nil end  -- Only green/blue/purple

    local avgValue, materials, avgQty = DisenchantData.CalculateExpectedValue(itemId, itemLevel, quality, materialPrices)
    if not avgValue then return nil end

    return {
        available = true,
        provider = "GoblinFlip-Internal",
        expectedGrossPerItem = avgValue,
        saleFeeRate = 0.05,  -- 5% AH fee assumption
        asOf = type(time) == "function" and time() or 0,
        stale = true,
        illustrative = true,
        skillVerified = false,
        assumptions = {
            "Based on internal DE probability tables (classic through MoP).",
            "Material prices from live AH or defaults.",
            "5% AH fee deducted from expected gross.",
        },
    }
end

-- Initialize with default material prices (vendor/fallback)
DisenchantData.defaultPrices = {
    -- Classic
    [10940] = 500,   -- Strange Dust
    [11083] = 2000,  -- Soul Dust
    [11137] = 5000,  -- Vision Dust
    [11176] = 10000, -- Dream Dust
    [16204] = 50000, -- Illusion Dust
    [16202] = 20000, -- Greater Eternal Essence
    [16203] = 10000, -- Lesser Eternal Essence
    [11082] = 8000,  -- Greater Astral Essence
    [10998] = 4000,  -- Lesser Astral Essence
    [10938] = 2000,  -- Lesser Magic Essence
    [10939] = 4000,  -- Greater Magic Essence
    [11174] = 6000,  -- Lesser Nether Essence
    [11175] = 12000, -- Greater Nether Essence
    [14343] = 20000, -- Small Brilliant Shard
    [14344] = 100000,-- Large Brilliant Shard
    [20725] = 500000,-- Nexus Crystal
    -- TBC
    [22445] = 15000, -- Arcane Dust
    [22446] = 30000, -- Greater Planar Essence
    [22447] = 15000, -- Lesser Planar Essence
    [22448] = 50000, -- Small Prismatic Shard
    [22449] = 200000,-- Large Prismatic Shard
    [22450] = 500000,-- Void Crystal
    -- WotLK
    [34054] = 20000, -- Infinite Dust
    [34055] = 40000, -- Greater Cosmic Essence
    [34056] = 20000, -- Lesser Cosmic Essence
    [34052] = 100000,-- Dream Shard
    [34053] = 500000,-- Abyss Crystal
    -- Cata
    [52718] = 25000, -- Hypnotic Dust
    [52719] = 50000, -- Greater Celestial Essence
    [52720] = 25000, -- Lesser Celestial Essence
    [52721] = 150000,-- Heavenly Shard
    [52722] = 800000,-- Maelstrom Crystal
    -- MoP
    [74248] = 30000, -- Spirit Dust
    [74249] = 60000, -- Mysterious Essence
    [74250] = 200000,-- Ethereal Shard
    [74251] = 1000000,-- Sha Crystal
}

return DisenchantData
