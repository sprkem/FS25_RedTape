PolicyIds = {
    CROP_ROTATION = 1,
    SPRAY_VIOLATION = 2,
    EMPTY_STRAW = 3,
    FULL_SLURRY = 4,
    EMPTY_FOOD = 5,
    ANIMAL_SPACE = 6,
    ANIMAL_PRODUCTIVITY = 7,
    MANURE_SPREADING = 8,
    RESTRICTED_SLURRY = 9
}

Policies = {

    [PolicyIds.CROP_ROTATION] = {
        id = PolicyIds.CROP_ROTATION,
        name = "rt_policy_croprotation",
        description = "rt_policy_description_croprotation",
        report_description = "rt_policy_report_description_croprotation",
        probability = 0.8,
        periodicReward = 100,
        periodicPenalty = -200,
        evaluationInterval = 12,
        minEvaluationCount = 2,
        activate = function(policyInfo, policy, farmId)
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMLANDS]
            local fruitsToSkip = { FruitType.GRASS, FruitType.MEADOW, FruitType.OILSEEDRADISH }
            local cumulativeMonth = RedTape.getCumulativeMonth()

            local totalHa = 0
            local nonCompliantHa = 0

            for _, farmland in pairs(g_farmlandManager.farmlands) do
                if farmland.farmId == farmId and farmland.field ~= nil then
                    local farmLandData = gatherer:getFarmlandData(farmland.id)

                    if farmLandData.fallowMonths > 10 then
                        print("Skipping farmland " ..
                            farmland.id .. " due to fallow months: " .. farmLandData.fallowMonths)
                        continue
                    end

                    local mostRecentFruit = farmLandData.fruitHistory[cumulativeMonth]
                    local mostRecentFruitMonth = cumulativeMonth
                    if mostRecentFruit == nil then
                        mostRecentFruit, mostRecentFruitMonth = gatherer:getPreviousFruit(farmland.id,
                            cumulativeMonth - 1,
                            cumulativeMonth - 12, nil)
                    end

                    if RedTape.tableHasValue(fruitsToSkip, mostRecentFruit) then
                        print("Skipping farmland " .. farmland.id .. " with fruit " .. mostRecentFruit)
                        continue
                    end

                    -- Accounting for a new game where we have no history
                    local hasAnyPreviousFruit = gatherer:hasRecordedFruit(farmland.id, cumulativeMonth - 12,
                        cumulativeMonth - 1)
                    if not hasAnyPreviousFruit then
                        print("Skipping farmland " .. farmland.id .. " due to no previous fruit recorded")
                        continue
                    end

                    -- Try to find a different fruit in the 12 months prior to the most recent fruit. Don't match the mostRecentFruit
                    local previousFruit, _ = gatherer:getPreviousFruit(farmland.id, mostRecentFruitMonth,
                        mostRecentFruitMonth - 12,
                        mostRecentFruit)

                    totalHa = totalHa + farmLandData.areaHa
                    if previousFruit == nil then
                        nonCompliantHa = nonCompliantHa + farmLandData.areaHa
                    end
                end
            end

            local reward = 0
            if totalHa == 0 then
                print("Farm " .. farmId .. ": No area to check.")
                reward = 0
            elseif nonCompliantHa == 0 then
                print("Farm " .. farmId .. ": All farmlands compliant with Crop Rotation policy.")
                reward = policyInfo.periodicReward
            else
                local nonCompliantProportion = nonCompliantHa / totalHa
                print("Farm " .. farmId .. ": Non-compliant area: " .. nonCompliantHa .. " ha, Total area: " ..
                    totalHa .. " ha, Compliance rate: " .. nonCompliantProportion)
                reward = policyInfo.periodicPenalty * nonCompliantProportion
            end

            local report = {}
            table.insert(report,
                { cell1 = g_i18n:getText("rt_report_name_total_area_ha"), cell2 = g_i18n:formatArea(totalHa, 2) })
            table.insert(report,
                {
                    cell1 = g_i18n:getText("rt_report_name_non_compliant_area_ha"),
                    cell2 = g_i18n:formatArea(nonCompliantHa, 2)
                })

            if reward ~= 0 then
                g_client:getServerConnection():sendEvent(PolicyPointsEvent.new(farmId, reward, policy:getName()))
            end
            return report
        end,
    },

    [PolicyIds.SPRAY_VIOLATION] = {
        id = PolicyIds.SPRAY_VIOLATION,
        name = "rt_policy_sprayviolation",
        description = "rt_policy_description_sprayviolation",
        report_description = "rt_policy_report_description_sprayviolation",
        probability = 0.5,
        periodicReward = 5,
        periodicPenaltyPerViolation = -1,
        evaluationInterval = 1,
        minEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingSprayViolations = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local pendingSprayViolations = farmData.pendingSprayViolations or 0

            local reward = 0
            if pendingSprayViolations > 0 then
                reward = policyInfo.periodicPenaltyPerViolation * pendingSprayViolations
            else
                reward = policyInfo.periodicReward
            end

            local report = {}
            table.insert(report,
                { cell1 = g_i18n:getText("rt_report_name_spray_violations"), cell2 = pendingSprayViolations })
            farmData.pendingSprayViolations = 0

            if reward ~= 0 then
                g_client:getServerConnection():sendEvent(PolicyPointsEvent.new(farmId, reward, policy:getName()))
            end

            return report
        end,
    },

    [PolicyIds.EMPTY_STRAW] = {
        id = PolicyIds.EMPTY_STRAW,
        name = "rt_policy_empty_straw",
        description = "rt_policy_description_empty_straw",
        report_description = "rt_policy_report_description_empty_straw",
        probability = 0.6,
        periodicReward = 5,
        periodicPenaltyPerViolation = -2,
        evaluationInterval = 1,
        minEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingEmptyStrawCount = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local pendingEmptyStrawCount = farmData.pendingEmptyStrawCount or 0
            local reward = 0
            if pendingEmptyStrawCount > 0 then
                reward = policyInfo.periodicPenaltyPerViolation * pendingEmptyStrawCount
            else
                reward = policyInfo.periodicReward
            end
            local report = {}
            table.insert(report, { cell1 = g_i18n:getText("rt_report_name_empty_straw"), cell2 = pendingEmptyStrawCount })

            farmData.pendingEmptyStrawCount = 0

            if reward ~= 0 then
                g_client:getServerConnection():sendEvent(PolicyPointsEvent.new(farmId, reward, policy:getName()))
            end

            return report
        end,
    },

    [PolicyIds.FULL_SLURRY] = {
        id = PolicyIds.FULL_SLURRY,
        name = "rt_policy_full_slurry",
        description = "rt_policy_description_full_slurry",
        report_description = "rt_policy_report_description_full_slurry",
        probability = 0.5,
        periodicReward = 5,
        periodicPenaltyPerViolation = -3,
        evaluationInterval = 1,
        minEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingFullSlurryCount = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local pendingFullSlurryCount = farmData.pendingFullSlurryCount or 0
            local reward = 0
            if pendingFullSlurryCount > 0 then
                reward = policyInfo.periodicPenaltyPerViolation * pendingFullSlurryCount
            else
                reward = policyInfo.periodicReward
            end

            local report = {}
            table.insert(report, { cell1 = g_i18n:getText("rt_report_name_full_slurry"), cell2 = pendingFullSlurryCount })

            farmData.pendingFullSlurryCount = 0

            if reward ~= 0 then
                g_client:getServerConnection():sendEvent(PolicyPointsEvent.new(farmId, reward, policy:getName()))
            end

            return report
        end
    },

    [PolicyIds.EMPTY_FOOD] = {
        id = PolicyIds.EMPTY_FOOD,
        name = "rt_policy_empty_food",
        description = "rt_policy_description_empty_food",
        report_description = "rt_policy_report_description_empty_food",
        probability = 0.7,
        periodicReward = 5,
        periodicPenaltyPerViolation = -3,
        deductionPerViolationOnComplete = 5,
        maxCompleteReward = 500,
        evaluationInterval = 1,
        minEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingEmptyFoodCount = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local pendingEmptyFoodCount = farmData.pendingEmptyFoodCount or 0
            local reward = 0
            if pendingEmptyFoodCount > 0 then
                reward = policyInfo.periodicPenaltyPerViolation * pendingEmptyFoodCount
            else
                reward = policyInfo.periodicReward
            end

            local report = {}
            table.insert(report, { cell1 = g_i18n:getText("rt_report_name_empty_food"), cell2 = pendingEmptyFoodCount })

            farmData.pendingEmptyFoodCount = 0

            if reward ~= 0 then
                g_client:getServerConnection():sendEvent(PolicyPointsEvent.new(farmId, reward, policy:getName()))
            end

            return report
        end,
    },

    [PolicyIds.ANIMAL_SPACE] = {
        id = PolicyIds.ANIMAL_SPACE,
        name = "rt_policy_animal_space",
        description = "rt_policy_description_animal_space",
        report_description = "rt_policy_report_description_animal_space",
        probability = 0.6,
        periodicReward = 10,
        periodicPenaltyPerViolation = -1,
        evaluationInterval = 1,
        minEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingAnimalSpaceViolations = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local pendingViolations = farmData.pendingAnimalSpaceViolations or 0
            local reward = 0
            if pendingViolations > 0 then
                reward = policyInfo.periodicPenaltyPerViolation * pendingViolations
            else
                reward = policyInfo.periodicReward
            end

            local report = {}
            table.insert(report,
                { cell1 = g_i18n:getText("rt_report_name_animal_space_violations"), cell2 = pendingViolations })

            farmData.pendingAnimalSpaceViolations = 0

            if reward ~= 0 then
                g_client:getServerConnection():sendEvent(PolicyPointsEvent.new(farmId, reward, policy:getName()))
            end

            return report
        end,
    },

    [PolicyIds.ANIMAL_PRODUCTIVITY] = {
        id = PolicyIds.ANIMAL_PRODUCTIVITY,
        name = "rt_policy_animal_productivity",
        description = "rt_policy_description_animal_productivity",
        report_description = "rt_policy_report_description_animal_productivity",
        probability = 0.3,
        periodicReward = 5,
        periodicPenaltyPerViolation = -1,
        evaluationInterval = 1,
        minEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingLowProductivityHusbandry = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local pendingViolations = farmData.pendingLowProductivityHusbandry or 0
            local reward = 0
            if pendingViolations > 0 then
                reward = policyInfo.periodicPenaltyPerViolation * pendingViolations
            else
                reward = policyInfo.periodicReward
            end

            local report = {}
            table.insert(report,
                { cell1 = g_i18n:getText("rt_report_name_low_productivity_hours"), cell2 = pendingViolations })

            farmData.pendingLowProductivityHusbandry = 0

            if reward ~= 0 then
                g_client:getServerConnection():sendEvent(PolicyPointsEvent.new(farmId, reward, policy:getName()))
            end

            return report
        end,
    },

    [PolicyIds.MANURE_SPREADING] = {
        id = PolicyIds.MANURE_SPREADING,
        name = "rt_policy_manure_spreading",
        description = "rt_policy_description_manure_spreading",
        report_description = "rt_policy_report_description_manure_spreading",
        probability = 0.4,
        periodicReward = 50,
        periodicPenalty = -100,
        evaluationInterval = 6,
        minEvaluationCount = 2,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingManureSpread = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)

            if farmData.rollingAverageManureLevel == 0 then
                farmData.pendingManureSpread = 0
                return 0
            end

            local expectedSpread = farmData.rollingAverageManureLevel * 0.5

            local reward = 0
            if farmData.pendingManureSpread < expectedSpread then
                reward = policyInfo.periodicPenalty
            else
                reward = policyInfo.periodicReward
            end

            local report = {}
            table.insert(report,
                {
                    cell1 = g_i18n:getText("rt_report_name_manure_spread"),
                    cell2 = g_i18n:formatVolume(
                        farmData.pendingManureSpread, 0)
                })
            table.insert(report,
                {
                    cell1 = g_i18n:getText("rt_report_name_manure_spread_expected"),
                    cell2 = g_i18n:formatVolume(
                        expectedSpread, 0)
                })
            table.insert(report,
                {
                    cell1 = g_i18n:getText("rt_report_name_manure_spread_rolling_average"),
                    cell2 = g_i18n:formatVolume(farmData.rollingAverageManureLevel, 0)
                })

            farmData.pendingManureSpread = 0

            if reward ~= 0 then
                g_client:getServerConnection():sendEvent(PolicyPointsEvent.new(farmId, reward, policy:getName()))
            end

            return report
        end
    },

    [PolicyIds.RESTRICTED_SLURRY] = {
        id = PolicyIds.RESTRICTED_SLURRY,
        name = "rt_policy_restricted_slurry",
        description = "rt_policy_description_restricted_slurry",
        report_description = "rt_policy_report_description_restricted_slurry",
        probability = 0.4,
        periodicReward = 20,
        periodicPenaltyPerViolation = -5,
        evaluationInterval = 1,
        minEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.restrictedSlurryViolations = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local pendingViolations = farmData.restrictedSlurryViolations or 0
            local reward = 0
            if pendingViolations > 0 then
                reward = policyInfo.periodicPenaltyPerViolation * pendingViolations
            else
                reward = policyInfo.periodicReward
            end

            local report = {}
            table.insert(report,
                { cell1 = g_i18n:getText("rt_report_name_restricted_slurry_violations"), cell2 = pendingViolations })

            farmData.restrictedSlurryViolations = 0

            if reward ~= 0 then
                g_client:getServerConnection():sendEvent(PolicyPointsEvent.new(farmId, reward, policy:getName()))
            end

            return report
        end,
    },
}
