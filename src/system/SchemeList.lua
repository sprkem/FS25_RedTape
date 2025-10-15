-- Maybe an incentive to use a natural fertiliser. Like sea weed fert, its a real  thing.

SchemeIds = {
    DELAYED_MOWING_WILDLIFE = 1, -- SFI, or just only cut twice for a payout
    REDUCE_BALE_WRAPPING = 2,    -- He also got paid for hay making. Basically, he chose to make hay and not silage in some fields. Reasons are less plastic use from wrapping, and the seeds from the wildflowers and grass get spread when baling and loading, and moving the bales.
    NATURAL_GRAZING = 3,         -- Promotes natural grazing
    NATURAL_FERTILISER = 4,      -- Encourages the use of natural fertilizers to improve soil health
    CROP_PROMOTION = 5,          -- promotes growing specific crops. possibly split this by tier, and give equipment or cash bonuses
    TRACTOR_DEMO = 6,            -- Demo a tractor for some time
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
        selectionProbability = 1,
        availabilityProbability = 0.8,
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

                    local grassName = g_fruitTypeManager:getFruitTypeByIndex(FruitType.GRASS).name
                    local retainedGrass = juneFruit ~= nil and juneFruit.name == grassName and
                        mayFruit ~= nil and mayFruit.name == grassName and
                        aprilFruit ~= nil and aprilFruit.name == grassName

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

    [SchemeIds.REDUCE_BALE_WRAPPING] = {
        id = SchemeIds.REDUCE_BALE_WRAPPING,
        name = "rt_scheme_reduce_bale_wrapping",
        description = "rt_scheme_desc_reduce_bale_wrapping",
        report_description = "rt_scheme_report_desc_reduce_bale_wrapping",
        duplicationKey = "REDUCE_BALE_WRAPPING",
        tiers = {
            [PolicySystem.TIER.A] = {
                deductionPerBaleRate = 0.068,
                maxPayoutPerHa = 2000,
            },
            [PolicySystem.TIER.B] = {
                deductionPerBaleRate = 0.068,
                maxPayoutPerHa = 1750,
            },
            [PolicySystem.TIER.C] = {
                deductionPerBaleRate = 0.068,
                maxPayoutPerHa = 1500,
            },
            [PolicySystem.TIER.D] = {
                deductionPerBaleRate = 0.068,
                maxPayoutPerHa = 1250,
            },
        },
        selectionProbability = 1,
        availabilityProbability = 0.8,
        initialise = function(schemeInfo, scheme)
            -- Init of an available scheme, prior to selection by a farm
        end,
        selected = function(schemeInfo, scheme, tier)
            -- Any action when applying the scheme to a farm, e.g. initial payout or equipment
        end,
        evaluate = function(schemeInfo, scheme, tier)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMLANDS]
            local farmId = scheme.farmId
            local cumulativeMonth = RedTape.getCumulativeMonth()

            local report = {}
            for _, farmland in pairs(g_farmlandManager.farmlands) do
                if farmland.farmId == farmId then
                    local farmlandData = gatherer:getFarmlandData(farmland.id)
                    local grassName = g_fruitTypeManager:getFruitTypeByIndex(FruitType.GRASS).name
                    local lastMonthFruit = farmlandData.fruitHistory[cumulativeMonth - 1]
                    local tierInfo = schemeInfo.tiers[tier]

                    local payout = 0

                    -- The goal of this calculation is an entirely baled field at 150cm bales reduces the payout to zero.
                    -- If the harvest and bale are split over months, we will see separate rewards/penalties
                    if farmlandData.monthlyWrappedBales > 0 then
                        local deductionPerBale = tierInfo.deductionPerBaleRate * tierInfo.maxPayoutPerHa
                        payout = payout - farmlandData.monthlyWrappedBales * deductionPerBale
                        table.insert(report, {
                            cell1 = string.format(g_i18n:getText("rt_report_name_farmland"), farmland.id),
                            cell2 = g_i18n:getText("rt_report_name_bale_penalty"),
                            cell3 = g_i18n:formatMoney(payout, 0, true, true)
                        })
                    end

                    if farmlandData.lastHarvestMonth == cumulativeMonth - 1 and lastMonthFruit.name == grassName then
                        local reward = farmlandData.areaHa * tierInfo.maxPayoutPerHa
                        payout = payout + reward

                        table.insert(report, {
                            cell1 = string.format(g_i18n:getText("rt_report_name_farmland"), farmland.id),
                            cell2 = g_i18n:getText("rt_report_name_harvest_reward"),
                            cell3 = g_i18n:formatMoney(payout, 0, true, true)
                        })
                    end

                    if payout ~= 0 then
                        g_client:getServerConnection():sendEvent(SchemePayoutEvent.new(scheme, farmId,
                            payout * EconomyManager.getPriceMultiplier()))
                    end
                end
            end



            return report
        end
    },

    [SchemeIds.NATURAL_GRAZING] = {
        id = SchemeIds.NATURAL_GRAZING,
        name = "rt_scheme_natural_grazing",
        description = "rt_scheme_desc_natural_grazing",
        report_description = "rt_scheme_report_desc_natural_grazing",
        duplicationKey = "NATURAL_GRAZING",
        tiers = {
            [PolicySystem.TIER.A] = {
                bonusPerAnimal = 500,
            },
            [PolicySystem.TIER.B] = {
                bonusPerAnimal = 400,
            },
            [PolicySystem.TIER.C] = {
                bonusPerAnimal = 300,
            },
            [PolicySystem.TIER.D] = {
                bonusPerAnimal = 250,
            },
        },
        selectionProbability = 1,
        availabilityProbability = 0.8,
        initialise = function(schemeInfo, scheme)
        end,
        selected = function(schemeInfo, scheme, tier)
        end,
        evaluate = function(schemeInfo, scheme, tier)
            local daysPerPeriod = g_currentMission.environment.daysPerPeriod

            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]

            local report = {}
            local farmData = gatherer:getFarmData(scheme.farmId)
            local tierInfo = schemeInfo.tiers[tier]
            local eligibleAnimalCount = farmData.monthlyAnimalGrazingHours / 24 / daysPerPeriod
            local payout = eligibleAnimalCount * tierInfo.bonusPerAnimal * EconomyManager.getPriceMultiplier()

            table.insert(report, {
                cell1 = g_i18n:getText("rt_report_name_animal_count"),
                cell2 = tostring(eligibleAnimalCount)
            })
            table.insert(report, {
                cell1 = g_i18n:getText("rt_report_name_total_payout"),
                cell2 = g_i18n:formatMoney(payout, 0, true, true)
            })
            g_client:getServerConnection():sendEvent(SchemePayoutEvent.new(scheme, scheme.farmId, payout))

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
        selectionProbability = 1,
        availabilityProbability = 1,
        -- vehicleGroupOmissions = { "TRACTORSS", "TRACTORSM", "TRACTORSL", "TRAILERS", "TRUCKS", "TRAILERSSEMI" },
        descriptionFunction = function(schemeInfo, scheme)
            local fruitType = tonumber(scheme.props['fruitType'])
            local title = g_fruitTypeManager.fruitTypes[fruitType].fillType.title
            return string.format(g_i18n:getText("rt_scheme_desc_crop_promotion"), title)
        end,
        initialise = function(schemeInfo, scheme)
            -- Init of an available scheme, prior to selection by a farm

            local fruitTypes = {
                [FruitType.SUGARBEET] = "BEETHARVESTERS",
                [FruitType.POTATO] = "POTATOHARVESTING",
                [FruitType.PARSNIP] = "VEGETABLEHARVESTERS",
                [FruitType.GREENBEAN] = "GREENBEANHARVESTERS",
                [FruitType.PEA] = "PEAHARVESTERS",
                [FruitType.SPINACH] = "SPINACHHARVESTERS",
                [FruitType.CARROT] = "VEGETABLEHARVESTERS",
            }
            local chosenIndex = math.random(1, RedTape.tableCount(fruitTypes))
            local chosenCategory = nil
            local i = 1
            for fruitType, category in pairs(fruitTypes) do
                if i == chosenIndex then
                    scheme:setProp('fruitType', fruitType)
                    chosenCategory = category
                    break
                end
                i = i + 1
            end

            local options = {}
            for _, item in pairs(g_storeManager:getItems()) do
                for i = 1, #item.categoryNames do
                    if chosenCategory == item.categoryNames[i] then
                        table.insert(options, item)
                    end
                end
            end
            local harvester = options[math.random(1, #options)]
            scheme:setProp('vehicleToSpawn1', harvester.xmlFilename)
            StoreItemUtil.loadSpecsFromXML(harvester)

            local skipCategories = { "WEIGHTS" }
            local spawnIndex = 2
            if harvester.specs ~= nil and harvester.specs.combinations ~= nil then
                local items = g_shopController:getItemsFromCombinations(harvester.specs.combinations)
                for _, item in pairs(items) do
                    local storeItem = item.storeItem
                    if not RedTape.tableHasValue(skipCategories, storeItem.categoryName) then
                        scheme:setProp('vehicleToSpawn' .. spawnIndex, storeItem.xmlFilename)
                        spawnIndex = spawnIndex + 1
                    end
                end
            end
        end,
        selected = function(schemeInfo, scheme, tier)
            -- Any action when applying the scheme to a farm, e.g. initial payout or equipment
            scheme:spawnVehicles()
            scheme:setProp('evaluationYear', g_currentMission.environment.currentYear)
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

            g_client:getServerConnection():sendEvent(SchemeEndedEvent.new(scheme.id, farmId))
            return report
        end
    },

    [SchemeIds.TRACTOR_DEMO] = {
        id = SchemeIds.TRACTOR_DEMO,
        name = "rt_scheme_tractor_demo",
        report_description = "rt_scheme_report_desc_tractor_demo",
        duplicationKey = "TRACTOR_DEMO",
        tiers = {
            [PolicySystem.TIER.A] = {
                categories = { "TRACTORSS", "TRACTORSM", "TRACTORSM", "TRACTORSL", "TRACTORSL" },
                durationMonths = { 2, 2, 3 },
            },
            [PolicySystem.TIER.B] = {
                categories = { "TRACTORSS", "TRACTORSM", "TRACTORSM", "TRACTORSL" },
                durationMonths = { 1, 2, 2 },
            },
            [PolicySystem.TIER.C] = {
                categories = { "TRACTORSS", "TRACTORSS", "TRACTORSM" },
                durationMonths = { 1, 1, 2 },
            },
            [PolicySystem.TIER.D] = {
                categories = { "TRACTORSS" },
                durationMonths = { 1 },
            },
        },
        selectionProbability = 1,
        availabilityProbability = 1,
        descriptionFunction = function(schemeInfo, scheme)
            local storeItem = g_storeManager:getItemByXMLFilename(scheme.props["vehicleToSpawn1"])
            StoreItemUtil.loadSpecsFromXML(storeItem)

            local brand = g_brandManager.indexToBrand[storeItem.brandIndex].title
            local vehicleName = storeItem.name
            local suffix = ""

            if (tonumber(scheme.props['durationMonths']) or 1) > 1 then
                suffix = "s"
            end

            return string.format(g_i18n:getText("rt_scheme_desc_tractor_demo"),
                brand,
                vehicleName,
                scheme.props['durationMonths'],
                suffix)
        end,
        initialise = function(schemeInfo, scheme)
            local tierInfo = schemeInfo.tiers[scheme.tier]
            local chosenCategory = tierInfo.categories[math.random(1, #tierInfo.categories)]

            local options = {}
            for _, item in pairs(g_storeManager:getItems()) do
                for i = 1, #item.categoryNames do
                    if chosenCategory == item.categoryNames[i] then
                        table.insert(options, item)
                    end
                end
            end
            local chosenItem = options[math.random(1, #options)]
            scheme:setProp('vehicleToSpawn1', chosenItem.xmlFilename)

            local chosenDuration = tierInfo.durationMonths[math.random(1, #tierInfo.durationMonths)]
            scheme:setProp('durationMonths', chosenDuration)
        end,
        selected = function(schemeInfo, scheme, tier)
            -- Any action when applying the scheme to a farm, e.g. initial payout or equipment
            local currentMonth = RedTape.periodToMonth(g_currentMission.environment.currentPeriod)
            local expiryMonth = currentMonth + tonumber(scheme.props['durationMonths'])
            local expiryYear = g_currentMission.environment.currentYear
            if expiryMonth > 12 then
                expiryMonth = expiryMonth - 12
                expiryYear = expiryYear + 1
            end
            scheme:setProp('evaluationYear', expiryYear)
            scheme:setProp('evaluationMonth', expiryMonth)
            scheme:spawnVehicles()
        end,
        evaluate = function(schemeInfo, scheme, tier)
            local evaluationYear = tonumber(scheme.props['evaluationYear'])
            local evaluationMonth = tonumber(scheme.props['evaluationMonth'])
            local currentYear = g_currentMission.environment.currentYear
            local currentMonth = RedTape.periodToMonth(g_currentMission.environment.currentPeriod)

            if currentYear ~= evaluationYear or currentMonth ~= evaluationMonth then
                g_client:getServerConnection():sendEvent(SchemeEndedEvent.new(scheme.id, scheme.farmId))
            end
            return {}
        end
    }

}
