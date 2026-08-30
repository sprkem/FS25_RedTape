RTCropRotationResetEvent = {}
local RTCropRotationResetEvent_mt = Class(RTCropRotationResetEvent, Event)

InitEventClass(RTCropRotationResetEvent, "RTCropRotationResetEvent")

function RTCropRotationResetEvent.emptyNew()
    return Event.new(RTCropRotationResetEvent_mt)
end

function RTCropRotationResetEvent.new()
    return RTCropRotationResetEvent.emptyNew()
end

-- No payload: the reset always clears every farmland.
function RTCropRotationResetEvent:writeStream(streamId, connection)
end

function RTCropRotationResetEvent:readStream(streamId, connection)
    self:run(connection)
end

function RTCropRotationResetEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTCropRotationResetEvent.new())
    end

    local infoGatherer = g_currentMission.RedTape.InfoGatherer
    infoGatherer.gatherers[INFO_KEYS.FARMLANDS]:resetCropRotationHistory()

    g_messageCenter:publish(MessageType.RT_DATA_UPDATED)
end
