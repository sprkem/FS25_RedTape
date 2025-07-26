PolicyIds = {
    CROP_ROTATION = 1
}

Policies = {
    [PolicyIds.CROP_ROTATION] = {
        id = PolicyIds.CROP_ROTATION,
        name = "Crop Rotation",
        description = "Encourages farmers to rotate crops to maintain soil health.",
        probability = 0.8,
        reward = 100,
        penalty = -50,
        evaluate = function(policy)
            local facts = policy.policySystem.facts
            -- Logic to evaluate crop rotation compliance
            -- This is a placeholder for actual evaluation logic
            return Policy.EVALUATION_RESULT.COMPLIANT
        end
    }
}
