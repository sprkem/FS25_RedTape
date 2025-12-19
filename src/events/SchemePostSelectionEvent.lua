-- A selected scheme is when a scheme is chosen by a farm
RTSchemePostSelectionEvent = {}
local RTSchemePostSelectionEvent_mt = Class(RTSchemePostSelectionEvent, Event)

InitEventClass(RTSchemePostSelectionEvent, "RTSchemePostSelectionEvent")

function RTSchemePostSelectionEvent.emptyNew()
    local self = Event.new(RTSchemePostSelectionEvent_mt)

    return self
end

function RTSchemePostSelectionEvent.new(scheme)
    local self = RTSchemePostSelectionEvent.emptyNew()
    self.scheme = scheme
    return self
end

function RTSchemePostSelectionEvent:writeStream(streamId, connection)
    self.scheme:writeStream(streamId, connection)
end

function RTSchemePostSelectionEvent:readStream(streamId, connection)
    self.scheme = RTScheme.new()
    self.scheme:readStream(streamId, connection)
    self:run(connection)
end

function RTSchemePostSelectionEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTSchemePostSelectionEvent.new(self.scheme))
    end

    if not g_currentMission:getIsServer() then
        local schemeSystem = g_currentMission.RedTape.SchemeSystem
        schemeSystem:storeSelectedSchemeOnClient(self.scheme)
    end
end
