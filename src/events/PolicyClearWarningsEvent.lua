RTPolicyClearWarningsEvent = {}
local RTPolicyClearWarningsEvent_mt = Class(RTPolicyClearWarningsEvent, Event)

InitEventClass(RTPolicyClearWarningsEvent, "RTPolicyClearWarningsEvent")

function RTPolicyClearWarningsEvent.emptyNew()
    local self = Event.new(RTPolicyClearWarningsEvent_mt)

    return self
end

function RTPolicyClearWarningsEvent.new(farmId, policyIndex)
    local self = RTPolicyClearWarningsEvent.emptyNew()
    self.farmId = farmId
    self.policyIndex = policyIndex
    return self
end

function RTPolicyClearWarningsEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.policyIndex)
end

function RTPolicyClearWarningsEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.policyIndex = streamReadInt32(streamId)

    self:run(connection)
end

function RTPolicyClearWarningsEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTPolicyClearWarningsEvent.new(self.farmId, self.policyIndex))
    end

    g_currentMission.RedTape.PolicySystem:clearWarning(self.farmId, self.policyIndex)
end
