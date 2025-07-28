Policy = {}
Policy_mt = Class(Policy)

-- Policy.EVALUATION_RESULT = {
--     COMPLIANT = 1,
--     NON_COMPLIANT = 2,
--     NO_RESULT = 3,
--     COMPLETE = 4
-- }

function Policy.new()
    local self = {}
    setmetatable(self, Policy_mt)

    self.policyIndex = nil
    self.nextEvaluationPeriod = nil
    self.nextEvaluationYear = nil
    self.evaluationCount = 0
    self.skipNextEvaluation = false
    self.policySystem = g_currentMission.RedTape.PolicySystem
    self.complete = false

    return self
end

function Policy:saveToXmlFile(xmlFile, key)
    -- TODO save commons here, then use the policy info to save specific data
    -- setXMLString(xmlFile, key .. "#id", self.id)
end

function Policy:loadFromXMLFile(xmlFile, key)
    -- TODO load commons here, then use the policy info to load specific data
    -- self.id = getXMLString(xmlFile, key .. "#id")
end

function Policy:activate()
    local policyInfo = Policies[self.policyIndex]

    if policyInfo.evaluationInterval > 0 then
        self.nextEvaluationPeriod = g_currentMission.environment.currentPeriod + policyInfo.evaluationInterval
        if self.nextEvaluationPeriod > 12 then
            self.nextEvaluationPeriod = self.nextEvaluationPeriod - 12
        end
        -- If the evaluation interval is 12, we skip the first evaluation as it loops back to evaluate immediately otherwise
        if policyInfo.evaluationInterval == 12 then self.skipNextEvaluation = true end
    end

    policyInfo.activate(policyInfo, self)

    print("Policy activated: " .. policyInfo.name)

    -- TODO sent an event here rather than an ingame notification
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
        string.format(g_i18n:getText("rt_notify_active_policy"), policyInfo.name))
end

function Policy:evaluate()
    if self.skipNextEvaluation then
        self.skipNextEvaluation = false
        return 0, false
    end

    local policyInfo = Policies[self.policyIndex]
    local currentPeriod = g_currentMission.environment.currentPeriod
    if currentPeriod ~= self.nextEvaluationPeriod then
        print("Policy not ready for evaluation. Current period: " .. currentPeriod ..
            ", Next evaluation period: " .. self.nextEvaluationPeriod)
        return 0, false
    end

    for farmId, farm in pairs(g_farmManager.farmIdToFarm) do
        local points = policyInfo.evaluate(policyInfo, self, farm.farmId)
        if points ~= 0 then self.policySystem:applyPoints(self, points, farm.farmId) end
    end

    self.evaluationCount = self.evaluationCount + 1
    self.complete = self.evaluationCount >= policyInfo.maxEvaluationCount

    if not self.complete then
        self.nextEvaluationPeriod = currentPeriod + policyInfo.evaluationInterval
    end
end

function Policy:complete()
    local policyInfo = Policies[self.policyIndex]
    return policyInfo.complete(policyInfo, self)
end
