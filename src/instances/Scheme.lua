Scheme = {}
Scheme_mt = Class(Scheme)


function Scheme.new()
    local self = {}
    setmetatable(self, Scheme_mt)

    self.id = RedTape.generateId()
    self.schemeIndex = -1

    -- if -1, the scheme is open for selection by farms
    self.farmId = -1

    -- Set when a farm chooses a scheme
    self.activatedTier = -1

    self.lastEvaluationReport = {}

    self.props = {}

    self.spawnedVehicles = false
    self.vehicles = {}
    self.pendingVehicleLoadingData = {} -- temp, not to be saved
    self.failedToLoadVehicles = false   -- temp, not to be saved

    return self
end

function Scheme:update(dt)
    if self.pendingVehicleUniqueIds ~= nil then
        for i = #self.pendingVehicleUniqueIds, 1, -1 do
            local uniqueId = self.pendingVehicleUniqueIds[i]
            local vehicle = g_currentMission.vehicleSystem:getVehicleByUniqueId(uniqueId)
            if vehicle ~= nil then
                table.remove(self.pendingVehicleUniqueIds, i)
                table.insert(self.vehicles, vehicle)
            end
        end
        if #self.pendingVehicleUniqueIds == 0 then
            self.pendingVehicleUniqueIds = nil
        end
    end
end

function Scheme:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
    streamWriteInt32(streamId, self.schemeIndex)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.activatedTier)
    streamWriteBool(streamId, self.spawnedVehicles)

    streamWriteInt32(streamId, #self.lastEvaluationReport)
    for i, report in ipairs(self.lastEvaluationReport) do
        streamWriteString(streamId, report.cell1)
        streamWriteString(streamId, report.cell2)
        streamWriteString(streamId, report.cell3)
    end

    streamWriteInt32(streamId, #self.props)
    for key, value in pairs(self.props) do
        streamWriteString(streamId, key)
        streamWriteString(streamId, value)
    end
end

function Scheme:readStream(streamId, connection)
    self.id = streamReadString(streamId)
    self.schemeIndex = streamReadInt32(streamId)
    self.farmId = streamReadInt32(streamId)
    self.activatedTier = streamReadInt32(streamId)
    self.spawnedVehicles = streamReadBool(streamId)

    local reportCount = streamReadInt32(streamId)
    for i = 1, reportCount do
        local report = {
            cell1 = streamReadString(streamId),
            cell2 = streamReadString(streamId),
            cell3 = streamReadString(streamId)
        }
        table.insert(self.lastEvaluationReport, report)
    end

    local propCount = streamReadInt32(streamId)
    for i = 1, propCount do
        local key = streamReadString(streamId)
        local value = streamReadString(streamId)
        self.props[key] = value
    end
end

function Scheme:saveToXmlFile(xmlFile, key)
    setXMLString(xmlFile, key .. "#id", self.id)
    setXMLInt(xmlFile, key .. "#schemeIndex", self.schemeIndex)
    setXMLInt(xmlFile, key .. "#farmId", self.farmId)
    setXMLInt(xmlFile, key .. "#activatedTier", self.activatedTier)
    setXMLBool(xmlFile, key .. "#spawnedVehicles", self.spawnedVehicles)

    for i, report in ipairs(self.lastEvaluationReport) do
        local reportKey = string.format("%s.reportItems.item(%d)", key, i)
        setXMLString(xmlFile, reportKey .. "#cell1", report.cell1)
        setXMLString(xmlFile, reportKey .. "#cell2", report.cell2)
        setXMLString(xmlFile, reportKey .. "#cell3", report.cell3)
    end

    local i = 0
    for key, value in pairs(self.props) do
        local propKey = string.format("%s.propItems.item(%d)", key, i)
        setXMLString(xmlFile, propKey .. "#key", key)
        setXMLString(xmlFile, propKey .. "#value", value)
        i = i + 1
    end

    for i, vehicle in ipairs(self.vehicles) do
        xmlFile:setValue(string.format(key .. ".vehicles.vehicle(%d)#uniqueId", i - 1), vehicle.uniqueId)
    end
end

function Scheme:loadFromXMLFile(xmlFile, key)
    self.id = getXMLString(xmlFile, key .. "#id")
    self.schemeIndex = getXMLInt(xmlFile, key .. "#schemeIndex")
    self.farmId = getXMLInt(xmlFile, key .. "#farmId")
    self.activatedTier = getXMLInt(xmlFile, key .. "#activatedTier")
    self.spawnedVehicles = getXMLBool(xmlFile, key .. "#spawnedVehicles")

    if self.spawnedVehicles then
        g_messageCenter:subscribe(MessageType.VEHICLE_RESET, self.onVehicleReset, self)
    end

    local i = 0
    while true do
        local reportKey = string.format("%s.reportItems.item(%d)", key, i)
        if not hasXMLProperty(xmlFile, reportKey) then
            break
        end
        local report = {
            cell1 = getXMLString(xmlFile, reportKey .. "#cell1"),
            cell2 = getXMLString(xmlFile, reportKey .. "#cell2"),
            cell3 = getXMLString(xmlFile, reportKey .. "#cell3")
        }
        table.insert(self.lastEvaluationReport, report)
        i = i + 1
    end

    local j = 0
    while true do
        local propKey = string.format("%s.propItems.item(%d)", key, j)
        if not hasXMLProperty(xmlFile, propKey) then
            break
        end
        local propKeyName = getXMLString(xmlFile, propKey .. "#key")
        local propValue = getXMLString(xmlFile, propKey .. "#value")
        self.props[propKeyName] = propValue
        j = j + 1
    end

    for _, vehicleKey in xmlFile:iterator(key .. ".vehicles.vehicle") do
        local vehicleUniqueId = xmlFile:getValue(vehicleKey .. "#uniqueId")
        if self.pendingVehicleUniqueIds == nil then
            self.pendingVehicleUniqueIds = {}
        end
        table.insert(self.pendingVehicleUniqueIds, vehicleUniqueId)
    end
end

-- Called by the SchemeSystem when generating schemes
function Scheme:initialise()
    local schemeInfo = Schemes[self.schemeIndex]
    schemeInfo.initialise(schemeInfo, self)
end

function Scheme:setProp(key, value)
    self.props[key] = tostring(value)
end

function Scheme:getName()
    if self.schemeIndex == -1 then
        return nil
    end

    local schemeInfo = Schemes[self.schemeIndex]

    return g_i18n:getText(schemeInfo.name)
end

function Scheme:getDescription()
    if self.schemeIndex == -1 then
        return nil
    end

    local schemeInfo = Schemes[self.schemeIndex]

    if schemeInfo.descriptionFunction ~= nil then
        return schemeInfo.descriptionFunction(schemeInfo, self)
    end

    return g_i18n:getText(schemeInfo.description)
end

function Scheme:getReportDescription()
    if self.schemeIndex == -1 then
        return nil
    end

    local schemeInfo = Schemes[self.schemeIndex]

    return g_i18n:getText(schemeInfo.report_description)
end

function Scheme:availableForCurrentFarm()
    local rt = g_currentMission.RedTape
    local schemeSystem = g_currentMission.RedTape.SchemeSystem
    local policySystem = g_currentMission.RedTape.PolicySystem
    local farmId = g_currentMission:getFarmId()
    local farmTier = policySystem:getProgressForCurrentFarm().tier
    local schemeInfo = Schemes[self.schemeIndex]

    -- Check if the scheme conflicts with another active scheme
    local activeSchemes = schemeSystem:getActiveSchemesForFarm(farmId)
    for _, scheme in pairs(activeSchemes) do
        local activeSchemeInfo = Schemes[scheme.schemeIndex]
        if activeSchemeInfo.duplicationKey == schemeInfo.duplicationKey then
            return false
        end
    end

    -- Check if the scheme supports the current farm tier
    if not rt.tableHasKey(schemeInfo.tiers, farmTier) then
        return false
    end

    return true
end

function Scheme:evaluate()
    local rt = g_currentMission.RedTape
    local schemeInfo = Schemes[self.schemeIndex]
    local report = schemeInfo.evaluate(schemeInfo, self, self.activatedTier)

    if report ~= nil and rt.tableCount(report) > 0 then
        self.lastEvaluationReport = report or {}

        -- Ensure all report values are strings
        for _, report in ipairs(self.lastEvaluationReport) do
            report.cell1 = tostring(report.cell1 or "")
            report.cell2 = tostring(report.cell2 or "")
            report.cell3 = tostring(report.cell3 or "")
        end
    end
end

-- Called by SchemeSelectedEvent, runs on client and server
-- Creates a new farm specific scheme from
function Scheme:createFarmScheme(farmId)
    local policySystem = g_currentMission.RedTape.PolicySystem
    local farmScheme = Scheme.new()
    farmScheme.schemeIndex = self.schemeIndex
    farmScheme.farmId = farmId
    farmScheme.activatedTier = policySystem:getProgressForFarm(farmId).tier

    for key, value in pairs(self.props) do
        farmScheme.props[key] = value
    end
    return farmScheme
end

-- Called by SchemeSelectedEvent, runs on server only
function Scheme:selected()
    if not g_currentMission:getIsServer() then
        return
    end

    local schemeInfo = Schemes[self.schemeIndex]
    schemeInfo.selected(schemeInfo, self, self.activatedTier)
end

function Scheme:spawnVehicles()
    if not g_currentMission:getIsServer() then
        return
    end

    local schemeInfo = Schemes[self.schemeIndex]
    local vehicles = schemeInfo.getSchemeVehicles(self)

    for _, info in ipairs(vehicles) do
        local data = VehicleLoadingData.new()
        data:setFilename(info.filename)
        if data.isValid then
            if info.configurations ~= nil then
                data:setConfigurations(info.configurations)
            end
            data:setLoadingPlace(g_currentMission.storeSpawnPlaces, g_currentMission.usedStorePlaces)
            data:setPropertyState(VehiclePropertyState.MISSION)
            data:setOwnerFarmId(self.farmId)
            table.insert(self.pendingVehicleLoadingData, data)
            data:load(self.onSpawnedVehicle, self, {
                ["loadingData"] = data,
                ["vehicleInfo"] = info
            })
        end
    end

    self.spawnedVehicles = #vehicleGroup.vehicles > 0
    g_messageCenter:subscribe(MessageType.VEHICLE_RESET, self.onVehicleReset, self)
end

function Scheme:onSpawnedVehicle(vehicles, vehicleLoadState, loadingInfo)
    table.removeElement(self.pendingVehicleLoadingData, loadingInfo.loadingData)
    if self.failedToLoadVehicles then
        for _, vehicle in ipairs(vehicles) do
            vehicle:delete()
        end
        return
    elseif vehicleLoadState == VehicleLoadingState.OK then
        for _, vehicle in ipairs(vehicles) do
            vehicle:addWearAmount(math.random() * 0.3 + 0.1)
            vehicle:setOperatingTime(3600000 * (math.random() * 40 + 30))
            table.insert(self.vehicles, vehicle)
        end
    else
        self.failedToLoadVehicles = true
        for _, vehicle in ipairs(vehicles) do
            vehicle:delete()
        end
        for _, loadingData in ipairs(self.pendingVehicleLoadingData) do
            loadingData:cancelLoading()
        end
        table.clear(self.pendingVehicleLoadingData)
        table.clear(self.vehiclesToLoad)
        self.spawnedVehicles = false
        for _, vehicle in ipairs(self.vehicles) do
            vehicle:delete()
        end
        table.clear(self.vehicles)
    end
end

function Scheme:onVehicleReset(oldVehicle, newVehicle)
    if g_currentMission:getIsServer() and table.removeElement(self.vehicles, oldVehicle) then
        table.addElement(self.vehicles, newVehicle)
    end
end

function Scheme:removeAccess()
    if g_currentMission:getIsServer() then
        for _, vehicle in ipairs(self.vehicles) do
            if not vehicle:getIsBeingDeleted() then
                vehicle:delete()
            end
        end
        self.vehicles = {}
    end
end

-- Must be called when the scheme ends
function Scheme:endScheme()
    self:removeAccess()
    g_messageCenter:unsubscribeAll(self)
end

function Scheme:isSchemeVehicle(vehicle)
    for _, v in ipairs(self.vehicles) do
        if v == vehicle then
            return true
        end
    end
    return false
end
