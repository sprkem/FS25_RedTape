-- A selected scheme is when a scheme is chosen by a farm
RTSchemeSelectedEvent = {}
local RTSchemeSelectedEvent_mt = Class(RTSchemeSelectedEvent, Event)

InitEventClass(RTSchemeSelectedEvent, "SchemeSelectedEvent")

function RTSchemeSelectedEvent.emptyNew()
    local self = Event.new(RTSchemeSelectedEvent_mt)

    return self
end

function RTSchemeSelectedEvent.new(scheme, farmId)
    local self = RTSchemeSelectedEvent.emptyNew()
    self.scheme = scheme
    self.farmId = farmId
    return self
end

function RTSchemeSelectedEvent:writeStream(streamId, connection)
    self.scheme:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
end

function RTSchemeSelectedEvent:readStream(streamId, connection)
    self.scheme = RTScheme.new()
    self.scheme:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self:run(connection)
end

function RTSchemeSelectedEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTSchemeSelectedEvent.new(self.scheme, self.farmId))
    end

    local schemeSystem = g_currentMission.RedTape.SchemeSystem
    schemeSystem:registerSelectedScheme(self.scheme, self.farmId)
end
