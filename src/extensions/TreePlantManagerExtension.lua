RTTreePlantManagerExtension = {}

function RTTreePlantManagerExtension:plantTree(superFunc, treeTypeIndex, x, y, z, rx, ry, rz, growthStateI,
                                               variationIndex,
                                               isGrowing, nextGrowthTargetHour, existingSplitShapeFileId)
    local rt = g_currentMission.RedTape

    if g_currentMission:getIsServer() and rt.missionStarted then
        local farmland = g_farmlandManager:getFarmlandAtWorldPosition(x, z)
        if farmland ~= nil then
            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMS]

            local farmData = gatherer:getFarmData(farmland.farmId)
            farmData.biAnnualPlantedTrees = farmData.biAnnualPlantedTrees + 1
        end
    end

    return superFunc(self, treeTypeIndex, x, y, z, rx, ry, rz, growthStateI, variationIndex,
        isGrowing, nextGrowthTargetHour, existingSplitShapeFileId)
end

TreePlantManager.plantTree = Utils.overwrittenFunction(TreePlantManager.plantTree,
    RTTreePlantManagerExtension.plantTree)
