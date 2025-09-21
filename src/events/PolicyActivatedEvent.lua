PolicyActivatedEvent = {}
local PolicyActivatedEvent_mt = Class(PolicyActivatedEvent, Event)

InitEventClass(PolicyActivatedEvent, "PolicyActivatedEvent")

function PolicyActivatedEvent.emptyNew()
    local self = Event.new(PolicyActivatedEvent_mt)

    return self
end

function PolicyActivatedEvent.new(policy)
    local self = PolicyActivatedEvent.emptyNew()
    self.policy = policy
    return self
end

function PolicyActivatedEvent:writeStream(streamId, connection)
    self.policy:writeStream(streamId, connection)
end

function PolicyActivatedEvent:readStream(streamId, connection)
    self.policy = Policy.new()
    self.policy:readStream(streamId, connection)
    self:run(connection)
end

function PolicyActivatedEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(PolicyActivatedEvent.new(self.policy))
    end

    local policySystem = g_currentMission.RedTape.PolicySystem
    policySystem:registerActivatedPolicy(self.policy, false)
end
