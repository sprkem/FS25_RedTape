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
            farmData.pendingFullSlurryCount = farmData.pendingFullSlurryCount + 1
        end

        if stats.numAnimals and stats.numAnimals > 0 then
            if stats.straw and stats.straw == 0 then
                farmData.pendingEmptyStrawCount = farmData.pendingEmptyStrawCount + 1
            end

            if stats.totalFood and stats.totalFood == 0 then
                farmData.pendingEmptyFoodCount = farmData.pendingEmptyFoodCount + 1
            end

            if stats.productivity and stats.productivity < 70 then
                farmData.pendingLowProductivityHusbandry = farmData.pendingLowProductivityHusbandry + 1
            end

            local desiredSpacePerAnimal = self:getDesirableSpace(stats.animalType)
            local actualSpacePerAnimal = stats.navigableArea / stats.numAnimals

            if actualSpacePerAnimal < desiredSpacePerAnimal then
                farmData.pendingAnimalSpaceViolations = farmData.pendingAnimalSpaceViolations + 1
            end
        end
    end
end

function FarmGatherer:periodChanged()
    self:updateManureLevels()
end

function FarmGatherer:getFarmData(farmId)
    if self.data[farmId] == nil then
        self.data[farmId] = {
            pendingSprayViolations = 0,
            pendingEmptyStrawCount = 0,
            pendingFullSlurryCount = 0,
            pendingEmptyFoodCount = 0,
            pendingLowProductivityHusbandry = 0,
            pendingAnimalSpaceViolations = 0,
            currentManureLevel = 0,
            rollingAverageManureLevel = 0,
            pendingManureSpread = 0,
            restrictedSlurryViolations = 0
        }
    end
    return self.data[farmId]
end

function FarmGatherer:saveToXmlFile(xmlFile, key)
    local i = 0
    for farmId, farmData in pairs(self.data) do
        local farmKey = string.format("%s.farms.farm(%d)", key, i)
        setXMLInt(xmlFile, farmKey .. "#id", farmId)
        setXMLInt(xmlFile, farmKey .. "#pendingSprayViolations", farmData.pendingSprayViolations)
        setXMLInt(xmlFile, farmKey .. "#pendingEmptyStrawCount", farmData.pendingEmptyStrawCount)
        setXMLInt(xmlFile, farmKey .. "#pendingFullSlurryCount", farmData.pendingFullSlurryCount)
        setXMLInt(xmlFile, farmKey .. "#pendingEmptyFoodCount", farmData.pendingEmptyFoodCount)
        setXMLInt(xmlFile, farmKey .. "#pendingLowProductivityHusbandry", farmData.pendingLowProductivityHusbandry)
        setXMLInt(xmlFile, farmKey .. "#pendingAnimalSpaceViolations", farmData.pendingAnimalSpaceViolations)
        setXMLInt(xmlFile, farmKey .. "#currentManureLevel", farmData.currentManureLevel)
        setXMLInt(xmlFile, farmKey .. "#rollingAverageManureLevel", farmData.rollingAverageManureLevel)
        setXMLInt(xmlFile, farmKey .. "#pendingManureSpread", farmData.pendingManureSpread)
        setXMLInt(xmlFile, farmKey .. "#restrictedSlurryViolations", farmData.restrictedSlurryViolations)
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
            pendingSprayViolations = getXMLInt(xmlFile, farmKey .. "#pendingSprayViolations"),
            pendingEmptyStrawCount = getXMLInt(xmlFile, farmKey .. "#pendingEmptyStrawCount"),
            pendingFullSlurryCount = getXMLInt(xmlFile, farmKey .. "#pendingFullSlurryCount"),
            pendingEmptyFoodCount = getXMLInt(xmlFile, farmKey .. "#pendingEmptyFoodCount"),
            pendingLowProductivityHusbandry = getXMLInt(xmlFile, farmKey .. "#pendingLowProductivityHusbandry"),
            pendingAnimalSpaceViolations = getXMLInt(xmlFile, farmKey .. "#pendingAnimalSpaceViolations"),
            currentManureLevel = getXMLInt(xmlFile, farmKey .. "#currentManureLevel"),
            rollingAverageManureLevel = getXMLInt(xmlFile, farmKey .. "#rollingAverageManureLevel"),
            pendingManureSpread = getXMLInt(xmlFile, farmKey .. "#pendingManureSpread"),
            restrictedSlurryViolations = getXMLInt(xmlFile, farmKey .. "#restrictedSlurryViolations")
        }
        i = i + 1
    end
end

function FarmGatherer:storeSprayAreaCoords(uniqueId, coords)
    self.sprayCoords[uniqueId] = coords
end

function FarmGatherer:checkSprayers()
    local checkFillTypes = { FillType.FERTILIZER, FillType.SLURRY, FillType.LIME, FillType.MANURE }
    local restrictedSlurryPeriods = { 11, 12, 1, 2 } -- September to December

    for uniqueId, sprayer in pairs(self.turnedOnSprayers) do
        local sprayerFarmId = sprayer:getOwnerFarmId()
        local farmData = self:getFarmData(sprayerFarmId)

        if not sprayer.spec_sprayer.workAreaParameters.isActive then
            print("Sprayer " .. uniqueId .. " is not active, skipping.")
            continue
        end

        local fillUnitIndex = sprayer:getSprayerFillUnitIndex()
        local fillType = sprayer:getFillUnitFillType(fillUnitIndex)

        if RedTape.tableHasValue(restrictedSlurryPeriods, g_currentMission.environment.currentPeriod) and fillType == FillType.SLURRY then
            print("Slurry spraying is restricted during this period. Sprayer " ..
                sprayer:getName() .. " is violating policy.")
            farmData.restrictedSlurryViolations = farmData.restrictedSlurryViolations + 1
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
                farmData.pendingSprayViolations = farmData.pendingSprayViolations + 1
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
            drawDebugArrow(rayStartX, rayStartY, rayStartZ, dx * length, dy * length, dz * length, 0.3, 0.3, 0.3, 0.8, 0,
                0, true)
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

    DebugUtil.drawOverlapBox(x + dx, y + dy, z + dz, rx, ry, rz, sizeX, sizeY, sizeZ)

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
            elseif conditionFillType == FillType.SLURRY then
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
