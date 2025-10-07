MissionManagerExtension = {}
function MissionManagerExtension:getIsMissionWorkAllowed(superFunc, farmId, x, z, workAreaType, vehicle)
    if g_currentMission.RedTape.SchemeSystem:getIsSchemeVehicle(farmId, vehicle) then
        local farmland = g_farmlandManager:getFarmlandAtWorldPosition(x, z)
        if farmland ~= nil and farmland.farmId == farmId then
            return true
        end
    end

    return superFunc(self, farmId, x, z, workAreaType, vehicle)
end

MissionManager.getIsMissionWorkAllowed = Utils.overwrittenFunction(MissionManager.getIsMissionWorkAllowed,
    MissionManagerExtension.getIsMissionWorkAllowed)
