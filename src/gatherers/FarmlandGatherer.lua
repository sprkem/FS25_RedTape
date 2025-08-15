FarmlandGatherer = {}
FarmlandGatherer_mt = Class(FarmlandGatherer)

function FarmlandGatherer.new()
    local self = {}
    setmetatable(self, FarmlandGatherer_mt)

    self.data = {}

    return self
end

function FarmlandGatherer:gather()
    print("Gathering farmlands data...")
    for _, farmland in pairs(g_farmlandManager.farmlands) do
        if farmland.showOnFarmlandsScreen and farmland.field ~= nil then
            local farmlandData = self:getFarmlandData(farmland.id)
            local field = farmland.field
            local x, z = field:getCenterOfFieldWorldPosition()
            local fruitTypeIndexPos, growthState = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(x, z)
            local currentFruit = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndexPos)

            if currentFruit == nil then
                farmlandData.fallowMonths = farmlandData.fallowMonths + 1
                if farmlandData.mostRecentFruit ~= nil then
                    farmlandData.previousFruit = farmlandData.mostRecentFruit
                end
                farmlandData.mostRecentFruit = nil
            else
                farmlandData.fallowMonths = 0

                -- if there is a fruit and it different from the previous one, update it
                if farmlandData.mostRecentFruit ~= nil and farmlandData.mostRecentFruit ~= fruitTypeIndexPos then
                    farmlandData.previousFruit = farmlandData.mostRecentFruit
                end
                farmlandData.mostRecentFruit = fruitTypeIndexPos
            end
            farmlandData.areaHa = field:getAreaHa()
        end
    end
end

function FarmlandGatherer:getFarmlandData(farmlandId)
    if self.data[farmlandId] == nil then
        self.data[farmlandId] = {
            fallowMonths = 0,
            mostRecentFruit = nil,
            previousFruit = nil,
            areaHa = 0
        }
    end
    return self.data[farmlandId]
end

function FarmlandGatherer:saveToXmlFile(xmlFile, key)
    local i = 0
    for farmlandId, farmlandData in pairs(self.data) do
        local farmlandKey = string.format("%s.farmlands.farmland(%d)", key, i)
        setXMLInt(xmlFile, farmlandKey .. "#id", farmlandId)
        setXMLInt(xmlFile, farmlandKey .. "#fallowMonths", farmlandData.fallowMonths)
        setXMLInt(xmlFile, farmlandKey .. "#mostRecentFruit", farmlandData.mostRecentFruit)
        setXMLInt(xmlFile, farmlandKey .. "#previousFruit", farmlandData.previousFruit)
        setXMLInt(xmlFile, farmlandKey .. "#areaHa", farmlandData.areaHa)
        i = i + 1
    end
end

function FarmlandGatherer:loadFromXMLFile(xmlFile, key)
    local i = 0
    while true do
        local farmlandKey = string.format("%s.farmlands.farmland(%d)", key, i)
        if not hasXMLProperty(xmlFile, farmlandKey) then
            break
        end

        local farmlandId = getXMLInt(xmlFile, farmlandKey .. "#id")
        self.data[farmlandId] = {
            fallowMonths = getXMLInt(xmlFile, farmlandKey .. "#fallowMonths"),
            mostRecentFruit = getXMLInt(xmlFile, farmlandKey .. "#mostRecentFruit"),
            previousFruit = getXMLInt(xmlFile, farmlandKey .. "#previousFruit"),
            areaHa = getXMLInt(xmlFile, farmlandKey .. "#areaHa")
        }
        i = i + 1
    end
end
