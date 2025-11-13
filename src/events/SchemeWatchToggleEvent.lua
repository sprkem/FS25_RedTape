-- A selected scheme is when a scheme is chosen by a farm
RTSchemeWatchToggleEvent = {}
local RTSchemeWatchToggleEvent_mt = Class(RTSchemeWatchToggleEvent, Event)

InitEventClass(RTSchemeWatchToggleEvent, "RTSchemeWatchToggleEvent")

function RTSchemeWatchToggleEvent.emptyNew()
    local self = Event.new(RTSchemeWatchToggleEvent_mt)

    return self
end

function RTSchemeWatchToggleEvent.new(schemeId)
    local self = RTSchemeWatchToggleEvent.emptyNew()
    self.id = schemeId
    return self
end

function RTSchemeWatchToggleEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
end

function RTSchemeWatchToggleEvent:readStream(streamId, connection)
    self.id = streamReadString(streamId)
    self:run(connection)
end

function RTSchemeWatchToggleEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTSchemeWatchToggleEvent.new(self.id))
    end

    local schemeSystem = g_currentMission.RedTape.SchemeSystem
    for _, schemes in pairs(schemeSystem.activeSchemesByFarm) do
        for _, scheme in pairs(schemes) do
            if scheme.id == self.id then
                scheme.watched = not scheme.watched
                break
            end
        end
    end
    g_messageCenter:publish(MessageType.SCHEMES_UPDATED)
end
