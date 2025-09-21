PolicySystem = {}
PolicySystem_mt = Class(PolicySystem)

PolicySystem.TIER = {
    A = 1,
    B = 2,
    C = 3,
    D = 4
}

PolicySystem.TIER_NAMES = {
    [PolicySystem.TIER.A] = "A",
    [PolicySystem.TIER.B] = "B",
    [PolicySystem.TIER.C] = "C",
    [PolicySystem.TIER.D] = "D"
}

PolicySystem.THRESHOLDS = {
    [PolicySystem.TIER.A] = 1500,
    [PolicySystem.TIER.B] = 750,
    [PolicySystem.TIER.C] = 300,
    [PolicySystem.TIER.D] = 0
}

PolicySystem.DESIRED_POLICY_COUNT = 10

function PolicySystem.new()
    local self = {}
    setmetatable(self, PolicySystem_mt)
    self.policies = {}
    self.points = {}

    return self
end

function PolicySystem:loadFromXMLFile(xmlFile)
    if (not g_currentMission:getIsServer()) then return end

    local key = RedTape.SaveKey .. ".policySystem"

    local i = 0
    while true do
        local policyKey = string.format(key .. ".policies.policy(%d)", i)
        if not hasXMLProperty(xmlFile, policyKey) then
            break
        end

        local policy = Policy.new()
        policy:loadFromXMLFile(xmlFile, policyKey)
        self:registerActivatedPolicy(policy, true)
        i = i + 1
    end

    local j = 0
    while true do
        local pointsKey = string.format(key .. ".points.farm(%d)", j)
        if not hasXMLProperty(xmlFile, pointsKey) then
            break
        end

        local farmId = getXMLInt(xmlFile, pointsKey .. "#farmId")
        local points = getXMLInt(xmlFile, pointsKey .. "#points")
        self.points[farmId] = points
        j = j + 1
    end
end

function PolicySystem:saveToXmlFile(xmlFile)
    if (not g_currentMission:getIsServer()) then return end

    local key = RedTape.SaveKey .. ".policySystem"

    local i = 0
    for _, group in pairs(self.policies) do
        local groupKey = string.format("%s.policies.policy(%d)", key, i)
        group:saveToXmlFile(xmlFile, groupKey)
        i = i + 1
    end

    local j = 0
    for farmId, points in pairs(self.points) do
        local pointsKey = string.format("%s.points.farm(%d)", key, j)
        setXMLInt(xmlFile, pointsKey .. "#farmId", farmId)
        setXMLInt(xmlFile, pointsKey .. "#points", points)
        j = j + 1
    end
end

function PolicySystem:hourChanged()
    -- local self = g_currentMission.RedTape.PolicySystem
end

function PolicySystem:periodChanged()
    local policySystem = g_currentMission.RedTape.PolicySystem

    for _, policy in ipairs(policySystem.policies) do
        policy:evaluate()
    end

    policySystem:generatePolicies()
end

function PolicySystem:generatePolicies()
    local rt = g_currentMission.RedTape
    local existingCount = rt:tableCount(self.policies)
    if existingCount < PolicySystem.DESIRED_POLICY_COUNT then
        local toCreate = PolicySystem.DESIRED_POLICY_COUNT - existingCount
        for i = 1, toCreate do
            local policy = Policy.new()
            local nextIndex = self:getNextPolicyIndex()
            if nextIndex == nil then
                break
            end
            policy.policyIndex = nextIndex
            policy:activate()
            g_client:getServerConnection():sendEvent(PolicyActivatedEvent.new(policy))
        end
    end
end

function PolicySystem:getNextPolicyIndex()
    local inUse = {}
    for _, policy in pairs(self.policies) do
        if policy.policyIndex then
            inUse[policy.policyIndex] = true
        end
    end

    local availablePolicies = {}
    for id, policy in pairs(Policies) do
        if not inUse[id] then
            table.insert(availablePolicies, policy)
        end
    end

    if #availablePolicies == 0 then
        return nil
    end

    print("Available policies: " .. #availablePolicies)

    -- sum the probabilities of available policies
    local totalProbability = 0
    for _, policy in pairs(availablePolicies) do
        totalProbability = totalProbability + policy.probability
    end

    print("Total probability: " .. totalProbability)

    if totalProbability == 0 then
        return nil -- No available policies to choose from
    end

    -- Choose a random policy based on their probabilities
    local randomValue = math.random() * totalProbability
    local cumulativeProbability = 0
    for _, policy in pairs(availablePolicies) do
        cumulativeProbability = cumulativeProbability + policy.probability
        if randomValue <= cumulativeProbability then
            print("Selected policy: " .. g_i18n:getText(policy.name))
            return policy.id -- Return the ID of the selected policy
        end
    end
    print("No policy selected, returning nil")

    return nil
end

-- Called from PolicyActivatedEvent or on loadFromXMLFile, runs on client and server
function PolicySystem:registerActivatedPolicy(policy, isLoading)
    table.insert(self.policies, policy)

    if not isLoading then
        g_currentMission.RedTape.EventLog:addEvent(policy.farmId, EventLogItem.EVENT_TYPE.POLICY_ACTIVATED,
            string.format(g_i18n:getText("rt_notify_active_policy"), policy:getName()), true)
    end
end

-- Called from PolicyPointsEvent, runs on client and server
function PolicySystem:applyPoints(farmId, points, reason)
    if self.points[farmId] == nil then
        self.points[farmId] = 0
    end

    self.points[farmId] = math.max(0, self.points[farmId] + points)
    g_currentMission.RedTape.EventLog:addEvent(farmId, EventLogItem.EVENT_TYPE.POLICY_POINTS, reason, false)
end

-- Called from PolicyCompletedEvent, runs on client
function PolicySystem:removePolicy(policyIndex)
    local removed = nil
    for i, p in ipairs(self.policies) do
        if p.policyIndex == policyIndex then
            removed = p:getName()
            print("Removing policy: " .. removed)
            table.remove(self.policies, i)
            break
        end
    end

    if removed == nil then
        print("Policy with index " .. policyIndex .. " not found while attempting to remove.")
        return
    end

    g_currentMission.RedTape.EventLog:addEvent(nil, EventLogItem.EVENT_TYPE.POLICY_COMPLETED,
        string.format(g_i18n:getText("rt_notify_completed_policy"), removed), true)
end

function PolicySystem:getProgressForCurrentFarm()
    local farmId = g_currentMission:getFarmId()
    return self:getProgressForFarm(farmId)
end

function PolicySystem:getProgressForFarm(farmId)
    local points = self.points[farmId] or 0

    local currentTier = PolicySystem.TIER.D
    for tier = PolicySystem.TIER.A, PolicySystem.TIER.D do
        local threshold = PolicySystem.THRESHOLDS[tier]
        if points >= threshold then
            currentTier = tier
            break
        end
    end

    if currentTier == PolicySystem.TIER.A then
        return {
            points = points,
            tier = currentTier,
            nextTierPoints = PolicySystem.THRESHOLDS[currentTier] -- maxed out
        }
    end

    local nextTierPoints = PolicySystem.THRESHOLDS[currentTier - 1]
    return {
        points = points,
        tier = currentTier,
        nextTierPoints = nextTierPoints
    }
end
