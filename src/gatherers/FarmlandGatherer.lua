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

function FarmlandGatherer:resetBiAnnualData()
end

function FarmlandGatherer:getFarmlandData(farmlandId)
    if self.data[farmlandId] == nil then
        self.data[farmlandId] = {
            fallowMonths = 0,
            areaHa = 0,
            lastGrassHarvest = -1,
            monthlyWrappedBales = 0,
            fruitHistory = {},
            isHarvested = false,
            harvestedCropsHistory = {},
            rotationExceptions = 0
        }
    end
    return self.data[farmlandId]
end

function FarmlandGatherer:saveToXmlFile(xmlFile, key)
    local farmlandGathererKey = string.format("%s.farmlandGatherer", key)

    local i = 0
    for farmlandId, farmlandData in pairs(self.data) do
        local farmlandKey = string.format("%s.farmlands.farmland(%d)", farmlandGathererKey, i)
        setXMLInt(xmlFile, farmlandKey .. "#id", farmlandId)
        setXMLInt(xmlFile, farmlandKey .. "#fallowMonths", farmlandData.fallowMonths)
        setXMLInt(xmlFile, farmlandKey .. "#areaHa", farmlandData.areaHa)
        setXMLInt(xmlFile, farmlandKey .. "#lastGrassHarvest", farmlandData.lastGrassHarvest)
        setXMLInt(xmlFile, farmlandKey .. "#monthlyWrappedBales", farmlandData.monthlyWrappedBales)
        setXMLBool(xmlFile, farmlandKey .. "#isHarvested", farmlandData.isHarvested)
        setXMLInt(xmlFile, farmlandKey .. "#rotationExceptions", farmlandData.rotationExceptions)

        local j = 0
        for month, fruitEntry in pairs(farmlandData.fruitHistory) do
            local fruitKey = string.format("%s.fruitHistory.fruit(%d)", farmlandKey, j)
            setXMLInt(xmlFile, fruitKey .. "#month", month)
            setXMLString(xmlFile, fruitKey .. "#name", fruitEntry.name)
            setXMLInt(xmlFile, fruitKey .. "#growthState", fruitEntry.growthState)
            j = j + 1
        end

        local k = 0
        for _, harvestEntry in pairs(farmlandData.harvestedCropsHistory) do
            local harvestKey = string.format("%s.harvestedCropsHistory.harvest(%d)", farmlandKey, k)
            setXMLString(xmlFile, harvestKey .. "#name", harvestEntry.name)
            setXMLInt(xmlFile, harvestKey .. "#month", harvestEntry.month)
            k = k + 1
        end

        i = i + 1
    end
end

function FarmlandGatherer:loadFromXMLFile(xmlFile, key)
    local farmlandGathererKey = string.format("%s.farmlandGatherer", key)

    local i = 0
    while true do
        local farmlandKey = string.format("%s.farmlands.farmland(%d)", farmlandGathererKey, i)
        if not hasXMLProperty(xmlFile, farmlandKey) then
            break
        end

        local farmlandId = getXMLInt(xmlFile, farmlandKey .. "#id")
        self.data[farmlandId] = {
            fallowMonths = getXMLInt(xmlFile, farmlandKey .. "#fallowMonths") or 0,
            areaHa = getXMLInt(xmlFile, farmlandKey .. "#areaHa") or 0,
            lastGrassHarvest = getXMLInt(xmlFile, farmlandKey .. "#lastGrassHarvest") or
                getXMLInt(xmlFile, farmlandKey .. "#lastHarvestMonth") or 0,
            monthlyWrappedBales = getXMLInt(xmlFile, farmlandKey .. "#monthlyWrappedBales") or 0,
            isHarvested = getXMLBool(xmlFile, farmlandKey .. "#isHarvested") or false,
            rotationExceptions = getXMLInt(xmlFile, farmlandKey .. "#rotationExceptions") or 0,
            harvestedCropsHistory = {}
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

        local k = 0
        while true do
            local harvestKey = string.format("%s.harvestedCropsHistory.harvest(%d)", farmlandKey, k)
            if not hasXMLProperty(xmlFile, harvestKey) then
                break
            end

            local harvestEntry = {
                name = getXMLString(xmlFile, harvestKey .. "#name"),
                month = getXMLInt(xmlFile, harvestKey .. "#month")
            }
            table.insert(self.data[farmlandId].harvestedCropsHistory, harvestEntry)

            k = k + 1
        end

        i = i + 1
    end
    self:buildHarvestHistory()
end

function FarmlandGatherer:buildHarvestHistory()
    -- First check if any farmland already has valid harvest history loaded
    local hasExistingHistory = false
    for _, farmlandData in pairs(self.data) do
        if #farmlandData.harvestedCropsHistory > 0 then
            hasExistingHistory = true
            break
        end
    end

    -- If we have existing harvest history, exit early
    if hasExistingHistory then
        return
    end

    local currentMonth = RedTape.getCumulativeMonth()

    for farmlandId, farmlandData in pairs(self.data) do
        if farmlandData.fruitHistory then
            local sortedMonths = {}
            for month, _ in pairs(farmlandData.fruitHistory) do
                table.insert(sortedMonths, month)
            end
            table.sort(sortedMonths)

            local lastHarvestedCropName = nil
            local lastCropName = nil

            for _, month in ipairs(sortedMonths) do
                local fruitEntry = farmlandData.fruitHistory[month]

                if fruitEntry and fruitEntry.name and fruitEntry.name ~= "" then
                    local fruit = g_fruitTypeManager.nameToFruitType[fruitEntry.name]

                    if fruit then
                        if month == currentMonth then
                            continue
                        end

                        local isHarvestable = (fruitEntry.growthState == fruit.cutState) or
                            (fruitEntry.growthState >= fruit.minHarvestingGrowthState and
                                fruitEntry.growthState <= fruit.maxHarvestingGrowthState)

                        if lastCropName == fruitEntry.name and fruitEntry.growthState < fruit.minHarvestingGrowthState then
                            lastHarvestedCropName = nil
                        end

                        if isHarvestable and lastHarvestedCropName ~= fruitEntry.name then
                            local harvestEntry = {
                                name = fruitEntry.name,
                                month = month
                            }

                            table.insert(farmlandData.harvestedCropsHistory, 1, harvestEntry)

                            while #farmlandData.harvestedCropsHistory > 5 do
                                table.remove(farmlandData.harvestedCropsHistory)
                            end

                            lastHarvestedCropName = fruitEntry.name
                        end

                        lastCropName = fruitEntry.name
                    end
                end
            end
        end
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
                farmlandData.isHarvested = false
            else
                local wasHarvested = farmlandData.isHarvested
                farmlandData.isHarvested = (growthState == currentFruit.cutState)

                if farmlandData.isHarvested and not wasHarvested then
                    g_client:getServerConnection():sendEvent(RTHarvestHistoryUpdateEvent.new(farmland.id,
                        currentFruit.name, RedTape.getCumulativeMonth()))
                end

                if currentFruit and fruitTypeIndexPos == FruitType.GRASS and growthState == currentFruit.cutState then
                    farmlandData.lastGrassHarvest = RedTape.getCumulativeMonth()
                end
            end
        end
    end
end

-- Forwards search to see if any fruit recorded in the given range
function FarmlandGatherer:hasRecordedFruit(farmlandId, startMonth, endMonth, ignoreHarvestedOrWithered)
    local farmlandData = self:getFarmlandData(farmlandId)
    for month = startMonth, endMonth do
        local fruitEntry = farmlandData.fruitHistory[month]

        if fruitEntry ~= nil then
            local fruit = g_fruitTypeManager.nameToFruitType[fruitEntry.name]

            if ignoreHarvestedOrWithered and fruitEntry.growthState > fruit.maxHarvestingGrowthState then
                continue
            end

            if fruitEntry.name ~= "" then
                return true
            end
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

function FarmlandGatherer:addRotationException(farmlandId, count)
    local farmlandData = self:getFarmlandData(farmlandId)
    farmlandData.rotationExceptions = farmlandData.rotationExceptions + count
end

function FarmlandGatherer:setRotationException(farmlandId, count)
    local farmlandData = self:getFarmlandData(farmlandId)
    farmlandData.rotationExceptions =  count
end

-- Add any data required on clients
function FarmlandGatherer:writeInitialClientState(streamId, connection)
    -- Write the number of farmlands with harvest history data
    local farmlandCount = 0
    for farmlandId, farmlandData in pairs(self.data) do
        if #farmlandData.harvestedCropsHistory > 0 then
            farmlandCount = farmlandCount + 1
        end
    end

    streamWriteInt32(streamId, farmlandCount)

    -- Write each farmland's harvest history
    for farmlandId, farmlandData in pairs(self.data) do
        if #farmlandData.harvestedCropsHistory > 0 then
            streamWriteInt32(streamId, farmlandId)
            streamWriteInt32(streamId, #farmlandData.harvestedCropsHistory)

            for _, harvestEntry in ipairs(farmlandData.harvestedCropsHistory) do
                streamWriteString(streamId, harvestEntry.name)
                streamWriteInt32(streamId, harvestEntry.month)
            end
        end
    end
end

-- Add any data required on clients
function FarmlandGatherer:readInitialClientState(streamId, connection)
    -- Read the number of farmlands with harvest history data
    local farmlandCount = streamReadInt32(streamId)

    -- Read each farmland's harvest history
    for i = 1, farmlandCount do
        local farmlandId = streamReadInt32(streamId)
        local historyCount = streamReadInt32(streamId)

        local farmlandData = self:getFarmlandData(farmlandId)
        farmlandData.harvestedCropsHistory = {}

        for j = 1, historyCount do
            local harvestEntry = {
                name = streamReadString(streamId),
                month = streamReadInt32(streamId)
            }
            table.insert(farmlandData.harvestedCropsHistory, harvestEntry)
        end
    end
end
