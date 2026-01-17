RTAnimalMoveEventExtension = {}

function RTAnimalMoveEventExtension:run(connection)
    if self.targetObject == nil then return end

    local ig = g_currentMission.RedTape.InfoGatherer
    local gatherer = ig.gatherers[INFO_KEYS.FARMS]
    gatherer:addProductivityException(self.targetObject, 24)
end

AnimalMoveEvent.run = Utils.appendedFunction(AnimalMoveEvent.run,
    RTAnimalMoveEventExtension.run)
