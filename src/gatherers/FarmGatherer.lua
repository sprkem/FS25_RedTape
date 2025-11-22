FarmGatherer = {}
FarmGatherer_mt = Class(FarmGatherer)

function FarmGatherer.new()
    local self = {}
    setmetatable(self, FarmGatherer_mt)

    self.data = {}

    self.knownCreeks = {}
    self.turnedOnSprayers = {}
    self.sprayCoords = {}
    self.productivityExceptions = {}
    self.snowOnGround = false
    self.saltData = {}

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

            if not self:isExemptFromProductivityCheck(husbandry) then
                if stats.productivity and stats.productivity < 0.40 then
                    farmData.monthlyLowProductivityHusbandry = farmData.monthlyLowProductivityHusbandry + 1
                end
            end

            if stats.meadowFood and stats.meadowFood > 0 and stats.totalFood == stats.meadowFood then
                farmData.monthlyAnimalGrazingHours = farmData.monthlyAnimalGrazingHours + stats.numAnimals
                farmData.monthlyScaledAnimalGrazingHours = farmData.monthlyScaledAnimalGrazingHours +
                    (stats.numAnimals * self:getAnimalGrazingScaleFactor(stats.animalType))
            end

            local desiredSpacePerAnimal = self:getDesirableSpace(stats.animalType)
            local actualSpacePerAnimal = stats.navigableArea / stats.numAnimals
            self:updateMinAnimalSpacing(husbandry, actualSpacePerAnimal, desiredSpacePerAnimal)

            if stats.numAnimals > 1 and actualSpacePerAnimal < desiredSpacePerAnimal then
                farmData.monthlyAnimalSpaceViolations = farmData.monthlyAnimalSpaceViolations + 1
            end
        end
    end

    for uniqueId, exceptionHours in pairs(self.productivityExceptions) do
        exceptionHours = exceptionHours - 1
        if exceptionHours <= 0 then
            self.productivityExceptions[uniqueId] = nil
        else
            self.productivityExceptions[uniqueId] = exceptionHours
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
        farmData.monthlyScaledAnimalGrazingHours = 0
        farmData.monthlyDetail = {}
    end
end

function FarmGatherer:resetBiAnnualData()
    for _, farmData in pairs(self.data) do
        farmData.biAnnualCutTrees = 0
        farmData.biAnnualPlantedTrees = 0
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
            monthlyScaledAnimalGrazingHours = 0,
            biAnnualCutTrees = 0,
            biAnnualPlantedTrees = 0,
            sprayHistory = {},
            monthlyDetail = {},
            saltCount = 0
        }
    end
    return self.data[farmId]
end

function FarmGatherer:saveToXmlFile(xmlFile, key)
    local farmGathererKey = string.format("%s.farmGatherer", key)
    setXMLBool(xmlFile, farmGathererKey .. "#snowOnGround", self.snowOnGround)

    local y = 0
    for uniqueId, hours in pairs(self.productivityExceptions) do
        local exceptionKey = string.format("%s.productivityExceptions.exception(%d)", farmGathererKey, y)
        setXMLString(xmlFile, exceptionKey .. "#uniqueId", uniqueId)
        setXMLInt(xmlFile, exceptionKey .. "#hours", hours)
        y = y + 1
    end

    local x = 0
    for spline, keys in pairs(self.saltData) do
        for storeKey, _ in pairs(keys) do
            local saltKey = string.format("%s.saltData.spline(%d)", farmGathererKey, x)
            setXMLInt(xmlFile, saltKey .. "#id", spline)
            setXMLString(xmlFile, saltKey .. "#key", storeKey)
            x = x + 1
        end
    end

    local i = 0
    for farmId, farmData in pairs(self.data) do
        local farmKey = string.format("%s.farms.farm(%d)", farmGathererKey, i)
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
        setXMLInt(xmlFile, farmKey .. "#monthlyScaledAnimalGrazingHours", farmData.monthlyScaledAnimalGrazingHours)
        setXMLInt(xmlFile, farmKey .. "#biAnnualCutTrees", farmData.biAnnualCutTrees)
        setXMLInt(xmlFile, farmKey .. "#biAnnualPlantedTrees", farmData.biAnnualPlantedTrees)
        setXMLInt(xmlFile, farmKey .. "#saltCount", farmData.saltCount)

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

        local k = 0
        for detailKey, detailTable in pairs(farmData.monthlyDetail) do
            local detailXmlKey = string.format("%s.monthlyDetail.detail(%d)", farmKey, k)
            setXMLString(xmlFile, detailXmlKey .. "#key", detailKey)

            local l = 0
            for _, detailLine in pairs(detailTable) do
                local lineKey = string.format("%s.line(%d)", detailXmlKey, l)
                setXMLString(xmlFile, lineKey .. "#k", detailLine.key)
                setXMLString(xmlFile, lineKey .. "#v1", detailLine.value1 or "")
                setXMLString(xmlFile, lineKey .. "#v2", detailLine.value2 or "")
                setXMLInt(xmlFile, lineKey .. "#updated", detailLine.updated or -1)
                l = l + 1
            end

            k = k + 1
        end

        i = i + 1
    end
end

function FarmGatherer:loadFromXMLFile(xmlFile, key)
    local farmGathererKey = string.format("%s.farmGatherer", key)
    self.snowOnGround = getXMLBool(xmlFile, farmGathererKey .. "#snowOnGround") or false

    local x = 0
    while true do
        local exceptionKey = string.format("%s.productivityExceptions.exception(%d)", farmGathererKey, x)
        if not hasXMLProperty(xmlFile, exceptionKey) then
            break
        end

        local uniqueId = getXMLString(xmlFile, exceptionKey .. "#uniqueId")
        local hours = getXMLInt(xmlFile, exceptionKey .. "#hours")
        self.productivityExceptions[uniqueId] = hours

        x = x + 1
    end

    local y = 0
    while true do
        local saltKey = string.format("%s.saltData.spline(%d)", farmGathererKey, y)
        if not hasXMLProperty(xmlFile, saltKey) then
            break
        end

        local spline = getXMLInt(xmlFile, saltKey .. "#id")
        local entryKey = getXMLString(xmlFile, saltKey .. "#key")
        if self.saltData[spline] == nil then
            self.saltData[spline] = {}
        end
        self.saltData[spline][entryKey] = true

        y = y + 1
    end

    local i = 0
    while true do
        local farmKey = string.format("%s.farms.farm(%d)", farmGathererKey, i)
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
            monthlyAnimalGrazingHours = getXMLInt(xmlFile, farmKey .. "#monthlyAnimalGrazingHours") or 0,
            monthlyScaledAnimalGrazingHours = getXMLInt(xmlFile, farmKey .. "#monthlyScaledAnimalGrazingHours") or 0,
            biAnnualCutTrees = getXMLInt(xmlFile, farmKey .. "#biAnnualCutTrees") or 0,
            biAnnualPlantedTrees = getXMLInt(xmlFile, farmKey .. "#biAnnualPlantedTrees") or 0,
            saltCount = getXMLInt(xmlFile, farmKey .. "#saltCount") or 0,
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

        local k = 0
        self.data[farmId].monthlyDetail = {}
        while true do
            local detailXmlKey = string.format("%s.monthlyDetail.detail(%d)", farmKey, k)
            if not hasXMLProperty(xmlFile, detailXmlKey) then
                break
            end

            local detailKey = getXMLString(xmlFile, detailXmlKey .. "#key")
            self.data[farmId].monthlyDetail[detailKey] = {}

            local l = 0
            while true do
                local lineKey = string.format("%s.line(%d)", detailXmlKey, l)
                if not hasXMLProperty(xmlFile, lineKey) then
                    break
                end

                table.insert(self.data[farmId].monthlyDetail[detailKey], {
                    key = getXMLString(xmlFile, lineKey .. "#k"),
                    value1 = getXMLString(xmlFile, lineKey .. "#v1"),
                    value2 = getXMLString(xmlFile, lineKey .. "#v2"),
                    updated = getXMLInt(xmlFile, lineKey .. "#updated") or -1
                })

                l = l + 1
            end

            k = k + 1
        end

        i = i + 1
    end
end

function FarmGatherer:storeSprayAreaCoords(uniqueId, coords)
    self.sprayCoords[uniqueId] = coords
end

function FarmGatherer:checkSprayers()
    local checkFillTypes = { FillType.FERTILIZER, FillType.LIQUIDMANURE, FillType.LIME, FillType.MANURE, FillType
        .HERBICIDE }
    local restrictedSlurryMonths = { 9, 10, 11, 12 } -- September to December

    for uniqueId, sprayer in pairs(self.turnedOnSprayers) do
        local sprayerFarmId = sprayer:getOwnerFarmId()
        local farmData = self:getFarmData(sprayerFarmId)

        if not sprayer.spec_sprayer.workAreaParameters.isActive then
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
                farmData.monthlySprayViolations = farmData.monthlySprayViolations + 1
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
    local ig = self
    local overlapResult = {
        overlapCallback = function(self, hitObjectId, x, y, z, distance)
            local originalHitObjectId = hitObjectId
            if not entityExists(hitObjectId) then
                ig.knownCreeks[originalHitObjectId] = nil
                return
            end

            local isCreek = false

            if ig.knownCreeks[originalHitObjectId] ~= nil then
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
                self.foundWater = true
            end
        end
    }

    local coords = self.sprayCoords[sprayer.uniqueId]
    local sizeX, sizeY, sizeZ = 2, 2, 2
    for _, coord in ipairs(coords) do
        overlapBox(coord.x, coord.y, coord.z, 0, 0, 0, sizeX, sizeY, sizeZ, "overlapCallback",
            overlapResult, CollisionFlag.STATIC_OBJECT, true, true, true, true)
        -- DebugUtil.drawOverlapBox(coord.x, coord.y, coord.z, 0, 0, 0, sizeX, sizeY, sizeZ)
    end

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

function FarmGatherer:getAnimalGrazingScaleFactor(animalType)
    if animalType == AnimalType.CHICKEN then
        return 0.2
    elseif animalType == AnimalType.COW then
        return 1.0
    elseif animalType == AnimalType.HORSE then
        return 0.3
    elseif animalType == AnimalType.PIG then
        return 0.5
    elseif animalType == AnimalType.SHEEP then
        return 0.6
    end
    return 1.0
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

function FarmGatherer:updateMinAnimalSpacing(husbandry, actual, desired)
    local farmId = husbandry:getOwnerFarmId()
    local husbandryName = husbandry:getName()
    local farmData = self:getFarmData(farmId)
    local cumulativeMonth = RedTape.getCumulativeMonth()
    if farmData.monthlyDetail["animalSpace"] == nil then
        farmData.monthlyDetail["animalSpace"] = {}
    end

    local formattedActual = string.format("%.2f", actual)
    for _, entry in pairs(farmData.monthlyDetail["animalSpace"]) do
        if entry.key == husbandryName then
            if entry.value1 == nil or actual < tonumber(entry.value1) then
                entry.value1 = formattedActual
                entry.value2 = tostring(desired)
            end
            entry.updated = cumulativeMonth
            return
        end
    end
    table.insert(farmData.monthlyDetail["animalSpace"], {
        key = husbandryName,
        value1 = formattedActual,
        value2 = tostring(desired),
        updated = cumulativeMonth
    })
end

function FarmGatherer:addProductivityException(husbandry, hours)
    self.productivityExceptions[husbandry.uniqueId] = hours
end

function FarmGatherer:isExemptFromProductivityCheck(husbandry)
    return self.productivityExceptions[husbandry.uniqueId] ~= nil
end

function FarmGatherer:recordSaltSpread(x, y, z, spline, farmId)
    if not self.snowOnGround then
        return
    end

    if self.saltData[spline] == nil then
        self.saltData[spline] = {}
    end

    local key = string.format("%d_%d_%d", math.floor(x), math.floor(y), math.floor(z))
    if not self.saltData[spline][key] then
        local farmData = self:getFarmData(farmId)
        farmData.saltCount = (farmData.saltCount or 0) + 1
        self.saltData[spline][key] = true
    end
end

function FarmGatherer:onSnowApplied()
    self.snowOnGround = true
    for _, farmData in pairs(self.data) do
        farmData.saltCount = 0
    end
    self.saltData = {}
end

function FarmGatherer:onSnowEnded()
    self.snowOnGround = false
    for _, farmData in pairs(self.data) do
        farmData.saltCount = 0
    end
    self.saltData = {}
end
