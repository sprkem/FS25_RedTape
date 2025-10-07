SchemeNoLongerAvailableEvent = {}
local SchemeNoLongerAvailableEvent_mt = Class(SchemeNoLongerAvailableEvent, Event)

InitEventClass(SchemeNoLongerAvailableEvent, "SchemeNoLongerAvailableEvent")

function SchemeNoLongerAvailableEvent.emptyNew()
    local self = Event.new(SchemeNoLongerAvailableEvent_mt)

    return self
end

function SchemeNoLongerAvailableEvent.new(id)
    local self = SchemeNoLongerAvailableEvent.emptyNew()
    self.id = id
    return self
end

function SchemeNoLongerAvailableEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
end

function SchemeNoLongerAvailableEvent:readStream(streamId, connection)
    self.id = streamReadString(streamId)
    self:run(connection)
end

function SchemeNoLongerAvailableEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(SchemeNoLongerAvailableEvent.new(self.id))
    end

    local schemeSystem = g_currentMission.RedTape.SchemeSystem
    schemeSystem:removeAvailableScheme(self.id)
end
