-- A payout when a scheme is evaluated
RTTaxStatementPaidEvent = {}
local RTTaxStatementPaidEvent_mt = Class(RTTaxStatementPaidEvent, Event)

InitEventClass(RTTaxStatementPaidEvent, "RTTaxStatementPaidEvent")

function RTTaxStatementPaidEvent.emptyNew()
    local self = Event.new(RTTaxStatementPaidEvent_mt)

    return self
end

function RTTaxStatementPaidEvent.new(farmId, amountPaid)
    local self = RTTaxStatementPaidEvent.emptyNew()
    self.farmId = farmId
    self.amountPaid = amountPaid
    return self
end

function RTTaxStatementPaidEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteFloat32(streamId, self.amountPaid)
end

function RTTaxStatementPaidEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.amountPaid = streamReadFloat32(streamId)
    self:run(connection)
end

function RTTaxStatementPaidEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTTaxStatementPaidEvent.new(self.farmId, self.amountPaid))
    end

    local taxSystem = g_currentMission.RedTape.TaxSystem
    taxSystem:markTaxStatementAsPaid(self.farmId, self.amountPaid)
    g_farmManager:getFarmById(self.farmId):changeBalance(-self.amountPaid, MoneyType.TAX_PAID)
end
