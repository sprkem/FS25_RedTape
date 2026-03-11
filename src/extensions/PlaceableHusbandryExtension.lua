RTPlaceableHusbandryExtension = {}

function RTPlaceableHusbandryExtension:addHusbandryFillLevelFromTool(superFunc, farmId, deltaFillLevel, fillTypeIndex,
                                                                     fillPositionData, toolType, extraAttributes)
    local qtyAdded = superFunc(self, farmId, deltaFillLevel, fillTypeIndex, fillPositionData, toolType, extraAttributes)

    if fillTypeIndex == FillType.MANURE and qtyAdded > 0 then
        local rt = g_currentMission.RedTape
        local farmData = rt.InfoGatherer.gatherers[INFO_KEYS.FARMS]:getFarmData(farmId)
        local produceHistory = farmData.produceHistory
        local cumulativeMonth = RedTape.getCumulativeMonth()
        if produceHistory[cumulativeMonth] == nil then
            produceHistory[cumulativeMonth] = {}
        end
        local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
        if produceHistory[cumulativeMonth][fillTypeName] == nil then
            produceHistory[cumulativeMonth][fillTypeName] = qtyAdded
        else
            produceHistory[cumulativeMonth][fillTypeName] = produceHistory[cumulativeMonth][fillTypeName] + qtyAdded
        end
    end

    return qtyAdded
end

PlaceableHusbandry.addHusbandryFillLevelFromTool = Utils.overwrittenFunction(
    PlaceableHusbandry.addHusbandryFillLevelFromTool,
    RTPlaceableHusbandryExtension.addHusbandryFillLevelFromTool)

function RTPlaceableHusbandryExtension:onHourChanged(superFunc, currentHour)
    if not self.isServer then
        return superFunc(self, currentHour)
    end

    local rt = g_currentMission.RedTape
    local multiplier = rt and rt.settings and rt.settings.productivityRecovery or 1

    -- 1x means no change, just run the base game logic
    if multiplier == 1 then
        return superFunc(self, currentHour)
    end

    local spec = self.spec_husbandry
    local foodFactor = self:updateFeeding()
    SpecializationUtil.raiseEvent(self, "onFinishedFeeding")
    local productionFactor = self:updateProduction(foodFactor)

    if multiplier == 0 then
        -- Instant: set globalProductionFactor to 1 so displayed productivity
        -- (globalProductionFactor * productionFactor) matches the current food level
        spec.globalProductionFactor = 1
    else
        local factor, changePerHour
        if spec.productionThreshold < productionFactor then
            factor = (productionFactor - spec.productionThreshold) / (1 - spec.productionThreshold)
            changePerHour = spec.productionChangePerHourIncrease
            -- Apply the multiplier only to the increase
            local delta = changePerHour * factor * multiplier
            spec.globalProductionFactor = math.clamp(spec.globalProductionFactor + delta, 0, 1)
        else
            -- Decreasing: no multiplier applied, use base game behavior
            factor = productionFactor / spec.productionThreshold - 1
            changePerHour = spec.productionChangePerHourDecrease
            local delta = changePerHour * factor
            spec.globalProductionFactor = math.clamp(spec.globalProductionFactor + delta, 0, 1)
        end
    end

    self:updateOutput(foodFactor, productionFactor, spec.globalProductionFactor)
    self:raiseDirtyFlags(spec.dirtyFlag)
end

PlaceableHusbandry.onHourChanged = Utils.overwrittenFunction(
    PlaceableHusbandry.onHourChanged,
    RTPlaceableHusbandryExtension.onHourChanged)
