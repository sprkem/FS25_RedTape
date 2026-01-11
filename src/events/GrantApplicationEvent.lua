RTGrantApplicationEvent = {}
local RTGrantApplicationEvent_mt = Class(RTGrantApplicationEvent, Event)

InitEventClass(RTGrantApplicationEvent, "RTGrantApplicationEvent")

function RTGrantApplicationEvent.emptyNew()
    return Event.new(RTGrantApplicationEvent_mt)
end

function RTGrantApplicationEvent.new(farmId, xmlFile, price, grantId)
    local self = RTGrantApplicationEvent.emptyNew()
    self.farmId = farmId
    self.xmlFile = xmlFile
    self.price = price
    self.grantId = grantId or RedTape.generateId()
    return self
end

function RTGrantApplicationEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteString(streamId, self.xmlFile)
    streamWriteFloat32(streamId, self.price)
    streamWriteString(streamId, self.grantId)
end

function RTGrantApplicationEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.xmlFile = streamReadString(streamId)
    self.price = streamReadFloat32(streamId)
    self.grantId = streamReadString(streamId)
    self:run(connection)
end

function RTGrantApplicationEvent:run(connection)
    -- Server broadcasts to all clients
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTGrantApplicationEvent.new(self.farmId, self.xmlFile, self.price, self.grantId))
    end

    -- Execute the grant application logic
    local grantSystem = g_currentMission.RedTape.GrantSystem
    grantSystem:applyForGrant(self.farmId, self.xmlFile, self.price, self.grantId)
end