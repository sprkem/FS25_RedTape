RTBaleWrapperExtension = {}

function RTBaleWrapperExtension:doStateChange(id, nearestBaleServerId)
    if self.isServer then
        local spec = self.spec_baleWrapper
        if id == BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE then
            local baleType = spec.currentWrapper.allowedBaleTypes[spec.currentBaleTypeIndex]
            local bale = NetworkUtil.getObject(spec.currentWrapper.currentBale)
            local skippedWrapping = not bale:getSupportsWrapping() or baleType.skipWrapping
            if not skippedWrapping then
                local x, y, z = getWorldTranslation(bale.nodeId)
                local farmland = g_farmlandManager:getFarmlandAtWorldPosition(x, z)
                if farmland ~= nil then
                    local ig = g_currentMission.RedTape.InfoGatherer
                    local gatherer = ig.gatherers[INFO_KEYS.FARMLANDS]
                    local farmlandData = gatherer:getFarmlandData(farmland.id)
                    farmlandData.monthlyWrappedBales = farmlandData.monthlyWrappedBales + 1
                end
            end
        end
    end
end

BaleWrapper.doStateChange = Utils.appendedFunction(BaleWrapper.doStateChange, RTBaleWrapperExtension.doStateChange)
