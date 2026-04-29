RTFarmExtension = {}
RTFarmExtension.INCLUDED_OTHER_TYPES = {
    "info_samplesAnalysed",
    "info_environmentalScoreReward",
    "info_environmentalScorePenalty",
    "info_subsidiesCoverCrop",
    "finance_purchaseFuel"
}

function RTFarmExtension.changeBalance(farm, amount, moneyType)
    if g_currentMission:getIsServer() then
        if moneyType == nil then
            return
        end

        if moneyType.statistic == "other" and not RedTape.tableHasValue(RTFarmExtension.INCLUDED_OTHER_TYPES, moneyType.name) then
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

