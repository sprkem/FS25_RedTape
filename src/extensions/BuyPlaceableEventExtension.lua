RTBuyPlaceableEventExtension = {}

-- Local values: buyData, totalCosts
function RTBuyPlaceableEventExtension:run(superFunc, connection)
    if connection:getIsServer() then
        g_messageCenter:publish(BuyPlaceableEvent, self.errorCode, self.price, self.objectId)
        return
    else
        local buyData = self.placeableBuyData
        if g_currentMission:getHasPlayerPermission(Farm.PERMISSION.BUY_PLACEABLE, connection) then
            if buyData:isValid() then
                local grantSystem = g_currentMission.RedTape.GrantSystem
                local grant = grantSystem:getApprovedGrantByXmlFilename(buyData.ownerFarmId,
                    buyData.storeItem.xmlFilename)

                local totalCosts = buyData.price + buyData.displacementCosts

                if grant ~= nil then
                    totalCosts = totalCosts - grant.amount
                end

                if buyData.isFreeOfCharge or g_currentMission:getMoney(buyData.ownerFarmId) >= totalCosts then
                    buyData:buy(self.onPlaceableBoughtCallback, self, {
                        ["connection"] = connection
                    })
                else
                    connection:sendEvent(BuyPlaceableEvent.newServerToClient(BuyPlaceableEvent.STATE_NOT_ENOUGH_MONEY,
                        buyData))
                end
            else
                connection:sendEvent(BuyPlaceableEvent.newServerToClient(BuyPlaceableEvent.STATE_FAILED_TO_LOAD, buyData))
                return
            end
        else
            connection:sendEvent(BuyPlaceableEvent.newServerToClient(BuyPlaceableEvent.STATE_NO_PERMISSION, buyData))
            return
        end
    end
end

BuyPlaceableEvent.run = Utils.overwrittenFunction(BuyPlaceableEvent.run,
    RTBuyPlaceableEventExtension.run)

function RTBuyPlaceableEventExtension:onPlaceableBoughtCallback(placeable, loadingState, arguments)
    if loadingState == PlaceableLoadingState.OK then
        local xmlFilename = placeable.xmlFile.filename
        local farmId = placeable:getOwnerFarmId()

        local grantSystem = g_currentMission.RedTape.GrantSystem
        if grantSystem and grantSystem:isEnabled() then
            grantSystem:onPlaceablePurchased(farmId, xmlFilename)
        end
    end
end

BuyPlaceableEvent.onPlaceableBoughtCallback = Utils.appendedFunction(BuyPlaceableEvent.onPlaceableBoughtCallback,
    RTBuyPlaceableEventExtension.onPlaceableBoughtCallback)
