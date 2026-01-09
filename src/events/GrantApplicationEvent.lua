RTGrantApplicationEvent = {}
local RTGrantApplicationEvent_mt = Class(RTGrantApplicationEvent, Event)

InitEventClass(RTGrantApplicationEvent, "RTGrantApplicationEvent")

function RTGrantApplicationEvent.emptyNew()
    return Event.new(RTGrantApplicationEvent_mt)
end

function RTGrantApplicationEvent.new(farmId, grantType, requestedAmount)
    local self = RTGrantApplicationEvent.emptyNew()
    self.farmId = farmId
    self.grantType = grantType
    self.requestedAmount = requestedAmount
    return self
end

function RTGrantApplicationEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteString(streamId, self.grantType)
    streamWriteFloat32(streamId, self.requestedAmount)
end

function RTGrantApplicationEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.grantType = streamReadString(streamId)
    self.requestedAmount = streamReadFloat32(streamId)
    self:run(connection)
end

function RTGrantApplicationEvent:run(connection)
    -- Server broadcasts to all clients
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTGrantApplicationEvent.new(self.farmId, self.grantType, self.requestedAmount))
    end

    -- Execute the grant application logic
    local grantSystem = g_currentMission.RedTape.GrantSystem
    grantSystem:applyForGrant(self.farmId, self.grantType, self.requestedAmount)
end