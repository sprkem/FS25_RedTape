FarmGatherer = {}
FarmGatherer_mt = Class(FarmGatherer)

function FarmGatherer.new()
    local self = {}
    setmetatable(self, FarmGatherer_mt)

    self.data = {}

    self.knownCreeks = {}
    self.turnedOnSprayers = {}
    self.sprayCoords = {}

    return self
end

function FarmGatherer:hourChanged()
    local husbandryData = self:getHusbandryStats()

    for husbandry, stats in pairs(husbandryData) do
        local farmId = husbandry:getOwnerFarmId()
        local farmData = self:getFarmData(farmId)

        if stats.slurry and stats.slurry > 0 and stats.slurry == stats.slurryCapacity then
            farmData.monthlyFullSlurryCount = farmData.monthlyFullSlurryCount + 1
        end

        local isFencelessPasture = false
        if husbandry.customEnvironment ~= nil and husbandry.customEnvironment == 'FS25_FencelessPastures' then
            isFencelessPasture = true
        end

        if stats.numAnimals and stats.numAnimals > 0 then
            if stats.straw and stats.straw == 0 and not isFencelessPasture then
                farmData.monthlyEmptyStrawCount = farmData.monthlyEmptyStrawCount + 1
            end

            if stats.totalFood and stats.totalFood == 0 then
                farmData.monthlyEmptyFoodCount = farmData.monthlyEmptyFoodCount + 1
            end

            if stats.productivity and stats.productivity < 0.40 then
                farmData.monthlyLowProductivityHusbandry = farmData.monthlyLowProductivityHusbandry + 1
            end

            if stats.meadowFood > 0 and stats.totalFood == stats.meadowFood then
                farmData.monthlyAnimalGrazingHours = farmData.monthlyAnimalGrazingHours + stats.numAnimals
            end

            local desiredSpacePerAnimal = self:getDesirableSpace(stats.animalType)
            local actualSpacePerAnimal = stats.navigableArea / stats.numAnimals

            if actualSpacePerAnimal < desiredSpacePerAnimal then
                farmData.monthlyAnimalSpaceViolations = farmData.monthlyAnimalSpaceViolations + 1
            end
        end
    end
end

function FarmGatherer:periodChanged()
    self:updateManureLevels()

    local cumulativeMonth = RedTape.getCumulativeMonth()
    local oldestHistoryMonth = cumulativeMonth - 24

    -- remove spray history entries older than 24 months
    for _, farmData in pairs(self.data) do
        for month, _ in pairs(farmData.sprayHistory) do
            if month < oldestHistoryMonth then
                farmData.sprayHistory[month] = nil
            end
        end
    end
    
end

function FarmGatherer:resetMonthlyData()
    for _, farmData in pairs(self.data) do
        farmData.monthlySprayViolations = 0
        farmData.monthlyEmptyStrawCount = 0
        farmData.monthlyFullSlurryCount = 0
        farmData.monthlyEmptyFoodCount = 0
        farmData.monthlyLowProductivityHusbandry = 0
        farmData.monthlyAnimalSpaceViolations = 0
        farmData.monthlyRestrictedSlurryViolations = 0
        farmData.monthlyAnimalGrazingHours = 0
    end
end

function FarmGatherer:getFarmData(farmId)
    if self.data[farmId] == nil then
        self.data[farmId] = {
            monthlySprayViolations = 0,
            monthlyEmptyStrawCount = 0,
            monthlyFullSlurryCount = 0,
            monthlyEmptyFoodCount = 0,
            monthlyLowProductivityHusbandry = 0,
            monthlyAnimalSpaceViolations = 0,
            monthlyRestrictedSlurryViolations = 0,
            currentManureLevel = 0,
            rollingAverageManureLevel = 0,
            monthlyAnimalGrazingHours = 0,
            sprayHistory = {}
        }
    end
    return self.data[farmId]
end

function FarmGatherer:saveToXmlFile(xmlFile, key)
    local i = 0
    for farmId, farmData in pairs(self.data) do
        local farmKey = string.format("%s.farms.farm(%d)", key, i)
        setXMLInt(xmlFile, farmKey .. "#id", farmId)
        setXMLInt(xmlFile, farmKey .. "#monthlySprayViolations", farmData.monthlySprayViolations)
        setXMLInt(xmlFile, farmKey .. "#monthlyEmptyStrawCount", farmData.monthlyEmptyStrawCount)
        setXMLInt(xmlFile, farmKey .. "#monthlyFullSlurryCount", farmData.monthlyFullSlurryCount)
        setXMLInt(xmlFile, farmKey .. "#monthlyEmptyFoodCount", farmData.monthlyEmptyFoodCount)
        setXMLInt(xmlFile, farmKey .. "#monthlyLowProductivityHusbandry", farmData.monthlyLowProductivityHusbandry)
        setXMLInt(xmlFile, farmKey .. "#monthlyAnimalSpaceViolations", farmData.monthlyAnimalSpaceViolations)
        setXMLInt(xmlFile, farmKey .. "#currentManureLevel", farmData.currentManureLevel)
        setXMLInt(xmlFile, farmKey .. "#rollingAverageManureLevel", farmData.rollingAverageManureLevel)
        setXMLInt(xmlFile, farmKey .. "#monthlyRestrictedSlurryViolations", farmData.monthlyRestrictedSlurryViolations)
        setXMLInt(xmlFile, farmKey .. "#monthlyAnimalGrazingHours", farmData.monthlyAnimalGrazingHours)


        local j = 0
        for month, nameTable in pairs(farmData.sprayHistory) do
            for name, amount in pairs(nameTable) do
            local sprayKey = string.format("%s.sprayHistory.spray(%d)", farmKey, j)
            setXMLInt(xmlFile, sprayKey .. "#month", month)
            setXMLString(xmlFile, sprayKey .. "#name", name)
            setXMLInt(xmlFile, sprayKey .. "#amount", amount)
            j = j + 1
            end
        end

        i = i + 1
    end
end

function FarmGatherer:loadFromXMLFile(xmlFile, key)
    local i = 0
    while true do
        local farmKey = string.format("%s.farms.farm(%d)", key, i)
        if not hasXMLProperty(xmlFile, farmKey) then
            break
        end

        local farmId = getXMLInt(xmlFile, farmKey .. "#id")
        self.data[farmId] = {
            monthlySprayViolations = getXMLInt(xmlFile, farmKey .. "#monthlySprayViolations") or 0,
            monthlyEmptyStrawCount = getXMLInt(xmlFile, farmKey .. "#monthlyEmptyStrawCount") or 0,
            monthlyFullSlurryCount = getXMLInt(xmlFile, farmKey .. "#monthlyFullSlurryCount") or 0,
            monthlyEmptyFoodCount = getXMLInt(xmlFile, farmKey .. "#monthlyEmptyFoodCount") or 0,
            monthlyLowProductivityHusbandry = getXMLInt(xmlFile, farmKey .. "#monthlyLowProductivityHusbandry") or 0,
            monthlyAnimalSpaceViolations = getXMLInt(xmlFile, farmKey .. "#monthlyAnimalSpaceViolations") or 0,
            currentManureLevel = getXMLInt(xmlFile, farmKey .. "#currentManureLevel") or 0,
            rollingAverageManureLevel = getXMLInt(xmlFile, farmKey .. "#rollingAverageManureLevel") or 0,
            monthlyRestrictedSlurryViolations = getXMLInt(xmlFile, farmKey .. "#monthlyRestrictedSlurryViolations") or 0,
            monthlyAnimalGrazingHours = getXMLInt(xmlFile, farmKey .. "#monthlyAnimalGrazingHours") or 0
        }

        local j = 0
        self.data[farmId].sprayHistory = {}
        while true do
            local sprayKey = string.format("%s.sprayHistory.spray(%d)", farmKey, j)
            if not hasXMLProperty(xmlFile, sprayKey) then
                break
            end

            local month = getXMLInt(xmlFile, sprayKey .. "#month")
            local name = getXMLString(xmlFile, sprayKey .. "#name")
            local amount = getXMLInt(xmlFile, sprayKey .. "#amount")

            if self.data[farmId].sprayHistory[month] == nil then
                self.data[farmId].sprayHistory[month] = {}
            end
            self.data[farmId].sprayHistory[month][name] = amount

            j = j + 1
        end

        i = i + 1
    end
end

function FarmGatherer:storeSprayAreaCoords(uniqueId, coords)
    self.sprayCoords[uniqueId] = coords
end

function FarmGatherer:checkSprayers()
    local checkFillTypes = { FillType.FERTILIZER, FillType.LIQUIDMANURE, FillType.LIME, FillType.MANURE, FillType.HERBICIDE }
    local restrictedSlurryMonths = { 9, 10, 11, 12 } -- September to December

    for uniqueId, sprayer in pairs(self.turnedOnSprayers) do
        local sprayerFarmId = sprayer:getOwnerFarmId()
        local farmData = self:getFarmData(sprayerFarmId)

        if not sprayer.spec_sprayer.workAreaParameters.isActive then
            print("Sprayer " .. uniqueId .. " is not active, skipping.")
            continue
        end

        local fillUnitIndex = sprayer:getSprayerFillUnitIndex()
        local fillType = sprayer:getFillUnitFillType(fillUnitIndex)
        local currentMonth = RedTape.periodToMonth(g_currentMission.environment.currentPeriod)

        if RedTape.tableHasValue(restrictedSlurryMonths, currentMonth) and fillType == FillType.LIQUIDMANURE then
            farmData.monthlyRestrictedSlurryViolations = farmData.monthlyRestrictedSlurryViolations + 1
        end

        if RedTape.tableHasValue(checkFillTypes, fillType) then
            local usageScale = sprayer.spec_sprayer.usageScale
            local workingWidth
            if usageScale.workAreaIndex == nil then
                workingWidth = usageScale.workingWidth
            else
                workingWidth = sprayer:getWorkAreaWidth(usageScale.workAreaIndex)
            end

            local raycastHit = self:checkWaterByRaycast(sprayer, workingWidth)
            local overlapHit = self:checkCreekByOverlap(sprayer, workingWidth)

            if raycastHit or overlapHit then
                print("Water found for sprayer " .. sprayer:getName())
                farmData.monthlySprayViolations = farmData.monthlySprayViolations + 1
            else
                print("No water found for sprayer " .. sprayer:getName())
            end
        end
    end
end

function FarmGatherer:sprayerDistanceCheck(coords, hitX, hitZ)
    if coords == nil then return false end

    local distanceAllowance = 14
    for _, coord in ipairs(coords) do
        local actualDistance = MathUtil.vector2Length(coord.x - hitX, coord.z - hitZ)
        if actualDistance < distanceAllowance then
            return true
        end
    end
    return false
end

function FarmGatherer:checkWaterByRaycast(sprayer, workingWidth)
    local length = 40
    local coords = self.sprayCoords[sprayer.uniqueId]
    if coords == nil then return false end
    local ig = self
    local raycastResult = {
        raycastCallback = function(self, hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex, shapeId, isLast)
            local mask = getCollisionFilterGroup(hitObjectId)
            if mask == CollisionFlag.WATER then
                if ig:sprayerDistanceCheck(coords, x, z) then
                    self.foundWater = true
                end
            end
        end
    }

    local rayStartX, rayStartY, rayStartZ = localToWorld(sprayer.rootNode, 0, 4.25, -(sprayer.size.length * 0.5))
    local xAngles = { -2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2 }
    local yAngles = { -0.3, -0.4, -0.5, -0.6, -0.7, -0.8, -0.9, -1 }

    for _, yAngle in ipairs(yAngles) do
        for _, xAngle in ipairs(xAngles) do
            local dx, dy, dz = localDirectionToWorld(sprayer.rootNode, xAngle, yAngle, -1)
            -- drawDebugArrow(rayStartX, rayStartY, rayStartZ, dx * length, dy * length, dz * length, 0.3, 0.3, 0.3, 0.8, 0,
            --     0, true)
            raycastClosest(rayStartX, rayStartY, rayStartZ, dx, dy, dz, length, "raycastCallback", raycastResult,
                CollisionFlag.WATER + CollisionFlag.TERRAIN)
        end
    end

    if raycastResult.foundWater then
        return true
    end
    return false
end

function FarmGatherer:checkCreekByOverlap(sprayer, workingWidth)
    local widthExcess = 3
    local ig = self
    local coords = self.sprayCoords[sprayer.uniqueId]
    local overlapResult = {
        overlapCallback = function(self, hitObjectId, x, y, z, distance)
            local originalHitObjectId = hitObjectId
            if not entityExists(hitObjectId) then
                ig.knownCreeks[originalHitObjectId] = nil
                return
            end

            local isCreek = false

            if ig.knownCreeks[originalHitObjectId] ~= nil then
                print("Detected known creek " .. originalHitObjectId)
                isCreek = true
            end

            if not isCreek then
                local name = getName(hitObjectId)
                if string.find(name, "creek") then
                    isCreek = true
                    self.knownCreeks[originalHitObjectId] = true
                end
            end

            if not isCreek then
                local maxTraverse = 3
                for i = 1, maxTraverse, 1 do
                    hitObjectId = getParent(hitObjectId)
                    local name = getName(hitObjectId)
                    if string.find(name, "creek") then
                        isCreek = true
                        ig.knownCreeks[originalHitObjectId] = true
                    end
                end
            end

            if isCreek then
                if ig:sprayerDistanceCheck(coords, x, z) then
                    self.foundWater = true
                end
            end
        end
    }

    local sizeX, sizeY, sizeZ = (workingWidth * 0.5) + widthExcess, 10, 6
    local x, y, z = localToWorld(sprayer.rootNode, 0, sprayer.size.height * 0.5, -sizeZ - (sprayer.size.length * 0.5))
    local rx, ry, rz = getWorldRotation(sprayer.rootNode)
    local dx, dy, dz = localDirectionToWorld(sprayer.rootNode, 0, 0, 0)
    overlapBox(x + dx, y + dy, z + dz, rx, ry, rz, sizeX, sizeY, sizeZ, "overlapCallback",
        overlapResult, CollisionFlag.STATIC_OBJECT, true, true, true, true)

    -- DebugUtil.drawOverlapBox(x + dx, y + dy, z + dz, rx, ry, rz, sizeX, sizeY, sizeZ)

    if overlapResult.foundWater then
        return true
    end
    return false
end

function FarmGatherer:getHusbandryStats()
    local rt = g_currentMission.RedTape
    local fillTypeCache = rt:getFillTypeCache()

    local results = {}
    local husbandries = g_currentMission.husbandrySystem.placeables
    for _, husbandry in pairs(husbandries) do
        if husbandry.isDeleted or husbandry.isDeleting then
            continue
        end
        local stats = {}

        local foodSpec = husbandry.spec_husbandryFood
        local meadowSpec = husbandry.spec_husbandryMeadow
        local animalSpec = husbandry.spec_husbandryAnimals
        local animalType = foodSpec.animalTypeIndex
        local totalFood = 0

        stats.navigableArea = getNavMeshSurfaceArea(animalSpec.navigationMesh)
        stats.animalType = animalType

        if meadowSpec ~= nil then
            totalFood = meadowSpec.info.value
            stats.meadowFood = meadowSpec.info.value
        end

        local food = g_currentMission.animalFoodSystem:getAnimalFood(animalType)
        for _, foodGroup in pairs(food.groups) do
            local groupTotal = 0
            for _, fillType in pairs(foodGroup.fillTypes) do
                groupTotal = groupTotal + foodSpec.fillLevels[fillType]
            end
            totalFood = totalFood + groupTotal
        end
        stats.totalFood = totalFood

        local conditionInfos = husbandry:getConditionInfos()
        for i, conditionInfo in pairs(conditionInfos) do
            if i == 1 then
                stats.productivity = conditionInfo.value
            end
            local conditionFillType = fillTypeCache[conditionInfo.title]
            if conditionFillType == FillType.STRAW then
                stats.straw = conditionInfo.value
            elseif conditionFillType == FillType.LIQUIDMANURE then
                stats.slurry = conditionInfo.value
                stats.slurryCapacity = husbandry:getHusbandryCapacity(conditionFillType)
            end
        end

        local numAnimals = 0
        local clusters = husbandry:getClusters()
        for _, cluster in pairs(clusters) do
            numAnimals = numAnimals + cluster:getNumAnimals()
        end
        stats.numAnimals = numAnimals

        results[husbandry] = stats
    end
    return results
end

function FarmGatherer:getDesirableSpace(animalType)
    if animalType == AnimalType.CHICKEN then
        return 1
    elseif animalType == AnimalType.COW then
        return 12
    elseif animalType == AnimalType.HORSE then
        return 17
    elseif animalType == AnimalType.PIG then
        return 7
    elseif animalType == AnimalType.SHEEP then
        return 9
    end
end

function FarmGatherer:updateManureLevels()
    for _, farmData in pairs(self.data) do
        farmData.currentManureLevel = 0
    end

    local placeables = g_currentMission.placeableSystem.placeables
    for _, placeable in pairs(placeables) do
        if placeable.spec_manureHeap ~= nil then
            for fillTypeIndex, fillLevel in pairs(placeable.spec_manureHeap.manureHeap.fillLevels) do
                if fillTypeIndex ~= FillType.MANURE then
                    continue
                end
                if fillLevel > 0 and fillTypeIndex ~= nil then
                    local farmData = self:getFarmData(placeable:getOwnerFarmId())
                    farmData.currentManureLevel = farmData.currentManureLevel + fillLevel
                end
            end
        end

        if placeable.spec_husbandry ~= nil and placeable.spec_husbandry.storage ~= nil then
            for fillTypeIndex, fillLevel in pairs(placeable.spec_husbandry.storage.fillLevels) do
                if fillTypeIndex ~= FillType.MANURE then
                    continue
                end
                if fillLevel > 0 and fillTypeIndex ~= nil then
                    local farmData = self:getFarmData(placeable:getOwnerFarmId())
                    farmData.currentManureLevel = farmData.currentManureLevel + fillLevel
                end
            end
        end
    end

    local averagingWindow = 6
    for _, farmData in pairs(self.data) do
        local oldAverage = farmData.rollingAverageManureLevel
        farmData.rollingAverageManureLevel = (oldAverage * (averagingWindow - 1) + farmData.currentManureLevel) /
            averagingWindow
    end
end
