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
    self.isComplete = false

    return self
end

function Policy:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.policyIndex)
    streamWriteInt32(streamId, self.nextEvaluationPeriod)
    streamWriteInt32(streamId, self.nextEvaluationYear)
    streamWriteInt32(streamId, self.evaluationCount)
    streamWriteBool(streamId, self.skipNextEvaluation)
    streamWriteBool(streamId, self.isComplete)
end

function Policy:readStream(streamId, connection)
    self.policyIndex = streamReadInt32(streamId)
    self.nextEvaluationPeriod = streamReadInt32(streamId)
    self.nextEvaluationYear = streamReadInt32(streamId)
    self.evaluationCount = streamReadInt32(streamId)
    self.skipNextEvaluation = streamReadBool(streamId)
    self.isComplete = streamReadBool(streamId)
end

function Policy:saveToXmlFile(xmlFile, key)
    -- TODO save commons here, then use the policy info to save specific data
    -- setXMLString(xmlFile, key .. "#id", self.id)
    setXMLInt(xmlFile, key .. "#policyIndex", self.policyIndex)
    setXMLInt(xmlFile, key .. "#nextEvaluationPeriod", self.nextEvaluationPeriod)
    setXMLInt(xmlFile, key .. "#nextEvaluationYear", self.nextEvaluationYear)
    setXMLInt(xmlFile, key .. "#evaluationCount", self.evaluationCount)
    setXMLBool(xmlFile, key .. "#skipNextEvaluation", self.skipNextEvaluation)
    setXMLBool(xmlFile, key .. "#isComplete", self.isComplete)
end

function Policy:loadFromXMLFile(xmlFile, key)
    -- TODO load commons here, then use the policy info to load specific data
    -- self.id = getXMLString(xmlFile, key .. "#id")
    self.policyIndex = getXMLInt(xmlFile, key .. "#policyIndex")
    self.nextEvaluationPeriod = getXMLInt(xmlFile, key .. "#nextEvaluationPeriod")
    self.nextEvaluationYear = getXMLInt(xmlFile, key .. "#nextEvaluationYear")
    self.evaluationCount = getXMLInt(xmlFile, key .. "#evaluationCount")
    self.skipNextEvaluation = getXMLBool(xmlFile, key .. "#skipNextEvaluation")
    self.isComplete = getXMLBool(xmlFile, key .. "#isComplete")
end

function Policy:getName()
    if self.policyIndex == nil then
        return nil
    end

    local policyInfo = Policies[self.policyIndex]

    return g_i18n:getText(policyInfo.name)
end

function Policy:getDescription()
    if self.policyIndex == nil then
        return nil
    end

    local policyInfo = Policies[self.policyIndex]

    return g_i18n:getText(policyInfo.description)
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

    for _, farm in pairs(g_farmManager.farmIdToFarm) do
        policyInfo.activate(policyInfo, self, farm.farmId)
    end


    print("Policy activated: " .. policyInfo.name)
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

    for _, farm in pairs(g_farmManager.farmIdToFarm) do
        local points = policyInfo.evaluate(policyInfo, self, farm.farmId)
        if points ~= 0 then
            local reason = string.format(g_i18n:getText("rt_policy_reason_evaluation"), points, self:getName())
            g_client:getServerConnection():sendEvent(PolicyPointsEvent.new(farm.farmId, points, reason))
        end
    end

    self.evaluationCount = self.evaluationCount + 1
    self.isComplete = self.evaluationCount >= policyInfo.maxEvaluationCount

    if not self.isComplete then
        self.nextEvaluationPeriod = currentPeriod + policyInfo.evaluationInterval
        if self.nextEvaluationPeriod > 12 then
            self.nextEvaluationPeriod = self.nextEvaluationPeriod - 12
        end
    end
end

function Policy:complete()
    local policyInfo = Policies[self.policyIndex]

    for _, farm in pairs(g_farmManager.farmIdToFarm) do
        local points = policyInfo.complete(policyInfo, self, farm.farmId)
        if points ~= 0 then
            local reason = string.format(g_i18n:getText("rt_policy_reason_completion"), points, self:getName())
            g_client:getServerConnection():sendEvent(PolicyPointsEvent.new(farm.farmId, reason))
        end
    end
end
