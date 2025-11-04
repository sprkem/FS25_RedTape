RTPolicyWarningEvent = {}
local RTPolicyWarningEvent_mt = Class(RTPolicyWarningEvent, Event)

InitEventClass(RTPolicyWarningEvent, "RTPolicyWarningEvent")

function RTPolicyWarningEvent.emptyNew()
    local self = Event.new(RTPolicyWarningEvent_mt)

    return self
end

function RTPolicyWarningEvent.new(farmId, policyIndex)
    local self = RTPolicyWarningEvent.emptyNew()
    self.farmId = farmId
    self.policyIndex = policyIndex
    return self
end

function RTPolicyWarningEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.policyIndex)
end

function RTPolicyWarningEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.policyIndex = streamReadInt32(streamId)

    self:run(connection)
end

function RTPolicyWarningEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTPolicyWarningEvent.new(self.farmId, self.policyIndex))
    end

    g_currentMission.RedTape.PolicySystem:recordWarning(self.farmId, self.policyIndex)
end
