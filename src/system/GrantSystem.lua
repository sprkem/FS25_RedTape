RTGrantSystem = {}
RTGrantSystem_mt = Class(RTGrantSystem)

RTGrantSystem.STATUS = {
    PENDING = 1,
    APPROVED = 2,
    COMPLETE = 3,
}

table.insert(FinanceStats.statNames, "grantReceived")
FinanceStats.statNameToIndex["grantReceived"] = #FinanceStats.statNames

table.insert(FinanceStats.statNames, "grantApplicationCost")
FinanceStats.statNameToIndex["grantApplicationCost"] = #FinanceStats.statNames

function RTGrantSystem.new()
    local self = {}
    setmetatable(self, RTGrantSystem_mt)

    -- Initialize system state
    self.activeGrants = {}    -- Grants currently being processed
    self.approvedGrants = {}  -- Grants approved and available for use
    self.completedGrants = {} -- Grants that have been fully utilized

    -- Register MoneyType for grant transactions
    MoneyType.GRANT_RECEIVED = MoneyType.register("grantReceived", "rt_ui_grantReceived")
    MoneyType.LAST_ID = MoneyType.LAST_ID + 1

    MoneyType.GRANT_APPLICATION_COST = MoneyType.register("grantApplicationCost", "rt_ui_grantApplicationCost")
    MoneyType.LAST_ID = MoneyType.LAST_ID + 1

    return self
end

-- Required lifecycle methods

function RTGrantSystem:loadFromXMLFile(xmlFile)
    if (not g_currentMission:getIsServer()) then
        return
    end

    local key = RedTape.SaveKey .. ".grantSystem"

    -- Load active grants
    local activeGrantsKey = key .. ".activeGrants"
    local i = 0
    while true do
        local grantKey = string.format("%s.grant(%d)", activeGrantsKey, i)
        if not xmlFile:hasProperty(grantKey) then
            break
        end

        local grant = {
            id = xmlFile:getValue(grantKey .. "#id", RedTape.generateId()),
            farmId = xmlFile:getValue(grantKey .. "#farmId", 1),
            grantType = xmlFile:getValue(grantKey .. "#grantType", ""),
            amount = xmlFile:getValue(grantKey .. "#amount", 0),
            applicationMonth = xmlFile:getValue(grantKey .. "#applicationMonth", 0),
            status = xmlFile:getValue(grantKey .. "#status", RTGrantSystem.STATUS.PENDING)
        }

        table.insert(self.activeGrants, grant)
        i = i + 1
    end

    -- Load approved grants
    local approvedGrantsKey = key .. ".approvedGrants"
    i = 0
    while true do
        local grantKey = string.format("%s.grant(%d)", approvedGrantsKey, i)
        if not xmlFile:hasProperty(grantKey) then
            break
        end

        local grant = {
            id = xmlFile:getValue(grantKey .. "#id", RedTape.generateId()),
            farmId = xmlFile:getValue(grantKey .. "#farmId", 1),
            grantType = xmlFile:getValue(grantKey .. "#grantType", ""),
            amount = xmlFile:getValue(grantKey .. "#amount", 0),
            approvalMonth = xmlFile:getValue(grantKey .. "#approvalMonth", 0),
            remainingAmount = xmlFile:getValue(grantKey .. "#remainingAmount", 0)
        }

        table.insert(self.approvedGrants, grant)
        i = i + 1
    end
end

function RTGrantSystem:saveToXmlFile(xmlFile)
    if (not g_currentMission:getIsServer()) then
        return
    end

    if (not self:isEnabled()) then
        return
    end

    local key = RedTape.SaveKey .. ".grantSystem"

    -- Save active grants
    local activeGrantsKey = key .. ".activeGrants"
    local counter = 0
    for _, grant in pairs(self.activeGrants) do
        local grantKey = string.format("%s.grant(%d)", activeGrantsKey, counter)
        xmlFile:setValue(grantKey .. "#id", grant.id)
        xmlFile:setValue(grantKey .. "#farmId", grant.farmId)
        xmlFile:setValue(grantKey .. "#grantType", grant.grantType)
        xmlFile:setValue(grantKey .. "#amount", grant.amount)
        xmlFile:setValue(grantKey .. "#applicationMonth", grant.applicationMonth)
        xmlFile:setValue(grantKey .. "#status", grant.status)
        counter = counter + 1
    end

    -- Save approved grants
    local approvedGrantsKey = key .. ".approvedGrants"
    counter = 0
    for _, grant in pairs(self.approvedGrants) do
        local grantKey = string.format("%s.grant(%d)", approvedGrantsKey, counter)
        xmlFile:setValue(grantKey .. "#id", grant.id)
        xmlFile:setValue(grantKey .. "#farmId", grant.farmId)
        xmlFile:setValue(grantKey .. "#grantType", grant.grantType)
        xmlFile:setValue(grantKey .. "#amount", grant.amount)
        xmlFile:setValue(grantKey .. "#approvalMonth", grant.approvalMonth)
        xmlFile:setValue(grantKey .. "#remainingAmount", grant.remainingAmount)
        counter = counter + 1
    end
end

function RTGrantSystem:isEnabled()
    return g_currentMission.RedTape.settings.grantsEnabled
end

function RTGrantSystem:writeInitialClientState(streamId, connection)
    -- Send active grants count and data
    streamWriteInt32(streamId, #self.activeGrants)
    for _, grant in pairs(self.activeGrants) do
        streamWriteString(streamId, grant.id)
        streamWriteInt32(streamId, grant.farmId)
        streamWriteString(streamId, grant.grantType)
        streamWriteFloat32(streamId, grant.amount)
        streamWriteInt32(streamId, grant.applicationMonth)
        streamWriteInt32(streamId, grant.status)
    end

    -- Send approved grants count and data
    streamWriteInt32(streamId, #self.approvedGrants)
    for _, grant in pairs(self.approvedGrants) do
        streamWriteString(streamId, grant.id)
        streamWriteInt32(streamId, grant.farmId)
        streamWriteString(streamId, grant.grantType)
        streamWriteFloat32(streamId, grant.amount)
        streamWriteInt32(streamId, grant.approvalMonth)
        streamWriteFloat32(streamId, grant.remainingAmount)
    end
end

function RTGrantSystem:readInitialClientState(streamId, connection)
    -- Read active grants
    local activeCount = streamReadInt32(streamId)
    self.activeGrants = {}
    for i = 1, activeCount do
        local grant = {
            id = streamReadString(streamId),
            farmId = streamReadInt32(streamId),
            grantType = streamReadString(streamId),
            amount = streamReadFloat32(streamId),
            applicationMonth = streamReadInt32(streamId),
            status = streamReadInt32(streamId)
        }
        table.insert(self.activeGrants, grant)
    end

    -- Read approved grants
    local approvedCount = streamReadInt32(streamId)
    self.approvedGrants = {}
    for i = 1, approvedCount do
        local grant = {
            id = streamReadString(streamId),
            farmId = streamReadInt32(streamId),
            grantType = streamReadString(streamId),
            amount = streamReadFloat32(streamId),
            approvalMonth = streamReadInt32(streamId),
            remainingAmount = streamReadFloat32(streamId)
        }
        table.insert(self.approvedGrants, grant)
    end
end

function RTGrantSystem:periodChanged()
    if (not self:isEnabled()) then
        return
    end

    -- Process pending grant applications (check for approvals/rejections)
    self:processGrantApplications()
end

-- System-specific methods

function RTGrantSystem:processGrantApplications()
    -- Placeholder for grant processing logic
    -- Will be implemented later with approval criteria
end

function RTGrantSystem:applyForGrant(farmId, grantType, requestedAmount)
    -- Create new grant application with unique ID
    local grant = {
        id = RedTape.generateId(),
        farmId = farmId,
        grantType = grantType,
        amount = requestedAmount,
        applicationMonth = RedTape.getCumulativeMonth(),
        status = RTGrantSystem.STATUS.PENDING
    }

    table.insert(self.activeGrants, grant)
    return grant.id
end

function RTGrantSystem:getGrantsForFarm(farmId)
    local farmGrants = {
        active = {},
        approved = {},
        completed = {}
    }

    -- Filter grants by farm ID
    for _, grant in pairs(self.activeGrants) do
        if grant.farmId == farmId then
            table.insert(farmGrants.active, grant)
        end
    end

    for _, grant in pairs(self.approvedGrants) do
        if grant.farmId == farmId then
            table.insert(farmGrants.approved, grant)
        end
    end

    for _, grant in pairs(self.completedGrants) do
        if grant.farmId == farmId then
            table.insert(farmGrants.completed, grant)
        end
    end

    return farmGrants
end

function RTGrantSystem:useGrantFunds(farmId, grantId, amount, purpose)
    -- Placeholder for using approved grant funds
    -- Will be implemented later with purchase validation
end

function RTGrantSystem:findGrantById(grantId)
    -- Search in active grants
    for _, grant in pairs(self.activeGrants) do
        if grant.id == grantId then
            return grant, "active"
        end
    end

    -- Search in approved grants
    for _, grant in pairs(self.approvedGrants) do
        if grant.id == grantId then
            return grant, "approved"
        end
    end

    -- Search in completed grants
    for _, grant in pairs(self.completedGrants) do
        if grant.id == grantId then
            return grant, "completed"
        end
    end

    return nil, nil
end
