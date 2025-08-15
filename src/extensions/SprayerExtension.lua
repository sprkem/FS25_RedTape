SprayerExtension = {}

function SprayerExtension:onTurnedOn()
    print("Sprayer turned on: " .. self:getName())
    g_currentMission.RedTape.InfoGatherer.turnedOnSprayers[self.uniqueId] = self
end

function SprayerExtension:onTurnedOff()
    print("Sprayer turned off: " .. self:getName())
    g_currentMission.RedTape.InfoGatherer.turnedOnSprayers[self.uniqueId] = nil
    g_currentMission.RedTape.InfoGatherer.sprayCoords[self.uniqueId] = nil
end

Sprayer.onTurnedOn = Utils.appendedFunction(Sprayer.onTurnedOn, SprayerExtension.onTurnedOn)
Sprayer.onTurnedOff = Utils.appendedFunction(Sprayer.onTurnedOff, SprayerExtension.onTurnedOff)

function SprayerExtension:processSprayerArea(superFunc, workArea, dt)
    local rt = g_currentMission.RedTape

    -- Gate to perform spray area calculations much less frequently
    if rt.sprayCheckTime > 0 then
        rt.sprayCheckTime = rt.sprayCheckTime - dt
        return superFunc(self, workArea, dt)
    else
        rt.sprayCheckTime = rt.sprayAreaCheckInterval
    end

    local sx, sy, sz = getWorldTranslation(workArea.start)
    local wx, wy, wz = getWorldTranslation(workArea.width)
    local hx, hy, hz = getWorldTranslation(workArea.height)

    local widthVecX, widthVecY, widthVecZ = wx - sx, wy - sy, wz - sz
    local heightVecX, heightVecY, heightVecZ = hx - sx, hy - sy, hz - sz

    local widthLength = MathUtil.vector3Length(widthVecX, widthVecY, widthVecZ)
    local heightLength = MathUtil.vector3Length(heightVecX, heightVecY, heightVecZ)

    local cellSize = 1
    local coords = {}

    -- Sample points in a grid over the work area
    for w = 0, widthLength, cellSize do
        for h = 0, heightLength, cellSize do
            local x = sx + (widthVecX / widthLength) * w + (heightVecX / heightLength) * h
            local y = sy + (widthVecY / widthLength) * w + (heightVecY / heightLength) * h
            local z = sz + (widthVecZ / widthLength) * w + (heightVecZ / heightLength) * h
            table.insert(coords, { x = x, y = y, z = z })
        end
    end

    rt.InfoGatherer.gatherers[INFO_KEYS.FARMS]:storeSprayAreaCoords(self.uniqueId, coords)

    return superFunc(self, workArea, dt)
end

Sprayer.processSprayerArea = Utils.overwrittenFunction(Sprayer.processSprayerArea, SprayerExtension.processSprayerArea)
