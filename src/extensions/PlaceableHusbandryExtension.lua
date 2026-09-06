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

--- Speeds up how fast a husbandry recovers its productivity, controlled by the
--- productivityRecovery setting. The base game logic (and anything else hooked into
--- the hour tick, such as Realistic Livestock, which does all of its feeding and
--- production work there) always runs first, and only the resulting increase in
--- globalProductionFactor is scaled. Never reimplement the tick here: skipping
--- superFunc stops other mods' animals eating and producing entirely.
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
    local before = spec.globalProductionFactor
    local result = superFunc(self, currentHour)
    local delta = spec.globalProductionFactor - before

    if multiplier == 0 then
        -- Instant: set globalProductionFactor to 1 so displayed productivity
        -- (globalProductionFactor * productionFactor) matches the current food level
        spec.globalProductionFactor = 1
    elseif delta > 0 then
        -- Apply the multiplier only to the increase, decreases keep base game behaviour.
        -- The output for this hour has already been produced with the pre-boost factor,
        -- so the boost takes effect from the next hour on.
        spec.globalProductionFactor = math.clamp(before + delta * multiplier, 0, 1)
    end

    if spec.globalProductionFactor ~= before + delta then
        self:raiseDirtyFlags(spec.dirtyFlag)
    end

    return result
end

PlaceableHusbandry.onHourChanged = Utils.overwrittenFunction(
    PlaceableHusbandry.onHourChanged,
    RTPlaceableHusbandryExtension.onHourChanged)
