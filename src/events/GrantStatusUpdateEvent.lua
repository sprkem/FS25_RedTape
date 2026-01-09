RTGrantStatusUpdateEvent = {}
local RTGrantStatusUpdateEvent_mt = Class(RTGrantStatusUpdateEvent, Event)

InitEventClass(RTGrantStatusUpdateEvent, "RTGrantStatusUpdateEvent")

function RTGrantStatusUpdateEvent.emptyNew()
    return Event.new(RTGrantStatusUpdateEvent_mt)
end

function RTGrantStatusUpdateEvent.new(farmId, grantId, newStatus, approvedAmount)
    local self = RTGrantStatusUpdateEvent.emptyNew()
    self.farmId = farmId
    self.grantId = grantId
    self.newStatus = newStatus
    self.approvedAmount = approvedAmount or 0
    return self
end

function RTGrantStatusUpdateEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteString(streamId, self.grantId)
    streamWriteInt32(streamId, self.newStatus)
    streamWriteFloat32(streamId, self.approvedAmount)
end

function RTGrantStatusUpdateEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.grantId = streamReadString(streamId)
    self.newStatus = streamReadInt32(streamId)
    self.approvedAmount = streamReadFloat32(streamId)
    self:run(connection)
end

function RTGrantStatusUpdateEvent:run(connection)
    -- Server broadcasts to all clients
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTGrantStatusUpdateEvent.new(self.farmId, self.grantId, self.newStatus, self.approvedAmount))
    end

    -- Execute the grant status update logic
    local grantSystem = g_currentMission.RedTape.GrantSystem
    -- Status update logic will be implemented later
end