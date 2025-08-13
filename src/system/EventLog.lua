EventLog = {}
EventLog_mt = Class(EventLog)

EventLog.sortAgeDescendingFunction = function(a, b)
    if a.year ~= b.year then
        return a.year > b.year
    else
        return a.month > b.month
    end
end

function EventLog.new()
    local self = {}
    setmetatable(self, EventLog_mt)

    self.events = {}

    self:loadFromXMLFile()
    return self
end

function EventLog:addEvent(farmId, eventType, detail, sendNotification)
    local event = EventLogItem.new()
    local rt = g_currentMission.RedTape

    event.farmId = farmId
    event.eventType = eventType
    event.detail = detail
    event.month = rt.periodToMonth(g_currentMission.environment.currentPeriod)
    event.year = g_currentMission.environment.currentYear
    table.insert(self.events, event)

    if sendNotification then
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, detail)
    end
    g_messageCenter:publish(MessageType.EVENT_LOG_UPDATED)
end

function EventLog:pruneOld()
    local newEvents = {}
    local rt = g_currentMission.RedTape
    local currentMonth = rt.periodToMonth(g_currentMission.environment.currentPeriod)
    local currentYear = g_currentMission.environment.currentYear

    for _, event in pairs(self.events) do
        local eventAge = (currentYear - event.year) * 12 + (currentMonth - event.month)
        if eventAge < 12 then
            table.insert(newEvents, event)
        end
    end

    self.events = newEvents
end

function EventLog:getEventsForCurrentFarm()
    local farmId = g_currentMission:getFarmId()
    local farmEvents = {}

    for _, event in pairs(self.events) do
        if event.farmId == nil or event.farmId == farmId then
            table.insert(farmEvents, event)
        end
    end
    table.sort(farmEvents, EventLog.sortAgeDescendingFunction)

    return farmEvents
end

function EventLog:loadFromXMLFile()
    if (not g_currentMission:getIsServer()) then return end

    local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
    if savegameFolderPath == nil then
        savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
    end
    savegameFolderPath = savegameFolderPath .. "/"
    local key = "EventLog"

    if fileExists(savegameFolderPath .. "RedTape.xml") then
        local xmlFile = loadXMLFile(key, savegameFolderPath .. "RedTape.xml");

        local i = 0
        while true do
            local eventKey = string.format("%s.events.event(%d)", key, i)
            if not hasXMLProperty(xmlFile, eventKey) then
                break
            end
            local event = Event.new()
            event:loadFromXMLFile(xmlFile, eventKey)
            table.insert(self.events, event)
            i = i + 1
        end

        delete(xmlFile)
    end
end

function EventLog:saveToXmlFile()
    if (not g_currentMission:getIsServer()) then return end

    local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory .. "/"
    if savegameFolderPath == nil then
        savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(),
            g_currentMission.missionInfo.savegameIndex .. "/")
    end

    local key = "EventLog";
    local xmlFile = createXMLFile(key, savegameFolderPath .. "RedTape.xml", key);

    local i = 0
    for _, event in pairs(self.events) do
        local eventKey = string.format("%s.events.event(%d)", key, i)
        event:saveToXmlFile(xmlFile, eventKey)
        i = i + 1
    end

    saveXMLFile(xmlFile);
    delete(xmlFile);
end

-- function EventLog:saveToXmlFile(xmlFile, key)
--     local i = 0
--     for _, event in pairs(self.events) do
--         local eventKey = string.format("%s.events.event(%d)", key, i)
--         event:saveToXmlFile(xmlFile, eventKey)
--         i = i + 1
--     end
-- end

-- function EventLog:loadFromXMLFile(xmlFile, key)
--     local i = 0
--     while true do
--         local eventKey = string.format("%s.events.event(%d)", key, i)
--         if not hasXMLProperty(xmlFile, eventKey) then
--             break
--         end
--         local event = Event.new()
--         event:loadFromXMLFile(xmlFile, eventKey)
--         table.insert(self.events, event)
--         i = i + 1
--     end
-- end
