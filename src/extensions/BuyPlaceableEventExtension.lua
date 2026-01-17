RTBuyPlaceableEventExtension = {}

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
