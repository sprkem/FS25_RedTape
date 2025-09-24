-- A payout when a scheme is evaluated
SchemePayoutEvent = {}
local SchemePayoutEvent_mt = Class(SchemePayoutEvent, Event)

InitEventClass(SchemePayoutEvent, "SchemePayoutEvent")

function SchemePayoutEvent.emptyNew()
    local self = Event.new(SchemePayoutEvent_mt)

    return self
end

function SchemePayoutEvent.new(scheme, farmId, amount)
    local self = SchemePayoutEvent.emptyNew()
    self.scheme = scheme
    self.farmId = farmId
    self.amount = amount
    return self
end

function SchemePayoutEvent:writeStream(streamId, connection)
    self.scheme:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteFloat32(streamId, self.amount)
end

function SchemePayoutEvent:readStream(streamId, connection)
    self.scheme = Scheme.new()
    self.scheme:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.amount = streamReadFloat32(streamId)
    self:run(connection)
end

function SchemePayoutEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(SchemePayoutEvent.new(self.scheme, self.farmId, self.amount))
    end

    if g_currentMission:getIsServer() then
        g_currentMission:addMoneyChange(self.amount, self.farmId,
            MoneyType.SCHEME_PAYOUT, true)
    end
    g_farmManager:getFarmById(self.farmId):changeBalance(self.amount, MoneyType.SCHEME_PAYOUT)

    local schemeSystem = g_currentMission.RedTape.EventLog
    local detail = string.format(g_i18n:getText("rt_notify_scheme_payout"), self.scheme:getName(),
        g_i18n:formatMoney(self.amount))
    schemeSystem:addEvent(self.farmId, EventLogItem.EVENT_TYPE.SCHEME_PAYOUT, detail, true)
end
