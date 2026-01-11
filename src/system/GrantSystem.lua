RTGrantSystem = {}
RTGrantSystem_mt = Class(RTGrantSystem)

RTGrantSystem.STATUS = {
    PENDING = 1,
    APPROVED = 2,
    REJECTED = 3,
    COMPLETE = 4,
}

RTGrantSystem.ALLOWED_CATEGORIES = {
    ["SHEDS"] = true,
    ["SILOS"] = true,
    ["SILOEXTENSIONS"] = true,
    ["FARMHOUSES"] = true,
    ["ANIMALPENS"] = true,
    ["PRODUCTIONPOINTS"] = true,
    ["SELLINGPOINTS"] = true,
}

RTGrantSystem.MIN_PRICE_FOR_GRANT = 100000
RTGrantSystem.APPLICATION_COST = 500

table.insert(FinanceStats.statNames, "grantReceived")
FinanceStats.statNameToIndex["grantReceived"] = #FinanceStats.statNames

table.insert(FinanceStats.statNames, "grantApplicationCost")
FinanceStats.statNameToIndex["grantApplicationCost"] = #FinanceStats.statNames

function RTGrantSystem.new()
    local self = {}
    setmetatable(self, RTGrantSystem_mt)

    self.pendingGrants = {}
    self.approvedGrants = {}
    self.completedGrants = {}

    MoneyType.GRANT_RECEIVED = MoneyType.register("grantReceived", "rt_ui_grantReceived")
    MoneyType.LAST_ID = MoneyType.LAST_ID + 1

    MoneyType.GRANT_APPLICATION_COST = MoneyType.register("grantApplicationCost", "rt_ui_grantApplicationCost")
    MoneyType.LAST_ID = MoneyType.LAST_ID + 1

    return self
end

function RTGrantSystem:loadFromXMLFile(xmlFile)
    if (not g_currentMission:getIsServer()) then
        return
    end

    local key = RedTape.SaveKey .. ".grantSystem"
    local pendingGrantsKey = key .. ".pendingGrants"
    local i = 0
    while true do
        local grantKey = string.format("%s.grant(%d)", pendingGrantsKey, i)
        if not hasXMLProperty(xmlFile, grantKey) then
            break
        end

        local grant = {
            id = xmlFile:getValue(grantKey .. "#id", RedTape.generateId()),
            farmId = xmlFile:getValue(grantKey .. "#farmId", 1),
            xmlFile = xmlFile:getValue(grantKey .. "#xmlFile", ""),
            price = xmlFile:getValue(grantKey .. "#price", 0),
            applicationMonth = xmlFile:getValue(grantKey .. "#applicationMonth", 0),
            assessmentMonth = xmlFile:getValue(grantKey .. "#assessmentMonth", 0),
            status = xmlFile:getValue(grantKey .. "#status", RTGrantSystem.STATUS.PENDING)
        }

        table.insert(self.pendingGrants, grant)
        i = i + 1
    end

    local approvedGrantsKey = key .. ".approvedGrants"
    i = 0
    while true do
        local grantKey = string.format("%s.grant(%d)", approvedGrantsKey, i)
        if not hasXMLProperty(xmlFile, grantKey) then
            break
        end

        local grant = {
            id = xmlFile:getValue(grantKey .. "#id", RedTape.generateId()),
            farmId = xmlFile:getValue(grantKey .. "#farmId", 1),
            xmlFile = xmlFile:getValue(grantKey .. "#xmlFile", ""),
            price = xmlFile:getValue(grantKey .. "#price", 0),
            amount = xmlFile:getValue(grantKey .. "#amount", 0),
            approvalMonth = xmlFile:getValue(grantKey .. "#approvalMonth", 0),
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

    -- Save pending grants
    local pendingGrantsKey = key .. ".pendingGrants"
    local counter = 0
    for _, grant in pairs(self.pendingGrants) do
        local grantKey = string.format("%s.grant(%d)", pendingGrantsKey, counter)
        xmlFile:setValue(grantKey .. "#id", grant.id)
        xmlFile:setValue(grantKey .. "#farmId", grant.farmId)
        xmlFile:setValue(grantKey .. "#xmlFile", grant.xmlFile)
        xmlFile:setValue(grantKey .. "#price", grant.price)
        xmlFile:setValue(grantKey .. "#applicationMonth", grant.applicationMonth)
        xmlFile:setValue(grantKey .. "#assessmentMonth", grant.assessmentMonth)
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
        xmlFile:setValue(grantKey .. "#xmlFile", grant.xmlFile)
        xmlFile:setValue(grantKey .. "#price", grant.price)
        xmlFile:setValue(grantKey .. "#amount", grant.amount)
        xmlFile:setValue(grantKey .. "#approvalMonth", grant.approvalMonth)
        counter = counter + 1
    end
end

function RTGrantSystem:isEnabled()
    return g_currentMission.RedTape.settings.grantsEnabled
end

function RTGrantSystem:writeInitialClientState(streamId, connection)
    streamWriteInt32(streamId, RedTape.tableCount(self.pendingGrants))
    for _, grant in pairs(self.pendingGrants) do
        streamWriteString(streamId, grant.id)
        streamWriteInt32(streamId, grant.farmId)
        streamWriteString(streamId, grant.xmlFile)
        streamWriteFloat32(streamId, grant.price)
        streamWriteInt32(streamId, grant.applicationMonth)
        streamWriteInt32(streamId, grant.assessmentMonth)
        streamWriteInt32(streamId, grant.status)
    end

    streamWriteInt32(streamId, RedTape.tableCount(self.approvedGrants))
    for _, grant in pairs(self.approvedGrants) do
        streamWriteString(streamId, grant.id)
        streamWriteInt32(streamId, grant.farmId)
        streamWriteString(streamId, grant.xmlFile)
        streamWriteFloat32(streamId, grant.price)
        streamWriteFloat32(streamId, grant.amount)
        streamWriteInt32(streamId, grant.approvalMonth)
    end
end

function RTGrantSystem:readInitialClientState(streamId, connection)
    local pendingCount = streamReadInt32(streamId)
    self.pendingGrants = {}
    for i = 1, pendingCount do
        local grant = {
            id = streamReadString(streamId),
            farmId = streamReadInt32(streamId),
            xmlFile = streamReadString(streamId),
            price = streamReadFloat32(streamId),
            applicationMonth = streamReadInt32(streamId),
            assessmentMonth = streamReadInt32(streamId),
            status = streamReadInt32(streamId)
        }
        table.insert(self.pendingGrants, grant)
    end

    local approvedCount = streamReadInt32(streamId)
    self.approvedGrants = {}
    for i = 1, approvedCount do
        local grant = {
            id = streamReadString(streamId),
            farmId = streamReadInt32(streamId),
            xmlFile = streamReadString(streamId),
            price = streamReadFloat32(streamId),
            amount = streamReadFloat32(streamId),
            approvalMonth = streamReadInt32(streamId),
        }
        table.insert(self.approvedGrants, grant)
    end
end

function RTGrantSystem:periodChanged()
    if (not self:isEnabled()) then
        return
    end

    self:processGrantApplications()
end

function RTGrantSystem:processGrantApplications()
    if not g_currentMission:getIsServer() then
        return
    end

    local currentMonth = RedTape.getCumulativeMonth()
    local policySystem = g_currentMission.RedTape.PolicySystem

    for _, grant in pairs(self.pendingGrants) do
        if grant.status == RTGrantSystem.STATUS.PENDING and grant.assessmentMonth <= currentMonth then
            local farmProgress = policySystem:getProgressForFarm(grant.farmId)
            local farmTier = farmProgress.tier

            local approvalChance = self:getApprovalChanceForTier(farmTier)
            local randomValue = math.random()

            if randomValue <= approvalChance then
                -- Grant approved
                local grantPercentage = self:getGrantPercentageForTier(farmTier)
                local grantAmount = grant.price * grantPercentage

                g_client:getServerConnection():sendEvent(RTGrantStatusUpdateEvent.new(grant.farmId, grant.id,
                    RTGrantSystem.STATUS.APPROVED, grantAmount))
            else
                -- Grant rejected
                g_client:getServerConnection():sendEvent(RTGrantStatusUpdateEvent.new(grant.farmId, grant.id,
                    RTGrantSystem.STATUS.REJECTED, 0))
            end
        end
    end
end

function RTGrantSystem:getApprovalChanceForTier(tier)
    if tier == RTPolicySystem.TIER.A then
        return 0.45
    elseif tier == RTPolicySystem.TIER.B then
        return 0.42
    elseif tier == RTPolicySystem.TIER.C then
        return 0.38
    elseif tier == RTPolicySystem.TIER.D then
        return 0.35
    else
        return 0.35
    end
end

function RTGrantSystem:getGrantPercentageForTier(tier)
    -- Tier-based grant percentages (30-40% range)
    if tier == RTPolicySystem.TIER.A then
        return 0.35 + (math.random() * 0.05)
    elseif tier == RTPolicySystem.TIER.B then
        return 0.33 + (math.random() * 0.05)
    elseif tier == RTPolicySystem.TIER.C then
        return 0.31 + (math.random() * 0.05)
    elseif tier == RTPolicySystem.TIER.D then
        return 0.30 + (math.random() * 0.05)
    else
        return 0.30 + (math.random() * 0.05)
    end
end

function RTGrantSystem:applyForGrant(farmId, xmlFile, price, grantId)
    -- Charge application fee
    local applicationCost = RTGrantSystem.APPLICATION_COST
    if g_currentMission:getIsServer() then
        g_currentMission:addMoneyChange(-applicationCost, farmId, MoneyType.GRANT_APPLICATION_COST, true)
    end
    g_farmManager:getFarmById(farmId):changeBalance(-applicationCost, MoneyType.GRANT_APPLICATION_COST)

    -- Create new grant application with provided ID and assessment date
    local currentMonth = RedTape.getCumulativeMonth()
    local assessmentDelay = 3 + math.random(3) -- 3-6 months delay

    local grant = {
        id = grantId,
        farmId = farmId,
        xmlFile = xmlFile,
        price = price,
        applicationMonth = currentMonth,
        assessmentMonth = currentMonth + assessmentDelay,
        status = RTGrantSystem.STATUS.PENDING
    }

    table.insert(self.pendingGrants, grant)
    return grant.id
end

function RTGrantSystem:getGrantsForFarm(farmId)
    local farmGrants = {
        pending = {},
        approved = {},
        completed = {}
    }

    -- Filter grants by farm ID
    for _, grant in pairs(self.pendingGrants) do
        if grant.farmId == farmId then
            table.insert(farmGrants.pending, grant)
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

function RTGrantSystem:onPlaceablePurchased(farmId, xmlFilename)
    if not g_currentMission:getIsServer() then
        return
    end

    -- Find matching approved grant for this farm and building type
    local matchingGrant = nil
    for _, grant in pairs(self.approvedGrants) do
        if grant.farmId == farmId and grant.xmlFile == xmlFilename then
            matchingGrant = grant
            break
        end
    end

    if matchingGrant then
        -- Award grant money to the farm
        if g_currentMission:getIsServer() then
            g_currentMission:addMoneyChange(matchingGrant.amount, farmId, MoneyType.GRANT_RECEIVED, true)
        end
        g_farmManager:getFarmById(farmId):changeBalance(matchingGrant.amount, MoneyType.GRANT_RECEIVED)

        -- Send completion event
        g_client:getServerConnection():sendEvent(RTGrantStatusUpdateEvent.new(farmId, matchingGrant.id,
            RTGrantSystem.STATUS.COMPLETE, matchingGrant.amount))
    end
end

function RTGrantSystem:updateGrantStatus(grantId, newStatus, approvedAmount)
    local grant, currentStatus = self:findGrantById(grantId)

    if not grant then
        return -- Grant not found
    end

    local currentFarmId = g_currentMission:getFarmId()
    local eventLog = g_currentMission.RedTape.EventLog

    if newStatus == RTGrantSystem.STATUS.APPROVED then
        -- Move from pending to approved
        if currentStatus == RTGrantSystem.STATUS.PENDING then
            -- Remove from pending grants
            local newPendingGrants = {}
            for _, g in pairs(self.pendingGrants) do
                if g.id ~= grantId then
                    table.insert(newPendingGrants, g)
                end
            end
            self.pendingGrants = newPendingGrants

            -- Add to approved grants
            local approvedGrant = {
                id = grant.id,
                farmId = grant.farmId,
                xmlFile = grant.xmlFile,
                price = grant.price,
                amount = approvedAmount,
                approvalMonth = RedTape.getCumulativeMonth()
            }
            table.insert(self.approvedGrants, approvedGrant)

            -- Add event log entry
            local detail = string.format(g_i18n:getText("rt_grant_approved_notification"), g_i18n:formatMoney(approvedAmount))
            local sendNotification = (grant.farmId == currentFarmId)
            eventLog:addEvent(grant.farmId, RTEventLogItem.EVENT_TYPE.GRANT_APPROVED, detail, sendNotification)
        end
    elseif newStatus == RTGrantSystem.STATUS.REJECTED then
        -- Remove from pending grants (rejected grants are not stored)
        if currentStatus == RTGrantSystem.STATUS.PENDING then
            local newPendingGrants = {}
            for _, g in pairs(self.pendingGrants) do
                if g.id ~= grantId then
                    table.insert(newPendingGrants, g)
                end
            end
            self.pendingGrants = newPendingGrants

            -- Add event log entry
            local detail = g_i18n:getText("rt_grant_rejected_notification")
            local sendNotification = (grant.farmId == currentFarmId)
            eventLog:addEvent(grant.farmId, RTEventLogItem.EVENT_TYPE.GRANT_REJECTED, detail, sendNotification)
        end
    elseif newStatus == RTGrantSystem.STATUS.COMPLETE then
        -- Move from approved to completed
        if currentStatus == RTGrantSystem.STATUS.APPROVED then
            -- Remove from approved grants
            local newApprovedGrants = {}
            for _, g in pairs(self.approvedGrants) do
                if g.id ~= grantId then
                    table.insert(newApprovedGrants, g)
                end
            end
            self.approvedGrants = newApprovedGrants

            -- Add to completed grants
            local completedGrant = {
                id = grant.id,
                farmId = grant.farmId,
                xmlFile = grant.xmlFile,
                price = grant.price,
                amount = grant.amount,
                completionMonth = RedTape.getCumulativeMonth()
            }
            table.insert(self.completedGrants, completedGrant)

            -- Add event log entry
            local detail = string.format(g_i18n:getText("rt_grant_completed_notification"), g_i18n:formatMoney(approvedAmount))
            local sendNotification = (grant.farmId == currentFarmId)
            eventLog:addEvent(grant.farmId, RTEventLogItem.EVENT_TYPE.GRANT_COMPLETED, detail, sendNotification)
        end
    end
end

function RTGrantSystem:findGrantById(grantId)
    -- Search in pending grants
    for _, grant in pairs(self.pendingGrants) do
        if grant.id == grantId then
            return grant, RTGrantSystem.STATUS.PENDING
        end
    end

    -- Search in approved grants
    for _, grant in pairs(self.approvedGrants) do
        if grant.id == grantId then
            return grant, RTGrantSystem.STATUS.APPROVED
        end
    end

    -- Search in completed grants
    for _, grant in pairs(self.completedGrants) do
        if grant.id == grantId then
            return grant, RTGrantSystem.STATUS.COMPLETE
        end
    end

    return nil, nil
end
