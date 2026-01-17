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

RTGrantSystem.MIN_PRICE_FOR_GRANT = 80000
RTGrantSystem.APPLICATION_COST = 500
RTGrantSystem.GRANT_RETENTION_MONTHS = 36
RTGrantSystem.COOLDOWN_PERIOD_MONTHS = 6

table.insert(FinanceStats.statNames, "grantReceived")
FinanceStats.statNameToIndex["grantReceived"] = #FinanceStats.statNames

table.insert(FinanceStats.statNames, "grantApplicationCost")
FinanceStats.statNameToIndex["grantApplicationCost"] = #FinanceStats.statNames

function RTGrantSystem.new()
    local self = {}
    setmetatable(self, RTGrantSystem_mt)

    -- Single data structure indexed by grant ID
    self.grants = {} -- [grantId] = grantObject

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

    local key = RedTape.SaveKey .. ".grantSystem.grants"
    local i = 0
    while true do
        local grantKey = string.format("%s.grant(%d)", key, i)
        if not hasXMLProperty(xmlFile, grantKey) then
            break
        end

        local grant = {
            id = getXMLString(xmlFile, grantKey .. "#id") or RedTape.generateId(),
            farmId = xmlFile:getValue(grantKey .. "#farmId", 1),
            xmlFile = xmlFile:getValue(grantKey .. "#xmlFile", ""),
            price = xmlFile:getValue(grantKey .. "#price", 0),
            status = xmlFile:getValue(grantKey .. "#status", RTGrantSystem.STATUS.PENDING),
            applicationMonth = xmlFile:getValue(grantKey .. "#applicationMonth", 0),
            assessmentMonth = xmlFile:getValue(grantKey .. "#assessmentMonth", 0),
            amount = xmlFile:getValue(grantKey .. "#amount", 0),
            completionMonth = xmlFile:getValue(grantKey .. "#completionMonth", 0)
        }

        self.grants[grant.id] = grant
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

    local key = RedTape.SaveKey .. ".grantSystem.grants"
    local counter = 0
    local currentMonth = RedTape.getCumulativeMonth()

    for _, grant in pairs(self.grants) do
        local shouldSave = true

        if grant.status == RTGrantSystem.STATUS.REJECTED then
            if grant.assessmentMonth and (currentMonth - grant.assessmentMonth) > RTGrantSystem.GRANT_RETENTION_MONTHS then
                shouldSave = false
            end
        end

        if grant.status == RTGrantSystem.STATUS.COMPLETE then
            if grant.completionMonth and (currentMonth - grant.completionMonth) > RTGrantSystem.GRANT_RETENTION_MONTHS then
                shouldSave = false
            end
        end

        if shouldSave then
            local grantKey = string.format("%s.grant(%d)", key, counter)
            xmlFile:setValue(grantKey .. "#id", grant.id)
            xmlFile:setValue(grantKey .. "#farmId", grant.farmId)
            xmlFile:setValue(grantKey .. "#xmlFile", grant.xmlFile)
            xmlFile:setValue(grantKey .. "#price", grant.price)
            xmlFile:setValue(grantKey .. "#status", grant.status)
            xmlFile:setValue(grantKey .. "#applicationMonth", grant.applicationMonth or 0)
            xmlFile:setValue(grantKey .. "#assessmentMonth", grant.assessmentMonth or 0)
            xmlFile:setValue(grantKey .. "#amount", grant.amount or 0)
            xmlFile:setValue(grantKey .. "#completionMonth", grant.completionMonth or 0)
            counter = counter + 1
        end
    end
end

function RTGrantSystem:isEnabled()
    return g_currentMission.RedTape.settings.grantsEnabled
end

function RTGrantSystem:writeInitialClientState(streamId, connection)
    streamWriteInt32(streamId, RedTape.tableCount(self.grants))
    for _, grant in pairs(self.grants) do
        streamWriteString(streamId, grant.id)
        streamWriteInt32(streamId, grant.farmId)
        streamWriteString(streamId, grant.xmlFile)
        streamWriteFloat32(streamId, grant.price)
        streamWriteInt32(streamId, grant.status)
        streamWriteInt32(streamId, grant.applicationMonth or 0)
        streamWriteInt32(streamId, grant.assessmentMonth or 0)
        streamWriteFloat32(streamId, grant.amount or 0)
        streamWriteInt32(streamId, grant.completionMonth or 0)
    end
end

function RTGrantSystem:readInitialClientState(streamId, connection)
    local grantCount = streamReadInt32(streamId)
    self.grants = {}
    for i = 1, grantCount do
        local grant = {
            id = streamReadString(streamId),
            farmId = streamReadInt32(streamId),
            xmlFile = streamReadString(streamId),
            price = streamReadFloat32(streamId),
            status = streamReadInt32(streamId),
            applicationMonth = streamReadInt32(streamId),
            assessmentMonth = streamReadInt32(streamId),
            amount = streamReadFloat32(streamId),
            completionMonth = streamReadInt32(streamId)
        }
        self.grants[grant.id] = grant
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

    for _, grant in pairs(self.grants) do
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
        status = RTGrantSystem.STATUS.PENDING,
        applicationMonth = currentMonth,
        assessmentMonth = currentMonth + assessmentDelay
    }

    self.grants[grantId] = grant

    -- Publish data updated message
    g_messageCenter:publish(MessageType.RT_DATA_UPDATED)

    return grant.id
end

function RTGrantSystem:getGrantsForFarm(farmId)
    local farmGrants = {
        pending = {},
        approved = {},
        completed = {}
    }

    -- Filter grants by farm ID and status
    for _, grant in pairs(self.grants) do
        if grant.farmId == farmId then
            if grant.status == RTGrantSystem.STATUS.PENDING then
                table.insert(farmGrants.pending, grant)
            elseif grant.status == RTGrantSystem.STATUS.APPROVED then
                table.insert(farmGrants.approved, grant)
            elseif grant.status == RTGrantSystem.STATUS.COMPLETE then
                table.insert(farmGrants.completed, grant)
            end
        end
    end

    return farmGrants
end

function RTGrantSystem:onPlaceablePurchased(farmId, xmlFilename)
    if not g_currentMission:getIsServer() then
        return
    end

    local matchingGrant = nil
    for _, grant in pairs(self.grants) do
        if grant.farmId == farmId and grant.xmlFile == xmlFilename and grant.status == RTGrantSystem.STATUS.APPROVED then
            matchingGrant = grant
            break
        end
    end

    if matchingGrant then
        if g_currentMission:getIsServer() then
            g_currentMission:addMoneyChange(matchingGrant.amount, farmId, MoneyType.GRANT_RECEIVED, true)
        end
        g_farmManager:getFarmById(farmId):changeBalance(matchingGrant.amount, MoneyType.GRANT_RECEIVED)
        g_client:getServerConnection():sendEvent(RTGrantStatusUpdateEvent.new(farmId, matchingGrant.id,
            RTGrantSystem.STATUS.COMPLETE, matchingGrant.amount))
    end
end

function RTGrantSystem:updateGrantStatus(grantId, newStatus, approvedAmount)
    local grant = self.grants[grantId]

    if not grant then
        return
    end

    local currentFarmId = g_currentMission:getFarmId()
    local eventLog = g_currentMission.RedTape.EventLog
    grant.status = newStatus

    if newStatus == RTGrantSystem.STATUS.APPROVED then
        grant.amount = approvedAmount

        local detail = string.format(g_i18n:getText("rt_grant_approved_notification"), g_i18n:formatMoney(approvedAmount))
        local sendNotification = (grant.farmId == currentFarmId)
        eventLog:addEvent(grant.farmId, RTEventLogItem.EVENT_TYPE.GRANT_APPROVED, detail, sendNotification)
    elseif newStatus == RTGrantSystem.STATUS.REJECTED then
        grant.completionMonth = RedTape.getCumulativeMonth()

        local detail = g_i18n:getText("rt_grant_rejected_notification")
        local sendNotification = (grant.farmId == currentFarmId)
        eventLog:addEvent(grant.farmId, RTEventLogItem.EVENT_TYPE.GRANT_REJECTED, detail, sendNotification)
    elseif newStatus == RTGrantSystem.STATUS.COMPLETE then
        grant.completionMonth = RedTape.getCumulativeMonth()

        local detail = string.format(g_i18n:getText("rt_grant_completed_notification"),
            g_i18n:formatMoney(approvedAmount))
        local sendNotification = (grant.farmId == currentFarmId)
        eventLog:addEvent(grant.farmId, RTEventLogItem.EVENT_TYPE.GRANT_COMPLETED, detail, sendNotification)
    end

    -- Publish data updated message
    g_messageCenter:publish(MessageType.RT_DATA_UPDATED)
end

function RTGrantSystem:findGrantById(grantId)
    local grant = self.grants[grantId]
    if grant then
        return grant, grant.status
    end
    return nil, nil
end

function RTGrantSystem:canFarmApplyForGrant(farmId)
    local currentMonth = RedTape.getCumulativeMonth()

    for _, grant in pairs(self.grants) do
        if grant.farmId == farmId then
            if grant.status == RTGrantSystem.STATUS.PENDING then
                return false
            end

            if grant.status == RTGrantSystem.STATUS.APPROVED then
                return false
            end

            if grant.status == RTGrantSystem.STATUS.COMPLETE then
                if grant.completionMonth then
                    local monthsSinceCompletion = currentMonth - grant.completionMonth
                    if monthsSinceCompletion < RTGrantSystem.COOLDOWN_PERIOD_MONTHS then
                        return false
                    end
                end
            end
        end
    end

    return true
end

function RTGrantSystem:onDisabled()
    for grantId, grant in pairs(self.grants) do
        if grant.status == RTGrantSystem.STATUS.PENDING or grant.status == RTGrantSystem.STATUS.APPROVED then
            self.grants[grantId] = nil
        end
    end
    g_messageCenter:publish(MessageType.RT_DATA_UPDATED)
end
