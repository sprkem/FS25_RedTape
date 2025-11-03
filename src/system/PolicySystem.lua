RTPolicySystem = {}
RTPolicySystem_mt = Class(RTPolicySystem)

RTPolicySystem.TIER = {
    A = 1,
    B = 2,
    C = 3,
    D = 4
}

RTPolicySystem.TIER_NAMES = {
    [RTPolicySystem.TIER.A] = "A",
    [RTPolicySystem.TIER.B] = "B",
    [RTPolicySystem.TIER.C] = "C",
    [RTPolicySystem.TIER.D] = "D"
}

RTPolicySystem.THRESHOLDS = {
    [RTPolicySystem.TIER.A] = 1500,
    [RTPolicySystem.TIER.B] = 750,
    [RTPolicySystem.TIER.C] = 300,
    [RTPolicySystem.TIER.D] = 0
}

RTPolicySystem.DESIRED_POLICY_COUNT = 10

function RTPolicySystem.new()
    local self = {}
    setmetatable(self, RTPolicySystem_mt)
    self.policies = {}
    self.points = {}
    self.warnings = {}

    MoneyType.POLICY_FINE = MoneyType.register("policyFine", "rt_ui_policyFine")
    MoneyType.LAST_ID = MoneyType.LAST_ID + 1

    return self
end

function RTPolicySystem:loadFromXMLFile(xmlFile)
    if (not g_currentMission:getIsServer()) then return end

    local key = RedTape.SaveKey .. ".policySystem"

    local i = 0
    while true do
        local policyKey = string.format(key .. ".policies.policy(%d)", i)
        if not hasXMLProperty(xmlFile, policyKey) then
            break
        end

        local policy = RTPolicy.new()
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

    local k = 0
    while true do
        local warningsKey = string.format(key .. ".warnings.farm(%d)", k)
        if not hasXMLProperty(xmlFile, warningsKey) then
            break
        end

        local farmId = getXMLInt(xmlFile, warningsKey .. "#farmId")
        local policyIndex = getXMLInt(xmlFile, warningsKey .. "#policyIndex")
        local warningCount = getXMLInt(xmlFile, warningsKey .. "#warningCount")
        table.insert(self.warnings, {
            farmId = farmId,
            policyIndex = policyIndex,
            warningCount = warningCount
        })
        k = k + 1
    end
end

function RTPolicySystem:saveToXmlFile(xmlFile)
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

    local k = 0
    for _, warning in pairs(self.warnings) do
        local warningsKey = string.format("%s.warnings.farm(%d)", key, k)
        setXMLInt(xmlFile, warningsKey .. "#farmId", warning.farmId)
        setXMLInt(xmlFile, warningsKey .. "#policyIndex", warning.policyIndex)
        setXMLInt(xmlFile, warningsKey .. "#warningCount", warning.warningCount)
        k = k + 1
    end
end

function RTPolicySystem:writeInitialClientState(streamId, connection)
    local policyCount = 0
    for _, _ in pairs(self.policies) do
        policyCount = policyCount + 1
    end
    streamWriteInt32(streamId, policyCount)

    for _, policy in pairs(self.policies) do
        policy:writeStream(streamId, connection)
    end

    local farmCount = 0
    for _ in pairs(self.points) do
        farmCount = farmCount + 1
    end
    streamWriteInt32(streamId, farmCount)
    for farmId, points in pairs(self.points) do
        streamWriteInt32(streamId, farmId)
        streamWriteInt32(streamId, points)
    end

    local warningCount = RedTape.tableCount(self.warnings)
    streamWriteInt32(streamId, warningCount)
    for _, warning in pairs(self.warnings) do
        streamWriteInt32(streamId, warning.farmId)
        streamWriteInt32(streamId, warning.policyIndex)
        streamWriteInt32(streamId, warning.warningCount)
    end
end

function RTPolicySystem:readInitialClientState(streamId, connection)
    local policyCount = streamReadInt32(streamId)
    for i = 1, policyCount do
        local policy = RTPolicy.new()
        policy:readStream(streamId, connection)
        self:registerActivatedPolicy(policy, false)
    end

    local farmCount = streamReadInt32(streamId)
    for i = 1, farmCount do
        local farmId = streamReadInt32(streamId)
        local points = streamReadInt32(streamId)
        self.points[farmId] = points
    end

    local warningCount = streamReadInt32(streamId)
    for i = 1, warningCount do
        local farmId = streamReadInt32(streamId)
        local policyIndex = streamReadInt32(streamId)
        local warningCount = streamReadInt32(streamId)
        table.insert(self.warnings, {
            farmId = farmId,
            policyIndex = policyIndex,
            warningCount = warningCount
        })
    end
end

function RTPolicySystem:hourChanged()
    -- local self = g_currentMission.RedTape.PolicySystem
end

function RTPolicySystem:periodChanged()
    local policySystem = g_currentMission.RedTape.PolicySystem

    for _, policy in ipairs(policySystem.policies) do
        policy:evaluate()
    end

    policySystem:generatePolicies()
end

function RTPolicySystem:generatePolicies()
    local rt = g_currentMission.RedTape
    local existingCount = rt.tableCount(self.policies)
    if existingCount < RTPolicySystem.DESIRED_POLICY_COUNT then
        local toCreate = RTPolicySystem.DESIRED_POLICY_COUNT - existingCount
        for i = 1, toCreate do
            local policy = RTPolicy.new()
            local nextIndex = self:getNextPolicyIndex()
            if nextIndex == nil then
                break
            end
            policy.policyIndex = nextIndex
            policy:activate()
            g_client:getServerConnection():sendEvent(RTPolicyActivatedEvent.new(policy))
        end
    end
end

function RTPolicySystem:getNextPolicyIndex()
    local inUse = {}
    for _, policy in pairs(self.policies) do
        if policy.policyIndex then
            inUse[policy.policyIndex] = true
        end
    end

    local availablePolicies = {}
    for id, policy in pairs(RTPolicies) do
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
-- Also called when loading RTInitialClientStateEvent
function RTPolicySystem:registerActivatedPolicy(policy, isLoading)
    table.insert(self.policies, policy)
    g_messageCenter:publish(MessageType.POLICIES_UPDATED)

    if not isLoading then
        g_currentMission.RedTape.EventLog:addEvent(policy.farmId, RTEventLogItem.EVENT_TYPE.POLICY_ACTIVATED,
            string.format(g_i18n:getText("rt_notify_active_policy"), policy:getName()), true)
    end
end

-- Called from PolicyPointsEvent, runs on client and server
function RTPolicySystem:applyPoints(farmId, points, reason)
    if self.points[farmId] == nil then
        self.points[farmId] = 0
    end

    self.points[farmId] = math.max(0, self.points[farmId] + points)
    g_messageCenter:publish(MessageType.POLICIES_UPDATED)
    g_currentMission.RedTape.EventLog:addEvent(farmId, RTEventLogItem.EVENT_TYPE.POLICY_POINTS, reason, false)
end

-- Called from PolicyCompletedEvent, runs on client
function RTPolicySystem:removePolicy(policyIndex)
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

    g_messageCenter:publish(MessageType.POLICIES_UPDATED)
    g_currentMission.RedTape.EventLog:addEvent(nil, RTEventLogItem.EVENT_TYPE.POLICY_COMPLETED,
        string.format(g_i18n:getText("rt_notify_completed_policy"), removed), true)
end

-- Called by RTPolicyWarningEvent
function RTPolicySystem:recordWarning(farmId, policyIndex)
    for _, warning in pairs(self.warnings) do
        if warning.farmId == farmId and warning.policyIndex == policyIndex then
            warning.warningCount = warning.warningCount + 1
            return
        end
    end

    table.insert(self.warnings, {
        farmId = farmId,
        policyIndex = policyIndex,
        warningCount = 1
    })

    for _, p in pairs(self.policies) do
        if p.policyIndex == policyIndex then
            g_currentMission.RedTape.EventLog:addEvent(farmId, RTEventLogItem.EVENT_TYPE.POLICY_WARNING,
                string.format(g_i18n:getText("rt_notify_policy_warning"), p:getName()), true)
            break
        end
    end
end

-- Called by RTPolicyFineEvent, runs on client and server
function RTPolicySystem:recordFine(farmId, policyIndex, amount)
    if g_currentMission:getIsServer() then
        g_currentMission:addMoneyChange(-amount, farmId, MoneyType.POLICY_FINE, true)
    end
    g_farmManager:getFarmById(farmId):changeBalance(-amount, MoneyType.POLICY_FINE)

    for _, p in pairs(self.policies) do
        if p.policyIndex == policyIndex then
            g_currentMission.RedTape.EventLog:addEvent(farmId, RTEventLogItem.EVENT_TYPE.POLICY_FINE,
                string.format(g_i18n:getText("rt_notify_policy_fine"), g_i18n:formatMoney(amount), p:getName()), true)
            break
        end
    end

    -- reset warnings to 0 for this policy after fine
    for _, warning in pairs(self.warnings) do
        if warning.farmId == farmId and warning.policyIndex == policyIndex then
            warning.warningCount = 0
            break
        end
    end
end

-- Called on the server during evaluation to warn and fine farms if warnings exceed the allowed amount
function RTPolicySystem:WarnAndFine(policyInfo, policy, farmId, fineIfDue)
    local futureWarningCount = policy:getWarningCount(farmId) + 1
    local allowedWarnings = policyInfo.maxWarnings or 1
    local sendFine = false
    if futureWarningCount > allowedWarnings then
        sendFine = true
    end
    g_client:getServerConnection():sendEvent(RTPolicyWarningEvent.new(farmId, policy.policyIndex))
    if sendFine and fineIfDue > 0 then
        g_client:getServerConnection():sendEvent(RTPolicyFineEvent.new(farmId, policy.policyIndex, fineIfDue))
    end
end

function RTPolicySystem:getWarningCountForFarmPolicy(farmId, policyIndex)
    for _, warning in pairs(self.warnings) do
        if warning.farmId == farmId and warning.policyIndex == policyIndex then
            return warning.warningCount
        end
    end

    return 0
end

function RTPolicySystem:getProgressForCurrentFarm()
    local farmId = g_currentMission:getFarmId()
    if farmId == nil or farmId == 0 then
        return nil
    end

    return self:getProgressForFarm(farmId)
end

function RTPolicySystem:getProgressForFarm(farmId)
    if farmId == nil or farmId == 0 then
        return nil
    end

    local points = self.points[farmId] or 0

    local currentTier = RTPolicySystem.TIER.D
    for tier = RTPolicySystem.TIER.A, RTPolicySystem.TIER.D do
        local threshold = RTPolicySystem.THRESHOLDS[tier]
        if points >= threshold then
            currentTier = tier
            break
        end
    end

    if currentTier == RTPolicySystem.TIER.A then
        return {
            points = points,
            tier = currentTier,
            nextTierPoints = RTPolicySystem.THRESHOLDS[currentTier] -- maxed out
        }
    end

    local nextTierPoints = RTPolicySystem.THRESHOLDS[currentTier - 1]
    return {
        points = points,
        tier = currentTier,
        nextTierPoints = nextTierPoints
    }
end
