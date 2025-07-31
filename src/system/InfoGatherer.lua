InfoGatherer = {}
InfoGatherer_mt = Class(InfoGatherer)

InfoGatherer.RETENTION_YEARS = 5

INFO_KEYS = {
    FARMLANDS = "farmlands",
}

function InfoGatherer.new()
    local self = {}
    setmetatable(self, InfoGatherer_mt)

    self.data = self:initData()
    self.turnedOnSprayers = {}

    return self
end

function InfoGatherer:runConstantChecks()
    print("Running constant checks...")
    self:checkSprayers()
end

function InfoGatherer:checkSprayers()
    local checkFillTypes = { FillType.FERTILIZER }
    for uniqueId, sprayer in pairs(self.turnedOnSprayers) do
        local sprayType = sprayer:getActiveSprayType()
        if sprayType == nil then
            continue
        end

        local fillUnitIndex = sprayer:getSprayerFillUnitIndex()
        local fillType = sprayer:getFillUnitFillType(fillUnitIndex)

        if not RedTape:tableHasValue(checkFillTypes, fillType) then
            continue
        end

        local workingWidth = sprayer:getWorkAreaWidth(sprayer.spec_sprayer.usageScale.workingWidth)

        print(workingWidth)
        print(fillType)

        -- sprayType.usageScale.workingWidth
    end
end

function InfoGatherer:initData()
    local data = {}
    for _, value in pairs(INFO_KEYS) do
        data[value] = {}
    end
    return data
end

function InfoGatherer:getPreviousPeriod()
    local previousPeriod = g_currentMission.environment.currentPeriod - 1
    if previousPeriod < 1 then return 12 end
    return previousPeriod
end

function InfoGatherer:gatherData()
    print("Gathering data for policies...")
    local currentMonth = RedTape.periodToMonth(g_currentMission.environment.currentPeriod)
    --self:stubCurrentMonth(data, g_currentMission.environment.currentYear, currentMonth)

    self:getFarmlands()


    -- self:removeOldData(data)
    return
end

-- function InfoGatherer:removeOldData(data)
--     local currentYear = g_currentMission.environment.currentYear

--     for _, value in pairs(INFO_KEYS) do
--         for year, _ in pairs(data[value]) do
--             if year < currentYear - InfoGatherer.RETENTION_YEARS then
--                 data[value][year] = nil
--             end
--         end
--     end
-- end

-- function InfoGatherer:stubCurrentMonth(data, year, month)
--     for _, value in pairs(INFO_KEYS) do
--         if data[value][year] == nil then
--             data[value][year] = {}
--         end
--         if data[value][year][month] == nil then
--             data[value][year][month] = {}
--         end
--     end
-- end

function InfoGatherer:getFarmlands()
    print("Gathering farmlands data...")
    for _, farmland in pairs(g_farmlandManager.farmlands) do
        if farmland.showOnFarmlandsScreen and farmland.field ~= nil then
            if self.data[INFO_KEYS.FARMLANDS][farmland.id] == nil then
                self.data[INFO_KEYS.FARMLANDS][farmland.id] = { fallowMonths = 0 }
            end

            local farmlandData = self.data[INFO_KEYS.FARMLANDS][farmland.id]

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

    return data
end
