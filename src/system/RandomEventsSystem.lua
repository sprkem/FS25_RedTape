RTRandomEventsSystem = {}

RTRandomEventsSystem_mt = Class(RTRandomEventsSystem)

function RTRandomEventsSystem.new()
    local self = {}
    setmetatable(self, RTRandomEventsSystem_mt)
    self.activeEventsByFarm = {}

    return self
end

function RTRandomEventsSystem:loadFromXMLFile(xmlFile, key)
    if (not g_currentMission:getIsServer()) then return end

    local i = 0
    while true do
        local eventKey = string.format("%s.activeEvents.item(%d)", key, i)
        if not hasXMLProperty(xmlFile, eventKey) then
            break
        end

        -- Load event data here
        local event = RTRandomEvent.new()
        event:loadFromXMLFile(xmlFile, eventKey)
        local farmId = event.farmId
        self.activeEventsByFarm[farmId] = self.activeEventsByFarm[farmId] or {}
        table.insert(self.activeEventsByFarm[farmId], event)

        i = i + 1
    end
end

function RTRandomEventsSystem:saveToXMLFile(xmlFile, key)
    if (not g_currentMission:getIsServer()) then return end

    local i = 0
    for _, events in pairs(self.activeEventsByFarm) do
        for _, event in pairs(events) do
            local eventKey = string.format("%s.activeEvents.item(%d)", key, i)
            event:saveToXMLFile(xmlFile, eventKey)
            i = i + 1
        end
    end
end

function RTRandomEventsSystem:writeInitialClientState(streamId, connection)

end

function RTRandomEventsSystem:readInitialClientState(streamId, connection)

end

function RTRandomEventsSystem:hourChanged()

end

function RTRandomEventsSystem:periodChanged()
    local eventSystem = g_currentMission.RedTape.RandomEventsSystem

    for farmId, events in pairs(eventSystem.activeEventsByFarm) do
        for _, event in pairs(events) do
            -- event:onPeriodChanged(farmId)
        end
    end

    eventSystem:generateRandomEvents()
end

function RTRandomEventsSystem:generateRandomEvents()

end