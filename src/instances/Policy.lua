Policy = {}
Policy_mt = Class(Policy)

-- Policy.EVALUATION_RESULT = {
--     COMPLIANT = 1,
--     NON_COMPLIANT = 2,
--     NO_RESULT = 3,
--     COMPLETE = 4
-- }

-- Policy.FORCE_EVALUATE_ALL = true -- TODO once testing complete

function Policy.new()
    local self = {}
    setmetatable(self, Policy_mt)

    self.policyIndex = -1
    self.nextEvaluationPeriod = -1
    self.evaluationCount = 0
    self.skipNextEvaluation = false
    self.policySystem = g_currentMission.RedTape.PolicySystem
    self.lastEvaluationReport = {}

    return self
end

function Policy:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.policyIndex)
    streamWriteInt32(streamId, self.nextEvaluationPeriod)
    streamWriteInt32(streamId, self.evaluationCount)
    streamWriteBool(streamId, self.skipNextEvaluation)

    streamWriteInt32(streamId, #self.lastEvaluationReport)
    for i, report in ipairs(self.lastEvaluationReport) do
        streamWriteString(streamId, report.name)
        streamWriteString(streamId, report.value)
    end
end

function Policy:readStream(streamId, connection)
    self.policyIndex = streamReadInt32(streamId)
    self.nextEvaluationPeriod = streamReadInt32(streamId)
    self.evaluationCount = streamReadInt32(streamId)
    self.skipNextEvaluation = streamReadBool(streamId)

    local reportCount = streamReadInt32(streamId)
    for i = 1, reportCount do
        local report = {
            name = streamReadString(streamId),
            value = streamReadString(streamId)
        }
        table.insert(self.lastEvaluationReport, report)
    end
end

function Policy:saveToXmlFile(xmlFile, key)
    setXMLInt(xmlFile, key .. "#policyIndex", self.policyIndex)
    setXMLInt(xmlFile, key .. "#nextEvaluationPeriod", self.nextEvaluationPeriod)
    setXMLInt(xmlFile, key .. "#evaluationCount", self.evaluationCount)
    setXMLBool(xmlFile, key .. "#skipNextEvaluation", self.skipNextEvaluation)

    for i, report in ipairs(self.lastEvaluationReport) do
        local reportKey = string.format("%s#report(%d)", key, i)
        setXMLString(xmlFile, reportKey .. "#name", report.name)
        setXMLString(xmlFile, reportKey .. "#value", report.value)
    end
end

function Policy:loadFromXMLFile(xmlFile, key)
    self.policyIndex = getXMLInt(xmlFile, key .. "#policyIndex")
    self.nextEvaluationPeriod = getXMLInt(xmlFile, key .. "#nextEvaluationPeriod")
    self.evaluationCount = getXMLInt(xmlFile, key .. "#evaluationCount")
    self.skipNextEvaluation = getXMLBool(xmlFile, key .. "#skipNextEvaluation")

    local i = 0
    while true do
        local reportKey = string.format("%s#report(%d)", key, i)
        if not hasXMLProperty(xmlFile, reportKey) then
            break
        end
        local report = {
            name = getXMLString(xmlFile, reportKey .. "#name"),
            value = getXMLString(xmlFile, reportKey .. "#value")
        }
        table.insert(self.lastEvaluationReport, report)
        i = i + 1
    end
end

function Policy:getName()
    if self.policyIndex == -1 then
        return nil
    end

    local policyInfo = Policies[self.policyIndex]

    return g_i18n:getText(policyInfo.name)
end

function Policy:getDescription()
    if self.policyIndex == -1 then
        return nil
    end

    local policyInfo = Policies[self.policyIndex]

    return g_i18n:getText(policyInfo.description)
end

function Policy:activate()
    local policyInfo = Policies[self.policyIndex]

    if policyInfo == nil then
        print("Error: Invalid policy index " .. tostring(self.policyIndex))
        return
    end

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
    local rt = g_currentMission.RedTape
    if self.skipNextEvaluation then
        self.skipNextEvaluation = false
        return
    end

    local policyInfo = Policies[self.policyIndex]
    local currentPeriod = g_currentMission.environment.currentPeriod
    if currentPeriod ~= self.nextEvaluationPeriod then
        print("Policy not ready for evaluation. Current period: " .. currentPeriod ..
            ", Next evaluation period: " .. self.nextEvaluationPeriod)
        return
    end

    for _, farm in pairs(g_farmManager.farmIdToFarm) do
        local points, report = policyInfo.evaluate(policyInfo, self, farm.farmId)
        if rt:tableCount(report) > 0 then
            self.lastEvaluationReport = report or {}

            -- Ensure all report values are strings
            for _, report in ipairs(self.lastEvaluationReport) do
                report.cell1 = tostring(report.cell1 or "")
                report.cell2 = tostring(report.cell2 or "")
                report.cell3 = tostring(report.cell3 or "")
            end
        end

        -- TODO move this to within the policyInfo as per schemes
        if points ~= 0 then
            local reason = string.format(g_i18n:getText("rt_policy_reason_evaluation"), points, self:getName())
            g_client:getServerConnection():sendEvent(PolicyPointsEvent.new(farm.farmId, points, reason))
        end
    end

    self.evaluationCount = self.evaluationCount + 1
    self.nextEvaluationPeriod = currentPeriod + policyInfo.evaluationInterval
    if self.nextEvaluationPeriod > 12 then
        self.nextEvaluationPeriod = self.nextEvaluationPeriod - 12
    end
end
