RTEventLog = {}
RTEventLog_mt = Class(RTEventLog)

RTEventLog.sortAgeDescendingFunction = function(a, b)
    if a.year ~= b.year then
        return a.year > b.year
    elseif a.month ~= b.month then
        return a.month > b.month
    else
        return a.hour > b.hour
    end
end

function RTEventLog.new()
    local self = {}
    setmetatable(self, RTEventLog_mt)

    self.events = {}

    return self
end

-- Should not be called directly, only via a broadcasted Event
function RTEventLog:addEvent(farmId, eventType, detail, sendNotification)
    local event = RTEventLogItem.new()
    local rt = g_currentMission.RedTape

    event.farmId = farmId or -1
    event.eventType = eventType
    event.detail = detail
    event.hour = g_currentMission.environment.currentHour
    event.month = rt.periodToMonth(g_currentMission.environment.currentPeriod)
    event.year = RedTape.getActualYear()
    table.insert(self.events, event)

    if sendNotification then
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, detail)
    end
    g_messageCenter:publish(MessageType.EVENT_LOG_UPDATED)
end

function RTEventLog:pruneOld()
    local newEvents = {}
    local rt = g_currentMission.RedTape
    local currentMonth = rt.periodToMonth(g_currentMission.environment.currentPeriod)
    local currentYear = RedTape.getActualYear()

    for _, event in pairs(self.events) do
        local eventAge = (currentYear - event.year) * 12 + (currentMonth - event.month)
        if eventAge < 12 then
            table.insert(newEvents, event)
        end
    end

    self.events = newEvents
end

function RTEventLog:getEventsForCurrentFarm()
    local farmId = g_currentMission:getFarmId()
    local farmEvents = {}

    for _, event in pairs(self.events) do
        if event.farmId == -1 or event.farmId == farmId then
            table.insert(farmEvents, event)
        end
    end
    table.sort(farmEvents, RTEventLog.sortAgeDescendingFunction)

    return farmEvents
end

function RTEventLog:loadFromXMLFile(xmlFile)
    if (not g_currentMission:getIsServer()) then return end

    local key = RedTape.SaveKey .. ".eventLog"
    local i = 0
    while true do
        local eventKey = string.format("%s.events.event(%d)", key, i)
        if not hasXMLProperty(xmlFile, eventKey) then
            break
        end
        local event = RTEventLogItem.new()
        event:loadFromXMLFile(xmlFile, eventKey)
        table.insert(self.events, event)
        i = i + 1
    end
end

function RTEventLog:saveToXmlFile(xmlFile)
    if (not g_currentMission:getIsServer()) then return end

    local key = RedTape.SaveKey .. ".eventLog"

    local i = 0
    for _, event in pairs(self.events) do
        local eventKey = string.format("%s.events.event(%d)", key, i)
        event:saveToXmlFile(xmlFile, eventKey)
        i = i + 1
    end
end

function RTEventLog:writeInitialClientState(streamId, connection)
    local eventCount = 0
    for _, _ in pairs(self.events) do
        eventCount = eventCount + 1
    end
    streamWriteInt32(streamId, eventCount)

    for _, event in pairs(self.events) do
        event:writeStream(streamId, connection)
    end
end

function RTEventLog:readInitialClientState(streamId, connection)
    local eventCount = streamReadInt32(streamId)
    for i = 1, eventCount do
        local event = RTEventLogItem.new()
        event:readStream(streamId, connection)
        table.insert(self.events, event)
    end
end