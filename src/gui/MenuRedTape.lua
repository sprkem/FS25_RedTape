MenuRedTape = {}
MenuRedTape.currentTasks = {}
MenuRedTape._mt = Class(MenuRedTape, TabbedMenuFrameElement)

MenuRedTape.SUB_CATEGORY = {
    ["OVERVIEW"] = 1,
    ["POLICIES"] = 2,
    ["SCHEMES"] = 3,
    ["TAX"] = 4,
    ["EVENTLOG"] = 5
}

MenuRedTape.HEADER_SLICES = {
    [MenuRedTape.SUB_CATEGORY.OVERVIEW] = "gui.icon_ingameMenu_prices",
    [MenuRedTape.SUB_CATEGORY.POLICIES] = "gui.icon_vehicleDealer_machines",
    [MenuRedTape.SUB_CATEGORY.SCHEMES] = "gui.icon_ingameMenu_handToolsOverview",
    [MenuRedTape.SUB_CATEGORY.TAX] = "gui.icon_ingameMenu_finances",
    [MenuRedTape.SUB_CATEGORY.EVENTLOG] = "gui.icon_ingameMenu_finances",
}
MenuRedTape.HEADER_TITLES = {
    [MenuRedTape.SUB_CATEGORY.OVERVIEW] = "rt_header_overview",
    [MenuRedTape.SUB_CATEGORY.POLICIES] = "rt_header_policies",
    [MenuRedTape.SUB_CATEGORY.SCHEMES] = "rt_header_schemes",
    [MenuRedTape.SUB_CATEGORY.TAX] = "rt_header_tax",
    [MenuRedTape.SUB_CATEGORY.EVENTLOG] = "rt_header_eventlog",
}

function MenuRedTape.new(i18n, messageCenter)
    local self = MenuRedTape:superClass().new(nil, MenuRedTape._mt)
    self.name = "MenuRedTape"
    self.i18n = i18n
    self.messageCenter = messageCenter

    self.eventLogRenderer = EventLogRenderer.new(self)
    self.activePoliciesRenderer = ActivePoliciesRenderer.new(self)

    return self
end

function MenuRedTape:onGuiSetupFinished()
    MenuRedTape:superClass().onGuiSetupFinished(self)

    self.farmEventsTable:setDataSource(self.eventLogRenderer)
    self.farmEventsTable:setDelegate(self.eventLogRenderer)

    self.activePoliciesTable:setDataSource(self.activePoliciesRenderer)
    self.activePoliciesTable:setDelegate(self.activePoliciesRenderer)
end

function MenuRedTape:initialize()
    MenuRedTape:superClass().initialize(self)
    for i, tab in pairs(self.subCategoryTabs) do
        tab:getDescendantByName("background").getIsSelected = function()
            return i == self.subCategoryPaging:getState()
        end
        function tab.getIsSelected()
            return i == self.subCategoryPaging:getState()
        end
    end
end

function MenuRedTape:onFrameOpen()
    local xmlFile = loadXMLFile("Temp", "dataS/gui/InGameMenuContractsFrame.xml")
    saveXMLFileTo(xmlFile, g_currentMission.missionInfo.savegameDirectory .. "/InGameMenuContractsFrame.xml")
    delete(xmlFile);

    -- local isMultiplayer = g_currentMission.missionDynamicInfo.isMultiplayer
    -- local v46_ = not isMultiplayer or g_localPlayer.farmId ~= FarmManager.SPECTATOR_FARM_ID
    local texts = {}
    for k, tab in pairs(self.subCategoryTabs) do
        tab:setVisible(true)
        table.insert(texts, tostring(k))
    end
    self.subCategoryBox:invalidateLayout()
    self.subCategoryPaging:setTexts(texts)
    self.subCategoryPaging:setSize(self.subCategoryBox.maxFlowSize + 140 * g_pixelSizeScaledX)

    self:onMoneyChange()
    g_messageCenter:subscribe(MessageType.MONEY_CHANGED, self.onMoneyChange, self)

    g_messageCenter:subscribe(MessageType.EVENT_LOG_UPDATED, function(menu)
        self:updateContent()
    end, self)
    self:updateContent()
    FocusManager:setFocus(self.subCategoryPaging)
end

function MenuRedTape:onFrameClose()
    MenuRedTape:superClass().onFrameClose(self)
    g_messageCenter:unsubscribeAll(self)
end

function MenuRedTape:onClickOverview()
    self.subCategoryPaging:setState(MenuRedTape.SUB_CATEGORY.OVERVIEW, true)
end

function MenuRedTape:onClickPolicies()
    self.subCategoryPaging:setState(MenuRedTape.SUB_CATEGORY.POLICIES, true)
end

function MenuRedTape:onClickSchemes()
    self.subCategoryPaging:setState(MenuRedTape.SUB_CATEGORY.SCHEMES, true)
end

function MenuRedTape:onClickTax()
    self.subCategoryPaging:setState(MenuRedTape.SUB_CATEGORY.TAX, true)
end

function MenuRedTape:onClickEventLog()
    self.subCategoryPaging:setState(MenuRedTape.SUB_CATEGORY.EVENTLOG, true)
end

function MenuRedTape:updateSubCategoryPages(subCategoryIndex)
    self:updateContent()
    FocusManager:setFocus(self.subCategoryPaging)
end

function MenuRedTape:updateContent()
    local state = self.subCategoryPaging:getState()

    self.categoryHeaderIcon:setImageSlice(nil, MenuRedTape.HEADER_SLICES[state])
    self.categoryHeaderText:setText(g_i18n:getText(MenuRedTape.HEADER_TITLES[state]))

    for k, v in pairs(self.subCategoryPages) do
        v:setVisible(k == state)
    end

    if state == MenuRedTape.SUB_CATEGORY.OVERVIEW then
        print("Overview sub-category selected")
    elseif state == MenuRedTape.SUB_CATEGORY.POLICIES then
        local activePolicies = g_currentMission.RedTape.PolicySystem.policies

        if #activePolicies == 0 then
            self.activePoliciesContainer:setVisible(false)
            self.noActivePoliciesContainer:setVisible(true)
            return
        end

        self.activePoliciesContainer:setVisible(true)
        self.noActivePoliciesContainer:setVisible(false)

        self.activePoliciesRenderer:setData(activePolicies)
        self.activePoliciesTable:reloadData()
    elseif state == MenuRedTape.SUB_CATEGORY.SCHEMES then
        print("Schemes sub-category selected")
    elseif state == MenuRedTape.SUB_CATEGORY.EVENTLOG then
        local farmEvents = g_currentMission.RedTape.EventLog:getEventsForCurrentFarm()

        if #farmEvents == 0 then
            self.farmEventsContainer:setVisible(false)
            self.noFarmEventsContainer:setVisible(true)
            return
        end

        self.farmEventsContainer:setVisible(true)
        self.noFarmEventsContainer:setVisible(false)

        self.eventLogRenderer:setData(farmEvents)
        self.farmEventsTable:reloadData()
    end

    self:updateMenuButtons()
end

function MenuRedTape:updateMenuButtons()
    local state = self.subCategoryPaging:getState()
    -- local v213_ = g_currentMission

    if state == MenuRedTape.SUB_CATEGORY.OVERVIEW then
        print("Overview sub-category selected")
    elseif state == MenuRedTape.SUB_CATEGORY.POLICIES then
        print("Policies sub-category selected")
    elseif state == MenuRedTape.SUB_CATEGORY.SCHEMES then
        print("Schemes sub-category selected")
    elseif state == MenuRedTape.SUB_CATEGORY.EVENTLOG then
        print("Event Log sub-category selected")
    end
end

function MenuRedTape:onMoneyChange()
    if g_localPlayer ~= nil then
        local farm = g_farmManager:getFarmById(g_localPlayer.farmId)
        if farm.money <= -1 then
            self.currentBalanceText:applyProfile(ShopMenu.GUI_PROFILE.SHOP_MONEY_NEGATIVE, nil, true)
        else
            self.currentBalanceText:applyProfile(ShopMenu.GUI_PROFILE.SHOP_MONEY, nil, true)
        end
        local moneyText = g_i18n:formatMoney(farm.money, 0, true, false)
        self.currentBalanceText:setText(moneyText)
        if self.shopMoneyBox ~= nil then
            self.shopMoneyBox:invalidateLayout()
            self.shopMoneyBoxBg:setSize(self.shopMoneyBox.flowSizes[1] + 60 * g_pixelSizeScaledX)
        end
    end
end
