Policy = {}
Policy_mt = Class(Policy)

function Policy.new()
    local self = {}
    setmetatable(self, Policy_mt)

    self.policyIndex = -1
    self.nextEvaluationMonth = -1
    self.evaluationCount = 0
    self.policySystem = g_currentMission.RedTape.PolicySystem
    self.lastEvaluationReport = {}

    return self
end

function Policy:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.policyIndex)
    streamWriteInt32(streamId, self.nextEvaluationMonth)
    streamWriteInt32(streamId, self.evaluationCount)

    streamWriteInt32(streamId, #self.lastEvaluationReport)
    for _, report in pairs(self.lastEvaluationReport) do
        streamWriteString(streamId, report.cell1)
        streamWriteString(streamId, report.cell2)
        streamWriteString(streamId, report.cell3)
    end
end

function Policy:readStream(streamId, connection)
    self.policyIndex = streamReadInt32(streamId)
    self.nextEvaluationMonth = streamReadInt32(streamId)
    self.evaluationCount = streamReadInt32(streamId)

    local reportCount = streamReadInt32(streamId)
    for i = 1, reportCount do
        local report = {
            cell1 = streamReadString(streamId),
            cell2 = streamReadString(streamId),
            cell3 = streamReadString(streamId)
        }
        table.insert(self.lastEvaluationReport, report)
    end
end

function Policy:saveToXmlFile(xmlFile, key)
    setXMLInt(xmlFile, key .. "#policyIndex", self.policyIndex)
    setXMLInt(xmlFile, key .. "#nextEvaluationMonth", self.nextEvaluationMonth)
    setXMLInt(xmlFile, key .. "#evaluationCount", self.evaluationCount)

    local i = 0
    for _, report in pairs(self.lastEvaluationReport) do
        local reportKey = string.format("%s.reportItems.item(%d)", key, i)
        setXMLString(xmlFile, reportKey .. "#cell1", report.cell1)
        setXMLString(xmlFile, reportKey .. "#cell2", report.cell2)
        setXMLString(xmlFile, reportKey .. "#cell3", report.cell3)
        i = i + 1
    end
end

function Policy:loadFromXMLFile(xmlFile, key)
    self.policyIndex = getXMLInt(xmlFile, key .. "#policyIndex")
    self.nextEvaluationMonth = getXMLInt(xmlFile, key .. "#nextEvaluationMonth")
    self.evaluationCount = getXMLInt(xmlFile, key .. "#evaluationCount")

    local i = 0
    while true do
        local reportKey = string.format("%s.reportItems.item(%d)", key, i)
        if not hasXMLProperty(xmlFile, reportKey) then
            break
        end
        local report = {
            cell1 = getXMLString(xmlFile, reportKey .. "#cell1"),
            cell2 = getXMLString(xmlFile, reportKey .. "#cell2"),
            cell3 = getXMLString(xmlFile, reportKey .. "#cell3")
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

function Policy:getReportDescription()
    if self.policyIndex == -1 then
        return nil
    end

    local policyInfo = Policies[self.policyIndex]

    return g_i18n:getText(policyInfo.report_description)
end

function Policy:activate()
    local policyInfo = Policies[self.policyIndex]

    if policyInfo == nil then
        print("Error: Invalid policy index " .. tostring(self.policyIndex))
        return
    end

    if policyInfo.evaluationInterval > 0 then
        self.nextEvaluationMonth = RedTape.getCumulativeMonth() + policyInfo.evaluationInterval
    end

    for _, farm in pairs(g_farmManager.farmIdToFarm) do
        policyInfo.activate(policyInfo, self, farm.farmId)
    end

    print("Policy activated: " .. policyInfo.name)
end

function Policy:evaluate()
    local rt = g_currentMission.RedTape

    local policyInfo = Policies[self.policyIndex]
    local cumulativeMonth = RedTape.getCumulativeMonth()
    if cumulativeMonth ~= self.nextEvaluationMonth then
        return
    end

    for _, farm in pairs(g_farmManager.farmIdToFarm) do
        local report = policyInfo.evaluate(policyInfo, self, farm.farmId)
        if report ~= nil then
            self.lastEvaluationReport = report or {}

            -- Ensure all report values are strings
            for _, report in pairs(self.lastEvaluationReport) do
                report.cell1 = tostring(report.cell1 or "")
                report.cell2 = tostring(report.cell2 or "")
                report.cell3 = tostring(report.cell3 or "")
            end
        end
    end

    self.evaluationCount = self.evaluationCount + 1
    self.nextEvaluationMonth = cumulativeMonth + policyInfo.evaluationInterval
end
