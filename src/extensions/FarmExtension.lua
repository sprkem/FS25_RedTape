RTFarmExtension = {}

function RTFarmExtension.changeBalance(farm, amount, moneyType)
    if g_currentMission:getIsServer() then
        if moneyType == nil then
            return
        end

        local farmId = farm.farmId
        local statistic = moneyType.statistic

        local lineItem = RTTaxLineItem.new()
        lineItem.amount = amount
        lineItem.statistic = statistic

        g_client:getServerConnection():sendEvent(RTNewTaxLineItemEvent.new(farmId, lineItem))
    end
end

