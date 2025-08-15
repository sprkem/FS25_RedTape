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

function FarmGatherer:gather()

end

function FarmGatherer:getFarmData(farmId)
    if self.data[farmId] == nil then
        self.data[farmId] = {
            pendingSprayViolations = 0,
            sprayViolationsInCurrentPolicyWindow = 0,
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
        setXMLInt(xmlFile, farmKey .. "#sprayViolationsInCurrentPolicyWindow", farmData.sprayViolationsInCurrentPolicyWindow)
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
            sprayViolationsInCurrentPolicyWindow = getXMLInt(xmlFile, farmKey .. "#sprayViolationsInCurrentPolicyWindow"),
        }
        i = i + 1
    end
end

function FarmGatherer:storeSprayAreaCoords(uniqueId, coords)
    self.sprayCoords[uniqueId] = coords
end

function FarmGatherer:checkSprayers()
    local checkFillTypes = { FillType.FERTILIZER }

    for uniqueId, sprayer in pairs(self.turnedOnSprayers) do
        if not sprayer.spec_sprayer.workAreaParameters.isActive then
            print("Sprayer " .. uniqueId .. " is not active, skipping.")
            continue
        end

        local fillUnitIndex = sprayer:getSprayerFillUnitIndex()
        local fillType = sprayer:getFillUnitFillType(fillUnitIndex)

        if not RedTape:tableHasValue(checkFillTypes, fillType) then
            print("Ignoring sprayer fill type " .. fillType)
            continue
        end

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
            local farmId = 1
            local farmData = self:getFarmData(farmId)
            farmData.pendingSprayViolations = farmData.pendingSprayViolations + 1
        else
            print("No water found for sprayer " .. sprayer:getName())
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
