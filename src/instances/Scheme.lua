Scheme = {}
Scheme_mt = Class(Scheme)


function Scheme.new()
    local self = {}
    setmetatable(self, Scheme_mt)

    self.schemeIndex = -1

    -- if -1, the scheme is open for selection by farms
    self.farmId = -1

    -- Set when a farm chooses a scheme
    self.activatedTier = -1

    self.lastEvaluationReport = {}

    return self
end

function Scheme:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.schemeIndex)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.activatedTier)

    streamWriteInt32(streamId, #self.lastEvaluationReport)
    for i, report in ipairs(self.lastEvaluationReport) do
        streamWriteString(streamId, report.name)
        streamWriteString(streamId, report.value)
    end
end

function Scheme:readStream(streamId, connection)
    self.schemeIndex = streamReadInt32(streamId)
    self.farmId = streamReadInt32(streamId)
    self.activatedTier = streamReadInt32(streamId)

    local reportCount = streamReadInt32(streamId)
    for i = 1, reportCount do
        local report = {
            name = streamReadString(streamId),
            value = streamReadString(streamId)
        }
        table.insert(self.lastEvaluationReport, report)
    end
end

function Scheme:saveToXmlFile(xmlFile, key)
    setXMLInt(xmlFile, key .. "#schemeIndex", self.schemeIndex)
    setXMLInt(xmlFile, key .. "#farmId", self.farmId)
    setXMLInt(xmlFile, key .. "#activatedTier", self.activatedTier)

    for i, report in ipairs(self.lastEvaluationReport) do
        local reportKey = string.format("%s#report(%d)", key, i)
        setXMLString(xmlFile, reportKey .. "#name", report.name)
        setXMLString(xmlFile, reportKey .. "#value", report.value)
    end
end

function Scheme:loadFromXMLFile(xmlFile, key)
    self.schemeIndex = getXMLInt(xmlFile, key .. "#schemeIndex")
    self.farmId = getXMLInt(xmlFile, key .. "#farmId")
    self.activatedTier = getXMLInt(xmlFile, key .. "#activatedTier")

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

-- Called by the SchemeSystem when generating schemes
function Scheme:initialise()
    local schemeInfo = Schemes[self.schemeIndex]
    schemeInfo.initialise(schemeInfo, self)
end

function Scheme:getName()
    if self.schemeIndex == -1 then
        return nil
    end

    local schemeInfo = Schemes[self.schemeIndex]

    return g_i18n:getText(schemeInfo.name)
end

function Scheme:getDescription()
    if self.schemeIndex == -1 then
        return nil
    end

    local schemeInfo = Schemes[self.schemeIndex]

    return g_i18n:getText(schemeInfo.description)
end

function Scheme:availableForCurrentFarm()
    local rt = g_currentMission.RedTape
    local schemeSystem = g_currentMission.RedTape.SchemeSystem
    local policySystem = g_currentMission.RedTape.PolicySystem
    local farmId = g_currentMission:getFarmId()
    local farmTier = policySystem:getProgressForCurrentFarm().tier
    local schemeInfo = Schemes[self.schemeIndex]

    -- Check if the scheme conflicts with another active scheme
    local activeSchemes = schemeSystem:getActiveSchemesForFarm(farmId)
    for _, scheme in pairs(activeSchemes) do
        local activeSchemeInfo = Schemes[scheme.schemeIndex]
        if activeSchemeInfo.duplicationKey == schemeInfo.duplicationKey then
            return false
        end
    end

    -- Check if the scheme supports the current farm tier
    if not rt:tableHasKey(schemeInfo.tiers, farmTier) then
        return false
    end

    return true
end

function Scheme:evaluate()
    local schemeInfo = Schemes[self.schemeIndex]
    local report = schemeInfo.evaluate(schemeInfo, self, self.activatedTier)
    self.lastEvaluationReport = report or {}

    -- Ensure all report values are strings
    for _, report in ipairs(self.lastEvaluationReport) do
        report.value = tostring(report.value)
    end
end

function Scheme:selected()
    if not g_currentMission:getIsServer() then
        return
    end

    local schemeInfo = Schemes[self.schemeIndex]
    schemeInfo.selected(schemeInfo, self, self.farmId)
end

-- Creates a new farm specific scheme from
function Scheme:createFarmScheme(farmId)
    local policySystem = g_currentMission.RedTape.PolicySystem
    local farmScheme = Scheme.new()
    farmScheme.schemeIndex = self.schemeIndex
    farmScheme.farmId = farmId
    farmScheme.activatedTier = policySystem:getProgressForFarm(farmId).tier
    return farmScheme
end
