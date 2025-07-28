InfoGatherer = {}
InfoGatherer_mt = Class(InfoGatherer)

InfoGatherer.RETENTION_YEARS = 5

INFO_KEYS = {
    FARMLANDS = "farmlands",
}

function InfoGatherer.new()
    local self = {}
    setmetatable(self, InfoGatherer_mt)
    return self
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

function InfoGatherer:gatherData(data)
    print("Gathering data for policies...")
    self:getFarmlands(data)


    self:removeOldData(data)
    DebugUtil.printTableRecursively(data)
    return data
end

function InfoGatherer:removeOldData(data)
    local currentYear = g_currentMission.environment.currentYear

    for _, value in pairs(INFO_KEYS) do
        for year, _ in pairs(data[value]) do
            if year < currentYear - InfoGatherer.RETENTION_YEARS then
                data[value][year] = nil
            end
        end
    end
end

function InfoGatherer:getFarmlands(data)
    print("Gathering farmlands data...")
    local currentPeriod = g_currentMission.environment.currentPeriod
    local currentYear = g_currentMission.environment.currentYear

    if data[INFO_KEYS.FARMLANDS][currentYear] == nil then
        data[INFO_KEYS.FARMLANDS][currentYear] = {}
    end

    if data[INFO_KEYS.FARMLANDS][currentYear][currentPeriod] == nil then
        data[INFO_KEYS.FARMLANDS][currentYear][currentPeriod] = {}
    end

    for _, farmland in pairs(g_farmlandManager.farmlands) do
        if farmland.showOnFarmlandsScreen and farmland.field ~= nil then
            if data[INFO_KEYS.FARMLANDS][currentYear][currentPeriod][farmland.id] == nil then
                data[INFO_KEYS.FARMLANDS][currentYear][currentPeriod][farmland.id] = {}
            end

            local farmlandData = data[INFO_KEYS.FARMLANDS][currentYear][currentPeriod][farmland.id]

            local field = farmland.field
            local x, z = field:getCenterOfFieldWorldPosition()
            local fruitTypeIndexPos, growthState = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(x, z)
            local currentFruit = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndexPos)

            if currentFruit == nil then
                print("No fruit found for farmland ID: " .. farmland.id)
                farmlandData.fruit = nil
            else
                farmlandData.fruit = currentFruit.fillType.title
            end
            farmlandData.areaHa = field:getAreaHa()
        end
    end

    return data
end
