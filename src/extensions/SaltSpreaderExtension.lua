RTSaltSpreaderExtension = {}

function RTSaltSpreaderExtension:processSaltSpreaderArea(superFunc, workArea)
    if self.isServer then
        local rt = g_currentMission.RedTape
        local snowOnGround = rt.InfoGatherer.gatherers[INFO_KEYS.FARMS].snowOnGround
        local farmId = self:getOwnerFarmId()

        if not snowOnGround then
            return superFunc(self, workArea)
        end

        local isActiveForScheme = g_currentMission.RedTape.SchemeSystem:isSchemeActiveForFarm(farmId,
            RTSchemeIds.ROAD_SNOW_CLEARING)

        local x, y, z = getWorldTranslation(self.rootNode)
        local maxKMH = RTSchemes[RTSchemeIds.ROAD_SNOW_CLEARING].maxKMH
        local kmhSpeed = self:getLastSpeed()
        if kmhSpeed > maxKMH then
            if isActiveForScheme then
                local message = string.format(g_i18n:getText("rt_misc_spreading_too_fast"),
                    string.format("%1d", g_i18n:getSpeed(maxKMH)), g_i18n:getSpeedMeasuringUnit())
                g_currentMission:showBlinkingWarning(message, 1000)
            end
            return superFunc(self, workArea)
        end

        for _, spline in pairs(g_currentMission.aiSystem.roadSplines) do
            local splineX, splineY, splineZ = getClosestSplinePosition(spline, x, y, z, 0.5)
            local distance = MathUtil.vector3Length(x - splineX, y - splineY, z - splineZ)

            if distance < 2 then
                local gridX, gridY, gridZ = RedTape.getGridPosition(splineX, splineY, splineZ, 10)
                local farmGatherer = g_currentMission.RedTape.InfoGatherer.gatherers[INFO_KEYS.FARMS]
                farmGatherer:recordSaltSpread(gridX, gridY, gridZ, spline, farmId)
            end
        end
    end
    return superFunc(self, workArea)
end

SaltSpreader.processSaltSpreaderArea = Utils.overwrittenFunction(SaltSpreader.processSaltSpreaderArea,
    RTSaltSpreaderExtension.processSaltSpreaderArea)
