-- ============================================================= --
-- RED TAPE SETTINGS EVENT
-- ============================================================= --
RedTapeSettingsEvent = {}
RedTapeSettingsEvent_mt = Class(RedTapeSettingsEvent, Event)

InitEventClass(RedTapeSettingsEvent, "RedTapeSettingsEvent")

function RedTapeSettingsEvent.emptyNew()
	local self = Event.new(RedTapeSettingsEvent_mt)
	return self
end

function RedTapeSettingsEvent.new(taxEnabled, policiesAndSchemesEnabled, baseTaxRate)
	local self = RedTapeSettingsEvent.emptyNew()
	self.taxEnabled = taxEnabled
	self.policiesAndSchemesEnabled = policiesAndSchemesEnabled
	self.baseTaxRate = baseTaxRate
	return self
end

function RedTapeSettingsEvent:readStream(streamId, connection)
	self.taxEnabled = streamReadBool(streamId)
	self.policiesAndSchemesEnabled = streamReadBool(streamId)
	self.baseTaxRate = streamReadFloat32(streamId)

	-- Update local values
	RedTape.taxEnabled = self.taxEnabled
	RedTape.policiesAndSchemesEnabled = self.policiesAndSchemesEnabled
	RedTape.baseTaxRate = self.baseTaxRate

	if connection:getIsServer() then
		-- Update UI controls if they exist
		for _, id in pairs(RedTape.menuItems) do
			local menuOption = RedTape.CONTROLS[id]
			if menuOption then
				local isAdmin = g_currentMission:getIsServer() or g_currentMission.isMasterUser
				menuOption:setState(RedTape.getStateIndex(id))
				menuOption:setDisabled(not isAdmin)
			end
		end
	else
		-- Server received from client, broadcast to all clients
		RedTapeSettingsEvent.sendEvent(self.taxEnabled, self.policiesAndSchemesEnabled, self.baseTaxRate)
	end
end

function RedTapeSettingsEvent:writeStream(streamId, connection)
	local taxEnabled = RedTape.taxEnabled or false
	local policiesAndSchemesEnabled = RedTape.policiesAndSchemesEnabled or false
	local baseTaxRate = RedTape.baseTaxRate or 20

	streamWriteBool(streamId, taxEnabled)
	streamWriteBool(streamId, policiesAndSchemesEnabled)
	streamWriteFloat32(streamId, baseTaxRate)
end

function RedTapeSettingsEvent.sendEvent(taxEnabled, policiesAndSchemesEnabled, baseTaxRate, noEventSend)
	if noEventSend == nil or noEventSend == false then
		-- Use current values if not provided
		taxEnabled = taxEnabled or RedTape.taxEnabled or RedTape.SETTINGS.taxEnabled['default']
		policiesAndSchemesEnabled = policiesAndSchemesEnabled or RedTape.policiesAndSchemesEnabled or RedTape.SETTINGS.policiesAndSchemesEnabled['default']
		baseTaxRate = baseTaxRate or RedTape.baseTaxRate or RedTape.SETTINGS.baseTaxRate['default']

		if g_server ~= nil then
			-- Server broadcasting to all clients
			g_server:broadcastEvent(RedTapeSettingsEvent.new(taxEnabled, policiesAndSchemesEnabled, baseTaxRate), false)
		else
			-- Client sending to server
			g_client:getServerConnection():sendEvent(RedTapeSettingsEvent.new(taxEnabled, policiesAndSchemesEnabled,
				baseTaxRate))
		end
	end
end
