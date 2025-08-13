PolicyIds = {
    CROP_ROTATION = 1,
    SPRAY_VIOLATION = 2,
}

Policies = {
    [PolicyIds.CROP_ROTATION] = {
        id = PolicyIds.CROP_ROTATION,
        name = "rt_policy_croprotation",
        -- description = "Encourages farmers to rotate crops to maintain soil health.",
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
            local fruitsToSkip = { FruitType.GRASS, FruitType.MEADOW, FruitType.OILSEEDRADISH }

            local totalHa = 0
            local nonCompliantHa = 0

            if farmId == 1 then
                print("on farm 1")
            end

            for _, farmland in pairs(g_farmlandManager.farmlands) do
                if farmland.farmId == farmId and farmland.field ~= nil then
                    local farmLandData = ig:getFarmlandData(farmland.id)
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
        -- description = "Penalizes farms for excessive spraying violations.",
        probability = 0.5,
        periodicReward = 0,
        penaltyPerSprayViolation = 10,
        deductionPerViolationOnComplete = 1,
        maxCompleteReward = 500,
        evaluationInterval = 1,
        maxEvaluationCount = 12,
        activate = function(policyInfo, policy, farmId)
        end,
        evaluate = function(policyInfo, policy, farmId)
            local ig = g_currentMission.RedTape.InfoGatherer
            local farmData = ig:getFarmData(farmId)
            local pendingSprayViolations = farmData.pendingSprayViolations or 0
            local forgiveness = math.random(0, 3)

            if pendingSprayViolations > forgiveness then
                print("Farm " .. farmId .. ": Spray violations detected: " .. pendingSprayViolations)
                local pointsLost = policyInfo.penaltyPerSprayViolation * pendingSprayViolations
                farmData.sprayViolationsInCurrentPolicyWindow = farmData.sprayViolationsInCurrentPolicyWindow +
                pendingSprayViolations
                farmData.pendingSprayViolations = 0
                return -pointsLost
            else
                print("Farm " .. farmId .. ": No spray violations. Violations ignored: " .. farmData.pendingSprayViolations)
                farmData.pendingSprayViolations = 0
                return policyInfo.periodicReward
            end
        end,
        complete = function(policyInfo, policy, farmId)
            print("Spray Violation policy completed.")
            local ig = g_currentMission.RedTape.InfoGatherer
            local farmData = ig:getFarmData(farmId)
            local sprayViolationsInCurrentPolicyWindow = farmData.sprayViolationsInCurrentPolicyWindow or 0
            local reward = math.max(
                policyInfo.maxCompleteReward - (sprayViolationsInCurrentPolicyWindow * math.abs(policyInfo.deductionPerViolationOnComplete)),
                0)
            farmData.sprayViolationsInCurrentPolicyWindow = 0
            return reward
        end,
    },
}
