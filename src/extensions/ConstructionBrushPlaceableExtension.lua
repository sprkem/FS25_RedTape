RTConstructionBrushPlaceableExtension = {}

function RTConstructionBrushPlaceableExtension:verifyPlacement(superFunc, x, y, z, rotY)
    local result = superFunc(self, x, y, z, rotY)

    if result == ConstructionBrushPlaceable.ERROR.NOT_ENOUGH_MONEY then
        local currentFarmId = g_currentMission:getFarmId()
        local price = self:getPrice()
        local balance = g_currentMission:getMoney()
        local xmlFilename = self.storeItem.xmlFilename

        local grantSystem = g_currentMission.RedTape.GrantSystem
        local grant = grantSystem:getApprovedGrantByXmlFilename(currentFarmId, xmlFilename)

        if grant ~= nil then
            if balance + grant.amount >= price then
                return nil
            end
        end
    end

    return result
end

ConstructionBrushPlaceable.verifyPlacement = Utils.overwrittenFunction(ConstructionBrushPlaceable.verifyPlacement,
    RTConstructionBrushPlaceableExtension.verifyPlacement)
