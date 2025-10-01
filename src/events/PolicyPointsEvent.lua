PolicyPointsEvent = {}
local PolicyPointsEvent_mt = Class(PolicyPointsEvent, Event)

InitEventClass(PolicyPointsEvent, "PolicyPointsEvent")

function PolicyPointsEvent.emptyNew()
    local self = Event.new(PolicyPointsEvent_mt)

    return self
end

function PolicyPointsEvent.new(farmId, pointChange, policyName)
    local self = PolicyPointsEvent.emptyNew()
    self.farmId = farmId
    self.pointChange = pointChange
    self.policyName = policyName
    return self
end

function PolicyPointsEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.farmId)
    streamWriteInt32(streamId, self.pointChange)
    streamWriteString(streamId, self.policyName)
end

function PolicyPointsEvent:readStream(streamId, connection)
    self.farmId = streamReadString(streamId)
    self.pointChange = streamReadInt32(streamId)
    self.policyName = streamReadString(streamId)

    self:run(connection)
end

function PolicyPointsEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(PolicyPointsEvent.new(self.farmId, self.pointChange, self.policyName))
    end

    local reason = string.format(g_i18n:getText("rt_policy_reason_evaluation"), self.pointChange, self.policyName)
    g_currentMission.RedTape.PolicySystem:applyPoints(self.farmId, self.pointChange, reason)
end
