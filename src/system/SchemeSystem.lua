SchemeSystem = {}
SchemeSystem_mt = Class(SchemeSystem)

SchemeSystem.OPEN_SCHEMES_PER_TIER = 10

table.insert(FinanceStats.statNames, "schemePayout")
FinanceStats.statNameToIndex["schemePayout"] = #FinanceStats.statNames

function SchemeSystem.new()
    local self = {}
    setmetatable(self, SchemeSystem_mt)
    self.availableSchemes = {
        [PolicySystem.TIER.A] = {},
        [PolicySystem.TIER.B] = {},
        [PolicySystem.TIER.C] = {},
        [PolicySystem.TIER.D] = {}
    }
    self.activeSchemesByFarm = {}

    MoneyType.SCHEME_PAYOUT = MoneyType.register("schemePayout", "rt_ui_schemePayout")
    MoneyType.LAST_ID = MoneyType.LAST_ID + 1

    return self
end

function SchemeSystem:loadFromXMLFile(xmlFile)
    if (not g_currentMission:getIsServer()) then return end

    local key = RedTape.SaveKey .. ".schemeSystem"

    local i = 0
    while true do
        local schemeKey = string.format(key .. ".schemes.scheme(%d)", i)
        if not hasXMLProperty(xmlFile, schemeKey) then
            break
        end

        local scheme = Scheme.new()
        scheme:loadFromXMLFile(xmlFile, schemeKey)
        local tier = getXMLInt(xmlFile, schemeKey .. "#tier")
        if self.availableSchemes[tier] == nil then
            self.availableSchemes[tier] = {}
        end
        table.insert(self.availableSchemes[tier], scheme)
        i = i + 1
    end

    local j = 0
    while true do
        local schemeKey = string.format(key .. ".activeSchemes.scheme(%d)", j)
        if not hasXMLProperty(xmlFile, schemeKey) then
            break
        end

        local scheme = Scheme.new()
        scheme:loadFromXMLFile(xmlFile, schemeKey)
        local farmId = scheme.farmId
        if self.activeSchemesByFarm[farmId] == nil then
            self.activeSchemesByFarm[farmId] = {}
        end
        table.insert(self.activeSchemesByFarm[farmId], scheme)
        j = j + 1
    end
end

function SchemeSystem:saveToXmlFile(xmlFile)
    if (not g_currentMission:getIsServer()) then return end

    local key = RedTape.SaveKey .. ".schemeSystem"

    local i = 0
    for tier, schemes in pairs(self.availableSchemes) do
        for _, scheme in pairs(schemes) do
            local schemeKey = string.format("%s.schemes.scheme(%d)", key, i)
            scheme:saveToXmlFile(xmlFile, schemeKey)
            setXMLInt(xmlFile, schemeKey .. "#tier", tier)
            i = i + 1
        end
    end

    local j = 0
    for _, schemes in pairs(self.activeSchemesByFarm) do
        for _, scheme in pairs(schemes) do
            local schemeKey = string.format("%s.activeSchemes.scheme(%d)", key, j)
            scheme:saveToXmlFile(xmlFile, schemeKey)
        end
        j = j + 1
    end
end

function SchemeSystem:hourChanged()
end

function SchemeSystem:periodChanged()
    local rt = g_currentMission.RedTape
    local schemeSystem = rt.SchemeSystem

    for farm, schemes in pairs(schemeSystem.activeSchemesByFarm) do
        for _, scheme in pairs(schemes) do
            scheme:evaluate()
        end
    end

    local currentMonth = rt.periodToMonth(g_currentMission.environment.currentPeriod)
    local expired = {}
    for tier, schemes in pairs(self.availableSchemes) do
        for _, scheme in pairs(schemes) do
            local schemeInfo = Schemes[scheme.schemeIndex]
            if schemeInfo.offerMonths ~= nil and not rt.tableHasValue(schemeInfo.offerMonths, currentMonth) then
                table.insert(expired, scheme)
            end
        end
    end

    for _, scheme in pairs(expired) do
        g_client:getServerConnection():sendEvent(SchemeNoLongerAvailableEvent.new(scheme.id))
    end

    schemeSystem:generateSchemes()
end

function SchemeSystem:checkPendingVehicles()
    for farm, schemes in pairs(self.activeSchemesByFarm) do
        for _, scheme in pairs(schemes) do
            scheme:checkPendingVehicles()
        end
    end
end

function SchemeSystem:generateSchemes()
    for tier, schemes in pairs(self.availableSchemes) do
        local existingCount = RedTape.tableCount(schemes)
        if existingCount < SchemeSystem.OPEN_SCHEMES_PER_TIER then
            local toCreate = SchemeSystem.OPEN_SCHEMES_PER_TIER - existingCount
            for i = 1, toCreate do
                local scheme = Scheme.new()
                scheme.tier = tier
                local nextIndex = self:getNextSchemeIndex(tier)

                if nextIndex == nil then
                    break
                end

                scheme.schemeIndex = nextIndex
                scheme:initialise()
                g_client:getServerConnection():sendEvent(SchemeActivatedEvent.new(scheme))
            end
        end
    end
end

function SchemeSystem:getNextSchemeIndex(tier)
    local rt = g_currentMission.RedTape
    local currentMonth = rt.periodToMonth(g_currentMission.environment.currentPeriod)
    local currentSchemeDupeKeys = {}
    for _, scheme in pairs(self.availableSchemes[tier]) do
        table.insert(currentSchemeDupeKeys, Schemes[scheme.schemeIndex].duplicationKey)
    end

    local availableSchemes = {}
    for _, schemeInfo in pairs(Schemes) do
        if rt.tableHasKey(schemeInfo.tiers, tier) and not rt.tableHasValue(currentSchemeDupeKeys, schemeInfo.duplicationKey) then
            if schemeInfo.offerMonths == nil or rt.tableHasValue(schemeInfo.offerMonths, currentMonth) then
                local availabilityProbability = schemeInfo.availabilityProbability or 1
                if math.random() <= availabilityProbability then
                    table.insert(availableSchemes, schemeInfo)
                end
            end
        end
    end

    local totalProbability = 0
    for _, scheme in pairs(availableSchemes) do
        totalProbability = totalProbability + scheme.selectionProbability
    end

    if totalProbability == 0 then
        return nil -- No available schemes to choose from
    end

    local randomValue = math.random() * totalProbability
    local cumulativeProbability = 0
    for _, scheme in pairs(availableSchemes) do
        cumulativeProbability = cumulativeProbability + scheme.selectionProbability
        if randomValue <= cumulativeProbability then
            return scheme.id
        end
    end

    return nil
end

-- Called by PolicyActivatedEvent, runs on Client and Server
function SchemeSystem:registerActivatedScheme(scheme)
    table.insert(self.availableSchemes[scheme.tier], scheme)
    local available = scheme:availableForCurrentFarm()
    g_currentMission.RedTape.EventLog:addEvent(nil, EventLogItem.EVENT_TYPE.SCHEME_ACTIVATED,
        string.format(g_i18n:getText("rt_notify_active_scheme"), scheme:getName()), available)
    g_messageCenter:publish(MessageType.SCHEMES_UPDATED)
end

-- Called by SchemeSelectedEvent, runs on Client and Server
function SchemeSystem:registerSelectedScheme(scheme, farmId)
    local activeSchemes = self:getActiveSchemesForFarm(farmId)

    local schemeForFarm = scheme:createFarmScheme(farmId)
    table.insert(activeSchemes, schemeForFarm)

    if g_currentMission:getIsServer() then
        schemeForFarm:selected()
    end

    g_messageCenter:publish(MessageType.SCHEMES_UPDATED)
end

-- Called by SchemeNoLongerAvailableEvent, runs on Client and Server
function SchemeSystem:removeAvailableScheme(id)
    for tier, schemes in pairs(self.availableSchemes) do
        for i, scheme in pairs(schemes) do
            if scheme.id == id then
                table.remove(schemes, i)
                g_messageCenter:publish(MessageType.SCHEMES_UPDATED)
                return
            end
        end
    end
end

function SchemeSystem:endActiveScheme(id, farmId)
    for i, scheme in pairs(self.activeSchemesByFarm[farmId]) do
        if scheme.id == id then
            scheme:endScheme()
            table.remove(self.activeSchemesByFarm[farmId], i)
            return
        end
    end
end

function SchemeSystem:getActiveSchemesForFarm(farmId)
    if self.activeSchemesByFarm[farmId] == nil then
        self.activeSchemesByFarm[farmId] = {}
    end

    return self.activeSchemesByFarm[farmId]
end

function SchemeSystem:getAvailableSchemesForCurrentFarm()
    local availableForFarm = {}

    local policySystem = g_currentMission.RedTape.PolicySystem
    local farmTier = policySystem:getProgressForCurrentFarm().tier
    for _, scheme in pairs(self.availableSchemes[farmTier]) do
        if scheme:availableForCurrentFarm() then
            table.insert(availableForFarm, scheme)
        end
    end

    return availableForFarm
end

function SchemeSystem:getIsSchemeVehicle(farmId, vehicle)
    local activeSchemes = self:getActiveSchemesForFarm(farmId)
    for _, scheme in pairs(activeSchemes) do
        if scheme:isSchemeVehicle(vehicle) then
            return true
        end
    end
    return false
end

-- function SchemeSystem.getAvailableEquipmentSize(variant)
--     local groups = g_missionManager.missionVehicles["harvestMission"]
--     local sizes = { "medium", "small", "large" }
--     local chosenSize = nil
--     local sized = nil

--     for _, s in ipairs(sizes) do
--         sized = groups[s]
--         if sized ~= nil then
--             for _, g in pairs(sized) do
--                 if g.variant == variant then
--                     chosenSize = s
--                     break
--                 end
--             end
--         end
--     end

--     if sized == nil then
--         print("No vehicle groups found for any size for variant " .. variant)
--         return nil
--     end

--     return chosenSize
-- end

function SchemeSystem.isSpawnSpaceAvailable(storeItems)
    local usedStorePlaces = g_currentMission.usedStorePlaces
    local placesFilled = {}
    local result = true
    for _, storeItem in ipairs(storeItems) do
        local size = StoreItemUtil.getSizeValues(storeItem.xmlFilename, "vehicle", storeItem.rotation, storeItem.configurations)
        local x = size.width
        size.width = math.max(x, VehicleLoadingData.MIN_SPAWN_PLACE_WIDTH)
        size.length = math.max(size.length, VehicleLoadingData.MIN_SPAWN_PLACE_LENGTH)
        size.height = math.max(size.height, VehicleLoadingData.MIN_SPAWN_PLACE_HEIGHT)
        size.width = size.width + VehicleLoadingData.SPAWN_WIDTH_OFFSET
        local adjustedX, _, _, place, width, _ = PlacementUtil.getPlace(g_currentMission.storeSpawnPlaces, size,
            usedStorePlaces)
        if adjustedX == nil then
            result = false
            break
        end
        PlacementUtil.markPlaceUsed(usedStorePlaces, place, width)
        table.insert(placesFilled, place)
    end
    for _, place in ipairs(placesFilled) do
        PlacementUtil.unmarkPlaceUsed(usedStorePlaces, place)
    end
    return result
end
