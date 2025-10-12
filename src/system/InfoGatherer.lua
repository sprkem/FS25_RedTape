InfoGatherer = {}
InfoGatherer_mt = Class(InfoGatherer)

InfoGatherer.RETENTION_YEARS = 5

INFO_KEYS = {
    FARMLANDS = "farmlands",
    FARMS = "farms",
}

-- SAVE_FUNCTIONS = {
--     [INFO_KEYS.FARMLANDS] = function(self, xmlFile, key)
--         setXMLString(xmlFile, key, table.concat(self.data.farmlands, ","))
--     end,
--     [INFO_KEYS.FARMS] = function(self, xmlFile, key)
--         setXMLString(xmlFile, key, table.concat(self.data.farms, ","))
--     end
-- }

function InfoGatherer.new()
    local self = {}
    setmetatable(self, InfoGatherer_mt)

    self.gatherers = {
        [INFO_KEYS.FARMLANDS] = FarmlandGatherer.new(),
        [INFO_KEYS.FARMS] = FarmGatherer.new(),
    }

    return self
end

function InfoGatherer:loadFromXMLFile(xmlFile)
    if not g_currentMission:getIsServer() then return end

    local key = RedTape.SaveKey .. ".infoGatherer"

    for infoKey, gatherer in pairs(self.gatherers) do
        local gathererKey = key .. ".gatherers"
        if gatherer.loadFromXMLFile ~= nil then
            gatherer:loadFromXMLFile(xmlFile, gathererKey)
        end
    end
end

function InfoGatherer:saveToXmlFile(xmlFile)
    if (not g_currentMission:getIsServer()) then return end

    local key = RedTape.SaveKey .. ".infoGatherer"

    for _, gatherer in self.gatherers do
        gatherer:saveToXmlFile(xmlFile, key .. ".gatherers")
    end
end

function InfoGatherer:runConstantChecks()
    self.gatherers[INFO_KEYS.FARMS]:checkSprayers()
end

function InfoGatherer:runInfrequentChecks()
    self.gatherers[INFO_KEYS.FARMLANDS]:checkHarvestedState()
end

function InfoGatherer:hourChanged()
    for _, gatherer in pairs(self.gatherers) do
        gatherer:hourChanged()
    end
end

function InfoGatherer:periodChanged()
    for _, gatherer in pairs(self.gatherers) do
        gatherer:periodChanged()
    end
end

function InfoGatherer:resetMonthlyData()
    for _, gatherer in pairs(self.gatherers) do
        gatherer:resetMonthlyData()
    end
end
