-- A selected scheme is when a scheme is chosen by a farm
RTPolicyWatchToggleEvent = {}
local RTPolicyWatchToggleEvent_mt = Class(RTPolicyWatchToggleEvent, Event)

InitEventClass(RTPolicyWatchToggleEvent, "RTPolicyWatchToggleEvent")

function RTPolicyWatchToggleEvent.emptyNew()
    local self = Event.new(RTPolicyWatchToggleEvent_mt)

    return self
end

function RTPolicyWatchToggleEvent.new(policyId, farmId)
    local self = RTPolicyWatchToggleEvent.emptyNew()
    self.id = policyId
    self.farmId = farmId
    return self
end

function RTPolicyWatchToggleEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
    streamWriteInt32(streamId, self.farmId)
end

function RTPolicyWatchToggleEvent:readStream(streamId, connection)
    self.id = streamReadString(streamId)
    self.farmId = streamReadInt32(streamId)
    self:run(connection)
end

function RTPolicyWatchToggleEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTPolicyWatchToggleEvent.new(self.id, self.farmId))
    end

    local policySystem = g_currentMission.RedTape.PolicySystem
    for _, policy in pairs(policySystem.policies) do
        if policy.id == self.id then
            policy:setBeingWatchedByFarm(self.farmId, not policy:isBeingWatchedByFarm(self.farmId))
            break
        end
    end
    g_messageCenter:publish(MessageType.POLICIES_UPDATED)
end
