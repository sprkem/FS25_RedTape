PolicyIds = {
    CROP_ROTATION = 1
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
        evaluationInterval = 2, -- TODO revert to 12
        maxEvaluationCount = 3,
        activate = function(policyInfo, policy)
            print("Activating Crop Rotation policy...")
        end,
        evaluate = function(policyInfo, policy, farmId)
            local data = g_currentMission.RedTape.data
            local currentPeriod = g_currentMission.environment.currentPeriod
            local currentYear = g_currentMission.environment.currentYear

            local totalHa = 0
            local nonCompliantHa = 0

            if farmId == 1 then
                print("on farm 1")
            end

            for _, farmland in pairs(g_farmlandManager.farmlands) do
                if farmland.farmId == farmId and farmland.field ~= nil then
                    local previousFruit = data[INFO_KEYS.FARMLANDS][currentYear][currentPeriod - 1][farmland.id].fruit
                    local currentFruit = data[INFO_KEYS.FARMLANDS][currentYear][currentPeriod][farmland.id].fruit

                    totalHa = totalHa + data[INFO_KEYS.FARMLANDS][currentYear][currentPeriod][farmland.id].areaHa
                    if previousFruit == currentFruit then
                        nonCompliantHa = nonCompliantHa +
                            data[INFO_KEYS.FARMLANDS][currentYear][currentPeriod][farmland.id].areaHa
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
        complete = function(policyInfo, policy)
            print("Crop Rotation policy completed.")

            -- Custom Logic to handle policy completion


            return policyInfo.completeReward
        end,
    }
}
