RTPolicy = {}
RTPolicy_mt = Class(RTPolicy)

function RTPolicy.new()
    local self = {}
    setmetatable(self, RTPolicy_mt)

    self.id = RedTape.generateId()
    self.policyIndex = -1
    self.nextEvaluationMonth = -1
    self.evaluationCount = 0
    -- self.lastEvaluationReport = {}
    self.evaluationReports = {}

    return self
end

function RTPolicy:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
    streamWriteInt32(streamId, self.policyIndex)
    streamWriteInt32(streamId, self.nextEvaluationMonth)
    streamWriteInt32(streamId, self.evaluationCount)

    streamWriteInt32(streamId, #RedTape.tableCount(self.evaluationReports))
    for farmId, report in pairs(self.evaluationReports) do
        streamWriteString(streamId, farmId)
        streamWriteString(streamId, report.cell1)
        streamWriteString(streamId, report.cell2)
        streamWriteString(streamId, report.cell3)
    end
end

function RTPolicy:readStream(streamId, connection)
    self.id = streamReadString(streamId)
    self.policyIndex = streamReadInt32(streamId)
    self.nextEvaluationMonth = streamReadInt32(streamId)
    self.evaluationCount = streamReadInt32(streamId)

    local reportCount = streamReadInt32(streamId)
    self.evaluationReports = {}
    for i = 1, reportCount do
        local farmId = streamReadString(streamId)
        local report = {
            cell1 = streamReadString(streamId),
            cell2 = streamReadString(streamId),
            cell3 = streamReadString(streamId)
        }
        self.evaluationReports[farmId] = report
    end
end

function RTPolicy:saveToXmlFile(xmlFile, key)
    setXMLString(xmlFile, key .. "#id", self.id)
    setXMLInt(xmlFile, key .. "#policyIndex", self.policyIndex)
    setXMLInt(xmlFile, key .. "#nextEvaluationMonth", self.nextEvaluationMonth)
    setXMLInt(xmlFile, key .. "#evaluationCount", self.evaluationCount)

    local i = 0
    for farmId, report in pairs(self.evaluationReports) do
        local reportKey = string.format("%s.evaluationReports.item(%d)", key, i)
        setXMLString(xmlFile, reportKey .. "#farmId", farmId)
        setXMLString(xmlFile, reportKey .. "#cell1", report.cell1)
        setXMLString(xmlFile, reportKey .. "#cell2", report.cell2)
        setXMLString(xmlFile, reportKey .. "#cell3", report.cell3)
        i = i + 1
    end
end

function RTPolicy:loadFromXMLFile(xmlFile, key)
    self.id = getXMLString(xmlFile, key .. "#id") or RedTape.generateId()
    self.policyIndex = getXMLInt(xmlFile, key .. "#policyIndex")
    self.nextEvaluationMonth = getXMLInt(xmlFile, key .. "#nextEvaluationMonth")
    self.evaluationCount = getXMLInt(xmlFile, key .. "#evaluationCount") or 0

    local i = 0
    self.evaluationReports = {}
    while true do
        local reportKey = string.format("%s.evaluationReports.item(%d)", key, i)
        if not hasXMLProperty(xmlFile, reportKey) then
            break
        end

        local farmId = getXMLString(xmlFile, reportKey .. "#farmId")
        local report = {
            cell1 = getXMLString(xmlFile, reportKey .. "#cell1") or "",
            cell2 = getXMLString(xmlFile, reportKey .. "#cell2") or "",
            cell3 = getXMLString(xmlFile, reportKey .. "#cell3") or ""
        }
        self.evaluationReports[farmId] = report

        i = i + 1
    end
end

function RTPolicy:getName()
    if self.policyIndex == -1 then
        return nil
    end

    local policyInfo = RTPolicies[self.policyIndex]

    return g_i18n:getText(policyInfo.name)
end

function RTPolicy:getDescription()
    if self.policyIndex == -1 then
        return nil
    end

    local policyInfo = RTPolicies[self.policyIndex]

    return g_i18n:getText(policyInfo.description)
end

function RTPolicy:getWarningCount(farmId)
    return g_currentMission.RedTape.PolicySystem:getWarningCountForFarmPolicy(farmId, self.policyIndex)
end

function RTPolicy:getReportDescription()
    if self.policyIndex == -1 then
        return nil
    end

    local policyInfo = RTPolicies[self.policyIndex]

    return g_i18n:getText(policyInfo.report_description)
end

function RTPolicy:activate()
    local policyInfo = RTPolicies[self.policyIndex]

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

function RTPolicy:evaluate()
    local rt = g_currentMission.RedTape

    local policyInfo = RTPolicies[self.policyIndex]
    local cumulativeMonth = RedTape.getCumulativeMonth()
    -- Accounts for possible skipping of time
    if cumulativeMonth < self.nextEvaluationMonth then
        return
    end

    for _, farm in pairs(g_farmManager.farmIdToFarm) do
        local report = policyInfo.evaluate(policyInfo, self, farm.farmId)
        if report ~= nil then
            report = report or {}

            -- Ensure all report values are strings
            for _, reportLine in pairs(report) do
                reportLine.cell1 = tostring(reportLine.cell1 or "")
                reportLine.cell2 = tostring(reportLine.cell2 or "")
                reportLine.cell3 = tostring(reportLine.cell3 or "")
            end
        end

        g_client:getServerConnection():sendEvent(RTPolicyReportEvent.new(self.policyIndex, farm.farmId, report))
    end

    self.evaluationCount = self.evaluationCount + 1
    self.nextEvaluationMonth = cumulativeMonth + policyInfo.evaluationInterval
end
