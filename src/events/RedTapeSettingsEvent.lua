RTSettingsEvent = {}
RTSettingsEvent_mt = Class(RTSettingsEvent, Event)

InitEventClass(RTSettingsEvent, "RedTapeSettingsEvent")

function RTSettingsEvent.emptyNew()
    local self = Event.new(RTSettingsEvent_mt)
    return self
end

function RTSettingsEvent.new(taxEnabled, policiesAndSchemesEnabled, baseTaxRate)
    local self = RTSettingsEvent.emptyNew()
    self.taxEnabled = taxEnabled
    self.policiesAndSchemesEnabled = policiesAndSchemesEnabled
    self.baseTaxRate = baseTaxRate
    return self
end

function RTSettingsEvent:writeStream(streamId, connection)
    local taxEnabled = RedTape.taxEnabled or false
    local policiesAndSchemesEnabled = RedTape.policiesAndSchemesEnabled or false
    local baseTaxRate = RedTape.baseTaxRate or 20

    streamWriteBool(streamId, taxEnabled)
    streamWriteBool(streamId, policiesAndSchemesEnabled)
    streamWriteFloat32(streamId, baseTaxRate)
end

function RTSettingsEvent:readStream(streamId, connection)
    self.taxEnabled = streamReadBool(streamId)
    self.policiesAndSchemesEnabled = streamReadBool(streamId)
    self.baseTaxRate = streamReadFloat32(streamId)
end

function RTSettingsEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTSettingsEvent.new())
    end

    RedTape.taxEnabled = self.taxEnabled
    RedTape.policiesAndSchemesEnabled = self.policiesAndSchemesEnabled
    RedTape.baseTaxRate = self.baseTaxRate

    if not connection:getIsServer() then
        if (not RedTape.policiesAndSchemesEnabled) then
            g_currentMission.RedTape.PolicySystem:onDisabled()
            g_currentMission.RedTape.SchemeSystem:onDisabled()
        end
    else
        -- Update UI controls if they exist
        for _, id in pairs(RedTape.menuItems) do
            local menuOption = RedTape.CONTROLS[id]
            if menuOption then
                local isAdmin = g_currentMission:getIsServer() or g_currentMission.isMasterUser
                menuOption:setState(RedTape.getStateIndex(id))
                menuOption:setDisabled(not isAdmin)
            end
        end
    end
end
