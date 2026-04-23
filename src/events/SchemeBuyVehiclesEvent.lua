RTSchemeBuyVehiclesEvent = {}
local RTSchemeBuyVehiclesEvent_mt = Class(RTSchemeBuyVehiclesEvent, Event)

InitEventClass(RTSchemeBuyVehiclesEvent, "RTSchemeBuyVehiclesEvent")

function RTSchemeBuyVehiclesEvent.emptyNew()
    local self = Event.new(RTSchemeBuyVehiclesEvent_mt)
    return self
end

function RTSchemeBuyVehiclesEvent.new(schemeId, farmId, price)
    local self = RTSchemeBuyVehiclesEvent.emptyNew()
    self.schemeId = schemeId
    self.farmId = farmId
    self.price = price
    return self
end

function RTSchemeBuyVehiclesEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.schemeId)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.price)
end

function RTSchemeBuyVehiclesEvent:readStream(streamId, connection)
    self.schemeId = streamReadString(streamId)
    self.farmId = streamReadInt32(streamId)
    self.price = streamReadInt32(streamId)
    self:run(connection)
end

function RTSchemeBuyVehiclesEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTSchemeBuyVehiclesEvent.new(self.schemeId, self.farmId, self.price))
    end

    local schemeSystem = g_currentMission.RedTape.SchemeSystem
    local activeSchemes = schemeSystem:getActiveSchemesForFarm(self.farmId)

    for _, scheme in pairs(activeSchemes) do
        if scheme.id == self.schemeId then
            local schemeInfo = RTSchemes[scheme.schemeIndex]
            if schemeInfo ~= nil and schemeInfo.action ~= nil and schemeInfo.action.confirm ~= nil then
                schemeInfo.action.confirm(schemeInfo, scheme, self.price)
            end
            return
        end
    end
end
