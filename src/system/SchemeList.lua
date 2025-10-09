-- Maybe an incentive to use a natural fertiliser. Like sea weed fert, its a real  thing.
-- You could add a big bad that just says sea weed feet but works the same. But include it as a environmental policy.
-- Another one would be to add a grass type, but would be a lot of work. But it could work like herbal lay does.

SchemeIds = {
    DELAYED_MOWING_WILDLIFE = 1, -- SFI, or just only cut twice for a payout
    BALES_OVER_FORAGING = 2,     -- He also got paid for hay making. Basically, he chose to make hay and not silage in some fields. Reasons are less plastic use from wrapping, and the seeds from the wildflowers and grass get spread when baling and loading, and moving the bales.
    NATURAL_GRAZING = 3,         -- Promotes natural grazing practices and biodiversity
    NATURAL_FERTILISER = 4,      -- Encourages the use of natural fertilizers to improve soil health
    CROP_PROMOTION = 5,          -- promotes growing specific crops. possibly split this by tier, and give equipment or cash bonuses
}


Schemes = {

    [SchemeIds.DELAYED_MOWING_WILDLIFE] = {
        id = SchemeIds.DELAYED_MOWING_WILDLIFE,
        name = "rt_scheme_delayed_mowing",
        description = "rt_scheme_desc_delayed_mowing",
        report_description = "rt_scheme_report_desc_delayed_mowing",
        duplicationKey = "DELAYED_HARVEST",
        tiers = {
            [PolicySystem.TIER.A] = {
                bonusPerHa = 12500,
            },
            [PolicySystem.TIER.B] = {
                bonusPerHa = 12300,
            },
            [PolicySystem.TIER.C] = {
                bonusPerHa = 12200,
            },
            [PolicySystem.TIER.D] = {
                bonusPerHa = 12000,
            },
        },
        probability = 1,
        initialise = function(schemeInfo, scheme)
            -- Init of an available scheme, prior to selection by a farm
        end,
        selected = function(schemeInfo, scheme, tier)
            -- Any action when applying the scheme to a farm, e.g. initial payout or equipment
        end,
        evaluate = function(schemeInfo, scheme, tier)
            local currentMonth = RedTape.periodToMonth(g_currentMission.environment.currentPeriod)
            if currentMonth ~= 7 then return end -- Only evaluate in July
            local cumulativeMonth = RedTape.getCumulativeMonth()

            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMLANDS]
            local farmId = scheme.farmId
            local invalidMonths = { cumulativeMonth - 1, cumulativeMonth - 2, cumulativeMonth - 3 }

            local report = {}
            for _, farmland in pairs(g_farmlandManager.farmlands) do
                if farmland.farmId == farmId then
                    local farmlandData = gatherer:getFarmlandData(farmland.id)

                    local juneFruit = farmlandData.fruitHistory[cumulativeMonth - 1]
                    local mayFruit = farmlandData.fruitHistory[cumulativeMonth - 2]
                    local aprilFruit = farmlandData.fruitHistory[cumulativeMonth - 3]

                    local retainedGrass = juneFruit ~= nil and juneFruit.name == "GRASS" and
                        mayFruit ~= nil and mayFruit.name == "GRASS" and
                        aprilFruit ~= nil and aprilFruit.name == "GRASS"

                    local didHarvest = RedTape.tableHasValue(invalidMonths, farmlandData.lastHarvestMonth)
                    if retainedGrass and not didHarvest then
                        local bonusPerHa = schemeInfo.tiers[tier].bonusPerHa
                        local payout = farmlandData.areaHa * bonusPerHa * EconomyManager.getPriceMultiplier()
                        table.insert(report, {
                            cell1 = string.format(g_i18n:getText("rt_report_name_farmland"), farmland.id),
                            cell2 = g_i18n:formatMoney(payout, 0, true, true)
                        })
                        g_client:getServerConnection():sendEvent(SchemePayoutEvent.new(scheme, farmId, payout))
                    else
                        table.insert(report, {
                            cell1 = string.format(g_i18n:getText("rt_report_name_farmland"), farmland.id),
                            cell2 = g_i18n:formatMoney(0, 0, true, true),
                        })
                    end
                end
            end

            return report
        end
    },

    [SchemeIds.CROP_PROMOTION] = {
        id = SchemeIds.CROP_PROMOTION,
        name = "rt_scheme_crop_promotion",
        report_description = "rt_scheme_report_desc_crop_promotion",
        duplicationKey = "CROP_PROMOTION",
        offerMonths = { 1, 2 },
        tiers = {
            [PolicySystem.TIER.A] = {
                bonusPerHa = 2200,
            },
            [PolicySystem.TIER.B] = {
                bonusPerHa = 1800,
            },
            [PolicySystem.TIER.C] = {
                bonusPerHa = 1500,
            },
            [PolicySystem.TIER.D] = {
                bonusPerHa = 1200,
            },
        },
        probability = 1,
        vehicleGroupOmissions = { "TRACTORSS", "TRACTORSM", "TRACTORSL", "TRAILERS", "TRUCKS", "TRAILERSSEMI" },
        descriptionFunction = function(schemeInfo, scheme)
            local fruitType = tonumber(scheme.props['fruitType'])
            local title = g_fruitTypeManager.fruitTypes[fruitType].fillType.title
            return string.format(g_i18n:getText("rt_scheme_desc_crop_promotion"), title)
        end,
        initialise = function(schemeInfo, scheme)
            -- Init of an available scheme, prior to selection by a farm
            scheme:setProp('vehicleMissionType', 'harvestMission')
            local fruitTypes = {
                [FruitType.SUGARBEET] = "SUGARBEET",
                [FruitType.POTATO] = "POTATO",
                [FruitType.PARSNIP] = "VEGETABLES",
                [FruitType.GREENBEAN] = "GREENBEAN",
                [FruitType.PEA] = "PEA",
                [FruitType.SPINACH] = "SPINACH",
                [FruitType.CARROT] = "VEGETABLES",
            }
            local chosenIndex = math.random(1, RedTape.tableCount(fruitTypes))
            local i = 1
            for fruitType, variant in pairs(fruitTypes) do
                if i == chosenIndex then
                    scheme:setProp('fruitType', fruitType)
                    scheme:setProp('variant', variant)
                    break
                end
                i = i + 1
            end
            scheme:setProp('size', SchemeSystem.getAvailableEquipmentSize(scheme.props['variant']))
            local sizedVehicles = g_missionManager.missionVehicles[scheme.props['vehicleMissionType']]
                [scheme.props['size']]
            local variantIndices = {}
            for groupIndex, group in pairs(sizedVehicles) do
                if group.variant == scheme.props['variant'] then
                    table.insert(variantIndices, groupIndex)
                end
            end
            local chosenGroupIndex = math.random(1, #variantIndices)
            scheme:setProp('vehicleGroup', variantIndices[chosenGroupIndex])
        end,
        selected = function(schemeInfo, scheme, tier)
            -- Any action when applying the scheme to a farm, e.g. initial payout or equipment
            scheme:spawnVehicles()
            scheme:setProp('evaluationYear', g_currentMission.environment.currentYear + 1)
            scheme:setProp('evaluationMonth', 12)
        end,
        evaluate = function(schemeInfo, scheme, tier)
            local evaluationYear = tonumber(scheme.props['evaluationYear'])
            local evaluationMonth = tonumber(scheme.props['evaluationMonth'])
            local currentYear = g_currentMission.environment.currentYear
            local currentMonth = RedTape.periodToMonth(g_currentMission.environment.currentPeriod)
            local cumulativeMonth = RedTape.getCumulativeMonth()
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMLANDS]
            local farmId = scheme.farmId

            if currentYear ~= evaluationYear or currentMonth ~= evaluationMonth then
                return
            end

            local fruitType = tonumber(scheme.props['fruitType'])

            local report = {}
            for _, farmland in pairs(g_farmlandManager.farmlands) do
                if farmland.farmId == farmId and farmland.field ~= nil then
                    local farmlandData = gatherer:getFarmlandData(farmland.id)
                    local wasFruitHarvestable = gatherer:wasFruitHarvestable(farmland.id, cumulativeMonth - 12,
                        cumulativeMonth, fruitType)
                    if wasFruitHarvestable then
                        local bonusPerHa = schemeInfo.tiers[tier].bonusPerHa
                        local payout = farmlandData.areaHa * bonusPerHa * EconomyManager.getPriceMultiplier()
                        table.insert(report, {
                            cell1 = string.format(g_i18n:getText("rt_report_name_farmland"), farmland.id),
                            cell2 = g_i18n:formatMoney(payout, 0, true, true)
                        })
                        g_client:getServerConnection():sendEvent(SchemePayoutEvent.new(scheme, farmId, payout))
                    else
                        table.insert(report, {
                            cell1 = string.format(g_i18n:getText("rt_report_name_farmland"), farmland.id),
                            cell2 = g_i18n:formatMoney(0, 0, true, true),
                        })
                    end
                end
            end

            scheme:endScheme()
            return report
        end
    }

}
