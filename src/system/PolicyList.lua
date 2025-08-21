PolicyIds = {
    CROP_ROTATION = 1,
    SPRAY_VIOLATION = 2,
    EMPTY_STRAW = 3,
    FULL_SLURRY = 4,
    EMPTY_FOOD = 5,
    ANIMAL_SPACE = 6,
    ANIMAL_PRODUCTIVITY = 7,
    MANURE_SPREADING = 8,
}

Policies = {

    [PolicyIds.CROP_ROTATION] = {
        id = PolicyIds.CROP_ROTATION,
        name = "rt_policy_croprotation",
        description = "rt_policy_description_croprotation",
        probability = 0.8,
        periodicReward = 100,
        periodicPenalty = -200,
        completeReward = 0,
        evaluationInterval = 12,
        maxEvaluationCount = 3,
        activate = function(policyInfo, policy, farmId)
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMLANDS]
            local fruitsToSkip = { FruitType.GRASS, FruitType.MEADOW, FruitType.OILSEEDRADISH }

            local totalHa = 0
            local nonCompliantHa = 0

            for _, farmland in pairs(g_farmlandManager.farmlands) do
                if farmland.farmId == farmId and farmland.field ~= nil then
                    local farmLandData = gatherer:getFarmlandData(farmland.id)
                    local mostRecentFruit = farmLandData.mostRecentFruit
                    local previousFruit = farmLandData.previousFruit

                    if farmLandData.fallowMonths > 10 then
                        print("Skipping farmland " ..
                            farmland.id .. " due to fallow months: " .. farmLandData.fallowMonths)
                        continue
                    end

                    if mostRecentFruit and not RedTape:tableHasValue(fruitsToSkip, mostRecentFruit) then
                        print("Skipping farmland " .. farmland.id .. " with fruit " .. mostRecentFruit)
                        continue
                    end

                    if previousFruit == nil then
                        print("Skipping farmland " .. farmland.id .. " due to no previous fruit.")
                        continue
                    end

                    totalHa = totalHa + farmLandData.areaHa
                    if previousFruit == mostRecentFruit then
                        nonCompliantHa = nonCompliantHa + farmLandData.areaHa
                    end
                end
            end

            -- Return reward if fully compliant or a proportional penalty if not
            if nonCompliantHa == 0 then
                print("Farm " .. farmId .. ": All farmlands compliant with Crop Rotation policy.")
                return policyInfo.periodicReward
            else
                local nonCompliantProportion = nonCompliantHa / totalHa
                print("Farm " .. farmId .. ": Non-compliant area: " .. nonCompliantHa .. " ha, Total area: " ..
                    totalHa .. " ha, Compliance rate: " .. nonCompliantProportion)
                return policyInfo.periodicPenalty * nonCompliantProportion
            end
        end,
        complete = function(policyInfo, policy, farmId)
            print("Crop Rotation policy completed.")
            return policyInfo.completeReward
        end,
    },

    [PolicyIds.SPRAY_VIOLATION] = {
        id = PolicyIds.SPRAY_VIOLATION,
        name = "rt_policy_sprayviolation",
        description = "rt_policy_description_sprayviolation",
        probability = 0.5,
        periodicReward = 5,
        periodicPenaltyPerViolation = 10,
        deductionPerViolationOnComplete = 5,
        maxCompleteReward = 500,
        evaluationInterval = 1,
        maxEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingSprayViolations = 0
            farmData.totalSprayViolations = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local pendingSprayViolations = farmData.pendingSprayViolations or 0
            local forgiveness = math.random(0, 3)

            if pendingSprayViolations > forgiveness then
                print("Farm " .. farmId .. ": Spray violations detected: " .. pendingSprayViolations)
                local pointsLost = policyInfo.periodicPenaltyPerViolation * pendingSprayViolations
                farmData.totalSprayViolations = farmData.totalSprayViolations + pendingSprayViolations
                farmData.pendingSprayViolations = 0
                return -pointsLost
            else
                print("Farm " ..
                    farmId .. ": No spray violations. Violations ignored: " .. farmData.pendingSprayViolations)
                farmData.pendingSprayViolations = 0
                return policyInfo.periodicReward
            end
        end,
        complete = function(policyInfo, policy, farmId)
            print("Spray Violation policy completed.")
            local ig = g_currentMission.RedTape.InfoGatherer
            local farmData = ig:getFarmData(farmId)
            local totalSprayViolations = farmData.totalSprayViolations or 0
            local reward = math.max(
                policyInfo.maxCompleteReward -
                (totalSprayViolations * math.abs(policyInfo.deductionPerViolationOnComplete)),
                0)
            farmData.totalSprayViolations = 0
            return reward
        end,
    },

    [PolicyIds.EMPTY_STRAW] = {
        id = PolicyIds.EMPTY_STRAW,
        name = "rt_policy_empty_straw",
        description = "rt_policy_description_empty_straw",
        probability = 0.6,
        periodicReward = 5,
        periodicPenaltyPerViolation = -2,
        deductionPerViolationOnComplete = 5,
        maxCompleteReward = 500,
        evaluationInterval = 1,
        maxEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingEmptyStrawCount = 0
            farmData.totalEmptyStrawCount = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local pendingEmptyStrawCount = farmData.pendingEmptyStrawCount or 0
            local reward = 0
            if pendingEmptyStrawCount > 0 then
                reward = -(policyInfo.periodicPenaltyPerViolation * pendingEmptyStrawCount)
                farmData.totalEmptyStrawCount = farmData.totalEmptyStrawCount + pendingEmptyStrawCount
            else
                reward = policyInfo.periodicReward
            end
            farmData.pendingEmptyStrawCount = 0
            return reward
        end,
        complete = function(policyInfo, policy, farmId)
            print("Empty Straw policy completed.")
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local totalEmptyStrawCount = farmData.totalEmptyStrawCount or 0
            local reward = math.max(
                policyInfo.maxCompleteReward -
                (totalEmptyStrawCount * math.abs(policyInfo.deductionPerViolationOnComplete)),
                0)
            farmData.totalEmptyStrawCount = 0
            return reward
        end,
    },

    [PolicyIds.FULL_SLURRY] = {
        id = PolicyIds.FULL_SLURRY,
        name = "rt_policy_full_slurry",
        description = "rt_policy_description_full_slurry",
        probability = 0.5,
        periodicReward = 5,
        periodicPenaltyPerViolation = -3,
        deductionPerViolationOnComplete = 5,
        maxCompleteReward = 500,
        evaluationInterval = 1,
        maxEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingFullSlurryCount = 0
            farmData.totalFullSlurryCount = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local pendingFullSlurryCount = farmData.pendingFullSlurryCount or 0
            local reward = 0
            if pendingFullSlurryCount > 0 then
                reward = -(policyInfo.periodicPenaltyPerViolation * pendingFullSlurryCount)
                farmData.totalFullSlurryCount = farmData.totalFullSlurryCount + pendingFullSlurryCount
            else
                reward = policyInfo.periodicReward
            end
            farmData.pendingFullSlurryCount = 0
            return reward
        end,
        complete = function(policyInfo, policy, farmId)
            print("Full Slurry policy completed.")
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local totalFullSlurryCount = farmData.totalFullSlurryCount or 0
            local reward = math.max(
                policyInfo.maxCompleteReward -
                (totalFullSlurryCount * math.abs(policyInfo.deductionPerViolationOnComplete)),
                0)
            farmData.totalFullSlurryCount = 0
            return reward
        end,
    },

    [PolicyIds.EMPTY_FOOD] = {
        id = PolicyIds.EMPTY_FOOD,
        name = "rt_policy_empty_food",
        description = "rt_policy_description_empty_food",
        probability = 0.7,
        periodicReward = 5,
        periodicPenaltyPerViolation = -3,
        deductionPerViolationOnComplete = 5,
        maxCompleteReward = 500,
        evaluationInterval = 1,
        maxEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingEmptyFoodCount = 0
            farmData.totalEmptyFoodCount = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local pendingEmptyFoodCount = farmData.pendingEmptyFoodCount or 0
            local reward = 0
            if pendingEmptyFoodCount > 0 then
                reward = -(policyInfo.periodicPenaltyPerViolation * pendingEmptyFoodCount)
                farmData.totalEmptyFoodCount = farmData.totalEmptyFoodCount + pendingEmptyFoodCount
            else
                reward = policyInfo.periodicReward
            end
            farmData.pendingEmptyFoodCount = 0
            return reward
        end,
        complete = function(policyInfo, policy, farmId)
            print("Empty Food policy completed.")
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local totalEmptyFoodCount = farmData.totalEmptyFoodCount or 0
            local reward = math.max(
                policyInfo.maxCompleteReward -
                (totalEmptyFoodCount * math.abs(policyInfo.deductionPerViolationOnComplete)),
                0)
            farmData.totalEmptyFoodCount = 0
            return reward
        end,
    },

    [PolicyIds.ANIMAL_SPACE] = {
        id = PolicyIds.ANIMAL_SPACE,
        name = "rt_policy_animal_space",
        description = "rt_policy_description_animal_space",
        probability = 0.6,
        periodicReward = 10,
        periodicPenaltyPerViolation = -1,
        deductionPerViolationOnComplete = 10,
        maxCompleteReward = 300,
        evaluationInterval = 1,
        maxEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingAnimalSpaceViolations = 0
            farmData.totalAnimalSpaceViolations = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local pendingViolations = farmData.pendingAnimalSpaceViolations or 0
            local reward = 0
            if pendingViolations > 0 then
                reward = policyInfo.periodicPenaltyPerViolation * pendingViolations
                farmData.totalAnimalSpaceViolations = farmData.totalAnimalSpaceViolations + pendingViolations
            else
                reward = policyInfo.periodicReward
            end
            farmData.pendingAnimalSpaceViolations = 0
            return reward
        end,
        complete = function(policyInfo, policy, farmId)
            print("Animal Space policy completed.")
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local totalViolations = farmData.totalAnimalSpaceViolations or 0
            local reward = math.max(
                policyInfo.maxCompleteReward -
                (totalViolations * math.abs(policyInfo.deductionPerViolationOnComplete)),
                0)
            farmData.totalAnimalSpaceViolations = 0
            return reward
        end,
    },

    [PolicyIds.ANIMAL_PRODUCTIVITY] = {
        id = PolicyIds.ANIMAL_PRODUCTIVITY,
        name = "rt_policy_animal_productivity",
        description = "rt_policy_description_animal_productivity",
        probability = 0.3,
        periodicReward = 15,
        periodicPenaltyPerViolation = -1,
        deductionPerViolationOnComplete = 15,
        maxCompleteReward = 400,
        evaluationInterval = 1,
        maxEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingLowProductivityHusbandry = 0
            farmData.totalLowProductivityHusbandry = 0
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local pendingViolations = farmData.pendingLowProductivityHusbandry or 0
            local reward = 0
            if pendingViolations > 0 then
                reward = policyInfo.periodicPenaltyPerViolation * pendingViolations
                farmData.totalLowProductivityHusbandry = farmData.totalLowProductivityHusbandry + pendingViolations
            else
                reward = policyInfo.periodicReward
            end
            farmData.pendingLowProductivityHusbandry = 0
            return reward
        end,
        complete = function(policyInfo, policy, farmId)
            print("Animal Productivity policy completed.")
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            local totalViolations = farmData.totalLowProductivityHusbandry or 0
            local reward = math.max(
                policyInfo.maxCompleteReward -
                (totalViolations * math.abs(policyInfo.deductionPerViolationOnComplete)),
                0)
            farmData.totalLowProductivityHusbandry = 0
            return reward
        end,
    },

    [PolicyIds.MANURE_SPREADING] = {
        id = PolicyIds.MANURE_SPREADING,
        name = "rt_policy_manure_spreading",
        description = "rt_policy_description_manure_spreading",
        probability = 0.4,
        periodicReward = 50,
        periodicPenalty = -100,
        completeReward = 0,
        evaluationInterval = 6,
        maxEvaluationCount = 4,
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
            local expectedSpread = farmData.rollingAverageManureLevel * 0.5

            local reward = 0
            if farmData.pendingManureSpread < expectedSpread then
                reward = policyInfo.periodicPenaltyPerViolation
            else
                reward = policyInfo.periodicReward
            end
            farmData.pendingManureSpread = 0
            return reward
        end,
        complete = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]
            local farmData = gatherer:getFarmData(farmId)
            farmData.pendingManureSpread = 0
            return policyInfo.completeReward
        end,
    },
}
