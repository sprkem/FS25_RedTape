RTFarmlandExtension = {}

function RTFarmlandExtension:setOwnerFarmId(farmId)
    if not g_currentMission.RedTape.missionStarted then
        return
    end

    if g_currentMission:getIsServer() and self.isOwned then
        local infoGatherer = g_currentMission.RedTape.InfoGatherer
        local farmlandGatherer = infoGatherer.gatherers[INFO_KEYS.FARMLANDS]
        farmlandGatherer:setRotationException(self.id, 1)
    end
end

Farmland.setOwnerFarmId = Utils.appendedFunction(Farmland.setOwnerFarmId,
    RTFarmlandExtension.setOwnerFarmId)
