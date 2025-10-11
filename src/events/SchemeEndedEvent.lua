SchemeEndedEvent = {}
local SchemeEndedEvent_mt = Class(SchemeEndedEvent, Event)

InitEventClass(SchemeEndedEvent, "SchemeEndedEvent")

function SchemeEndedEvent.emptyNew()
    local self = Event.new(SchemeEndedEvent_mt)

    return self
end

function SchemeEndedEvent.new(id, farmId)
    local self = SchemeEndedEvent.emptyNew()
    self.id = id
    self.farmId = farmId
    return self
end

function SchemeEndedEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
    streamWriteInt32(streamId, self.farmId)
end

function SchemeEndedEvent:readStream(streamId, connection)
    self.id = streamReadString(streamId)
    self.farmId = streamReadInt32(streamId)
    self:run(connection)
end

function SchemeEndedEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(SchemeEndedEvent.new(self.id, self.farmId))
    end

    local schemeSystem = g_currentMission.RedTape.SchemeSystem
    schemeSystem:endActiveScheme(self.id, self.farmId)
end
