RTConstructionScreenExtension = {}

function RTConstructionScreenExtension:setBrush(brush, skipMenuUpdate)
    local grantSystem = g_currentMission.RedTape.GrantSystem
    local grantsEnabled = grantSystem:isEnabled()

    local sourceButton = self.buttonBack
    local grantsButton = self.dealsButton

    -- If system is disabled, delete the button if it exists
    if not grantsEnabled then
        if grantsButton ~= nil then
            grantsButton:delete()
            self.dealsButton = nil
        end
        return
    end

    -- System is enabled, create button if it doesn't exist
    if not grantsButton and sourceButton then
        local parent = sourceButton.parent
        grantsButton = sourceButton:clone(parent)
        grantsButton.name = "dealsButton"
        grantsButton.inputActionName = "MENU_ACCEPT"
        self.dealsButton = grantsButton
    end

    if grantsButton ~= nil then
        local showGrantButton = RTConstructionScreenExtension.getGrantButtonVisibility(brush)
        grantsButton:setDisabled(not showGrantButton)

        grantsButton.onClick = "onClickGrantButton"
        grantsButton:setText(g_i18n:getText("rt_grant_button"))

        self.onClickGrantButton = function()
            local farmId = g_currentMission:getFarmId()
            local grantSystem = g_currentMission.RedTape.GrantSystem
            local farmGrants = grantSystem:getGrantsForFarm(farmId)
            local hasActiveApplications = #farmGrants.pending > 0

            if hasActiveApplications then
                InfoDialog.show(g_i18n:getText("rt_grant_existing_application"))
            else
                local dText = string.format(g_i18n:getText("rt_grant_confirm_application_dialog"),
                    g_i18n:formatMoney(RTGrantSystem.APPLICATION_COST, 0, true, true))
                YesNoDialog.show(
                    function(self, clickOk)
                        if clickOk then
                            local price = brush.storeItem.price
                            g_client:getServerConnection():sendEvent(RTGrantApplicationEvent.new(farmId,
                                brush.storeItem.xmlFilename, price))
                            InfoDialog.show(g_i18n:getText("rt_grant_application_submitted"))
                        end
                    end, self,
                    dText)
            end
        end

        grantsButton.onClickCallback = self.onClickGrantButton
    end
end

ConstructionScreen.setBrush = Utils.prependedFunction(ConstructionScreen.setBrush,
    RTConstructionScreenExtension.setBrush)

function RTConstructionScreenExtension.getGrantButtonVisibility(brush)
    if not brush then return false end

    local storeItem = brush.storeItem

    if storeItem == nil then
        return false
    end

    if not RedTape.tableHasKey(RTGrantSystem.ALLOWED_CATEGORIES, storeItem.categoryName) then
        return false
    end

    if storeItem.price < RTGrantSystem.MIN_PRICE_FOR_GRANT then
        return false
    end

    -- Check if farm is allowed to apply for new grants (cooldown check)
    local farmId = g_currentMission:getFarmId()
    local grantSystem = g_currentMission.RedTape.GrantSystem
    if not grantSystem:canFarmApplyForGrant(farmId) then
        return false
    end

    return true
end
