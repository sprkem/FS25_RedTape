RTDischargeableExtension = {}

function RTDischargeableExtension:dischargeToGround(superFunc, dischargeNode, emptyLiters)
    local dischargedLiters, minDropReached, hasMinDropFillLevel = superFunc(self, dischargeNode, emptyLiters)

    if not self.isServer or dischargedLiters == 0 then
        return dischargedLiters, minDropReached, hasMinDropFillLevel
    end

    local fillType = self:getDischargeFillType(dischargeNode)
    if fillType ~= FillType.MANURE then
        return dischargedLiters, minDropReached, hasMinDropFillLevel
    end

    local info = dischargeNode.info
    local sx, _, sz = localToWorld(info.node, -info.width, 0, info.zOffset)
    local ex, _, ez = localToWorld(info.node, info.width, 0, info.zOffset)
    local centerX = (sx + ex) / 2
    local centerZ = (sz + ez) / 2

    local rt = g_currentMission.RedTape
    if rt == nil then
        return dischargedLiters, minDropReached, hasMinDropFillLevel
    end

    local gatherer = rt.InfoGatherer.gatherers[INFO_KEYS.FARMS]
    local gridX, _, gridZ = RedTape.getGridPosition(centerX, 0, centerZ, 10)
    local cellKey = string.format("%d_%d", gridX, gridZ)
    gatherer.manureCells[cellKey] = true

    return dischargedLiters, minDropReached, hasMinDropFillLevel
end

Dischargeable.dischargeToGround = Utils.overwrittenFunction(
    Dischargeable.dischargeToGround,
    RTDischargeableExtension.dischargeToGround)
