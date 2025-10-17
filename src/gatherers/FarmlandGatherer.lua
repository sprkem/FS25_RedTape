FarmlandGatherer = {}
FarmlandGatherer_mt = Class(FarmlandGatherer)

function FarmlandGatherer.new()
    local self = {}
    setmetatable(self, FarmlandGatherer_mt)

    self.data = {}

    return self
end

function FarmlandGatherer:hourChanged()
end

function FarmlandGatherer:periodChanged()
    print("Gathering farmlands data...")
    local cumulativeMonth = RedTape.getCumulativeMonth()
    local oldestHistoryMonth = cumulativeMonth - 24
    for _, farmland in pairs(g_farmlandManager.farmlands) do
        if farmland.showOnFarmlandsScreen and farmland.field ~= nil then
            local farmlandData = self:getFarmlandData(farmland.id)

            local field = farmland.field
            local x, z = field:getCenterOfFieldWorldPosition()
            local fruitTypeIndex, growthState = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(x, z)
            local currentFruit = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)

            if currentFruit == nil then
                farmlandData.fallowMonths = farmlandData.fallowMonths + 1
            else
                farmlandData.fallowMonths = 0
                farmlandData.fruitHistory[cumulativeMonth] = {
                    name = currentFruit.name or "",
                    growthState = growthState
                }
            end
            farmlandData.areaHa = field:getAreaHa()

            -- remove history entries older than 24 months
            for month, _ in pairs(farmlandData.fruitHistory) do
                if month < oldestHistoryMonth then
                    farmlandData.fruitHistory[month] = nil
                end
            end
        end
    end
end

function FarmlandGatherer:resetMonthlyData()
    for _, farmlandData in pairs(self.data) do
        farmlandData.monthlyWrappedBales = 0
    end
end

function FarmlandGatherer:getFarmlandData(farmlandId)
    if self.data[farmlandId] == nil then
        self.data[farmlandId] = {
            fallowMonths = 0,
            areaHa = 0,
            lastHarvestMonth = -1,
            monthlyWrappedBales = 0,
            fruitHistory = {}
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
        setXMLInt(xmlFile, farmlandKey .. "#areaHa", farmlandData.areaHa)
        setXMLInt(xmlFile, farmlandKey .. "#lastHarvestMonth", farmlandData.lastHarvestMonth)
        setXMLInt(xmlFile, farmlandKey .. "#monthlyWrappedBales", farmlandData.monthlyWrappedBales)

        local j = 0
        for month, fruitEntry in pairs(farmlandData.fruitHistory) do
            local fruitKey = string.format("%s.fruitHistory.fruit(%d)", farmlandKey, j)
            setXMLInt(xmlFile, fruitKey .. "#month", month)
            setXMLString(xmlFile, fruitKey .. "#name", fruitEntry.name)
            setXMLInt(xmlFile, fruitKey .. "#growthState", fruitEntry.growthState)
            j = j + 1
        end

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
            fallowMonths = getXMLInt(xmlFile, farmlandKey .. "#fallowMonths") or 0,
            areaHa = getXMLInt(xmlFile, farmlandKey .. "#areaHa") or 0,
            lastHarvestMonth = getXMLInt(xmlFile, farmlandKey .. "#lastHarvestMonth") or 0,
            monthlyWrappedBales = getXMLInt(xmlFile, farmlandKey .. "#monthlyWrappedBales") or 0,
        }

        local j = 0
        self.data[farmlandId].fruitHistory = {}
        while true do
            local fruitKey = string.format("%s.fruitHistory.fruit(%d)", farmlandKey, j)
            if not hasXMLProperty(xmlFile, fruitKey) then
                break
            end

            local month = getXMLInt(xmlFile, fruitKey .. "#month")

            self.data[farmlandId].fruitHistory[month] = {
                name = getXMLString(xmlFile, fruitKey .. "#name"),
                growthState = getXMLInt(xmlFile, fruitKey .. "#growthState")
            }

            j = j + 1
        end

        i = i + 1
    end
end

function FarmlandGatherer:checkHarvestedState()
    for _, farmland in pairs(g_farmlandManager.farmlands) do
        if farmland.showOnFarmlandsScreen and farmland.field ~= nil then
            local farmlandData = self:getFarmlandData(farmland.id)
            local field = farmland.field
            local x, z = field:getCenterOfFieldWorldPosition()
            local fruitTypeIndexPos, growthState = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(x, z)
            local currentFruit = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndexPos)

            if currentFruit == nil then
                continue
            end

            if currentFruit and growthState == currentFruit.cutState then
                farmlandData.lastHarvestMonth = RedTape.getCumulativeMonth()
            end
        end
    end
end

-- Finds a previous fruit with a backwards search
function FarmlandGatherer:getPreviousFruit(farmlandId, startMonth, endMonth, notFruit)
    local farmlandData = self:getFarmlandData(farmlandId)
    for month = startMonth, endMonth, -1 do
        local fruitEntry = farmlandData.fruitHistory[month]
        if fruitEntry ~= nil and fruitEntry.name ~= "" then
            if notFruit == nil or fruitEntry.name ~= notFruit then
                return fruitEntry.name, month
            end
        end
    end
    return nil, nil
end

-- Forwards search to see if any fruit recorded in the given range
function FarmlandGatherer:hasRecordedFruit(farmlandId, startMonth, endMonth)
    local farmlandData = self:getFarmlandData(farmlandId)
    for month = startMonth, endMonth do
        local fruitEntry = farmlandData.fruitHistory[month]
        if fruitEntry ~= nil and fruitEntry.name ~= "" then
            return true
        end
    end
    return false
end

function FarmlandGatherer:wasFruitHarvestable(farmlandId, startMonth, endMonth, fruitType)
    local fruit = g_fruitTypeManager:getFruitTypeByIndex(fruitType)
    if fruit == nil then
        return false
    end
    local farmlandData = self:getFarmlandData(farmlandId)
    for month = startMonth, endMonth do
        local fruitEntry = farmlandData.fruitHistory[month]
        if fruitEntry ~= nil and fruitEntry.name == fruit.name then
            if fruitEntry.growthState >= fruit.minHarvestingGrowthState then
                return true
            end
        end
    end
    return false
end
