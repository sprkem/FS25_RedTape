-- A payout when a scheme is evaluated
RTTaxRateBenefitEvent = {}
local RTTaxRateBenefitEvent_mt = Class(RTTaxRateBenefitEvent, Event)

InitEventClass(RTTaxRateBenefitEvent, "RTTaxRateBenefitEvent")

function RTTaxRateBenefitEvent.emptyNew()
    local self = Event.new(RTTaxRateBenefitEvent_mt)

    return self
end

function RTTaxRateBenefitEvent.new(farmId, startMonth, endMonth, statistic, taxedAmountModifier)
    local self = RTTaxRateBenefitEvent.emptyNew()
    self.farmId = farmId
    self.start = startMonth
    self.endMonth = endMonth
    self.statistic = statistic
    self.taxedAmountModifier = taxedAmountModifier
    return self
end

function RTTaxRateBenefitEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.start)
    streamWriteInt32(streamId, self.endMonth)
    streamWriteString(streamId, self.statistic)
    streamWriteFloat32(streamId, self.taxedAmountModifier)
end

function RTTaxRateBenefitEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.start = streamReadInt32(streamId)
    self.endMonth = streamReadInt32(streamId)
    self.statistic = streamReadString(streamId)
    self.taxedAmountModifier = streamReadFloat32(streamId)
    self:run(connection)
end

function RTTaxRateBenefitEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTTaxRateBenefitEvent.new(self.farmId, self.start, self.endMonth, self.statistic, self.taxedAmountModifier))
    end

    local taxSystem = g_currentMission.RedTape.TaxSystem
    taxSystem:recordCustomTaxRateBenefit(self.farmId, self.start, self.endMonth, self.statistic, self.taxedAmountModifier)
end
