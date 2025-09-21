MenuRedTape = {}
MenuRedTape.currentTasks = {}
MenuRedTape._mt = Class(MenuRedTape, TabbedMenuFrameElement)

MenuRedTape.SUB_CATEGORY = {
    OVERVIEW = 1,
    POLICIES = 2,
    SCHEMES = 3,
    TAX = 4,
    EVENTLOG = 5
}

MenuRedTape.SCHEME_LIST_TYPE = {
    AVAILABLE = 1,
    ACTIVE = 2
}
MenuRedTape.SCHEME_STATE_TEXTS = { "ui_contractsNew", "ui_contractsActive" }

MenuRedTape.HEADER_SLICES = {
    [MenuRedTape.SUB_CATEGORY.OVERVIEW] = "gui.icon_ingameMenu_contracts",
    [MenuRedTape.SUB_CATEGORY.POLICIES] = "gui.icon_ingameMenu_finances",
    [MenuRedTape.SUB_CATEGORY.SCHEMES] = "gui.icon_ingameMenu_finances",
    [MenuRedTape.SUB_CATEGORY.TAX] = "gui.icon_ingameMenu_prices",
    [MenuRedTape.SUB_CATEGORY.EVENTLOG] = "gui.icon_ingameMenu_contracts",
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
    self.menuButtonInfo = {}

    self.eventLogRenderer = EventLogRenderer.new()
    self.activePoliciesRenderer = ActivePoliciesRenderer.new()
    self.schemesRenderer = SchemesRenderer.new()

    return self
end

function MenuRedTape:onGuiSetupFinished()
    MenuRedTape:superClass().onGuiSetupFinished(self)

    self.farmEventsTable:setDataSource(self.eventLogRenderer)
    self.farmEventsTable:setDelegate(self.eventLogRenderer)

    self.activePoliciesTable:setDataSource(self.activePoliciesRenderer)
    self.activePoliciesTable:setDelegate(self.activePoliciesRenderer)

    self.schemesTable:setDataSource(self.schemesRenderer)
    self.schemesTable:setDelegate(self.schemesRenderer)
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

    -- Set the available/active scheme switcher texts
    local schemeSwitcherTexts = {}
    for k, v in pairs(MenuRedTape.SCHEME_STATE_TEXTS) do
        table.insert(schemeSwitcherTexts, g_i18n:getText(v))
    end
    self.schemeDisplaySwitcher:setTexts(schemeSwitcherTexts)

    self.btnBack = {
        inputAction = InputAction.MENU_BACK
    }
    self.btnNextPage = {
        inputAction = InputAction.MENU_PAGE_NEXT,
        text = g_i18n:getText("ui_ingameMenuNext"),
        callback = self.onPageNext
    }
    self.btnPrevPage = {
        inputAction = InputAction.MENU_PAGE_PREV,
        text = g_i18n:getText("ui_ingameMenuPrev"),
        callback = self.onPagePrevious
    }

    self.menuButtonInfoDefault = { self.btnBack, self.btnNextPage, self.btnPrevPage }
    self.menuButtonInfo[MenuRedTape.SUB_CATEGORY.EVENTLOG] = self.menuButtonInfoDefault
    self.menuButtonInfo[MenuRedTape.SUB_CATEGORY.OVERVIEW] = self.menuButtonInfoDefault
    self.menuButtonInfo[MenuRedTape.SUB_CATEGORY.POLICIES] = self.menuButtonInfoDefault
    self.menuButtonInfo[MenuRedTape.SUB_CATEGORY.TAX] = self.menuButtonInfoDefault

    self.btnSelectSchemeForFarm = {
        inputAction = InputAction.MENU_ACTIVATE,
        text = g_i18n:getText("rt_btn_select_scheme"),
        callback = function()
            self:onSelectScheme()
        end
    }
    self.menuButtonInfo[MenuRedTape.SUB_CATEGORY.SCHEMES] = {
        self.btnSelectSchemeForFarm,
        self.btnBack,
        self.btnNextPage,
        self.btnPrevPage
    }
end

function MenuRedTape:getMenuButtonInfo()
    return self.menuButtonInfo[self.subCategoryPaging:getState()]
end

function MenuRedTape:onFrameOpen()
    local xmlFile = loadXMLFile("Temp", "dataS/gui/InGameMenuContractsFrame.xml")
    saveXMLFileTo(xmlFile, g_currentMission.missionInfo.savegameDirectory .. "/InGameMenuContractsFrame.xml")
    delete(xmlFile);

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
    g_messageCenter:subscribe(MessageType.EVENT_LOG_UPDATED, self.updateContent, self)
    g_messageCenter:subscribe(MessageType.SCHEMES_UPDATED, self.updateContent, self)
    self:updateContent()
    self:setMenuButtonInfoDirty()
    -- FocusManager:setFocus(self.subCategoryPaging)
end

function MenuRedTape:onFrameClose()
    MenuRedTape:superClass().onFrameClose(self)
    g_messageCenter:unsubscribeAll(self)
end

function MenuRedTape:onClickOverview()
    self.subCategoryPaging:setState(MenuRedTape.SUB_CATEGORY.OVERVIEW, true)
    self.btnSelectSchemeForFarm.disabled = self.schemeDisplaySwitcher:getState() ~= MenuRedTape.SCHEME_LIST_TYPE.AVAILABLE
    self:setMenuButtonInfoDirty()
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
    self:setMenuButtonInfoDirty()
    -- FocusManager:setFocus(self.subCategoryPaging)
end

function MenuRedTape:onSwitchSchemeDisplay()
    self.schemesTable:reloadData()
    self.schemesContainer:setVisible(self.schemesTable:getItemCount() > 0)
    self.noSchemesContainer:setVisible(self.schemesTable:getItemCount() == 0)
    self.btnSelectSchemeForFarm.disabled = self.schemeDisplaySwitcher:getState() ~= MenuRedTape.SCHEME_LIST_TYPE.AVAILABLE
    self:setMenuButtonInfoDirty()
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
        local policySystem = g_currentMission.RedTape.PolicySystem
        local activePolicies = policySystem.policies
        local progress = policySystem:getProgressForCurrentFarm()

        self.complianceTier:setText(string.format(g_i18n:getText("rt_header_current_tier"),
            PolicySystem.TIER_NAMES[progress.tier]))
        self.progressText:setText(string.format("%d/%d", progress.points, progress.nextTierPoints))
        local fullWidth = self.progressBarBg.size[1] - self.progressBar.margin[1] * 2
        local minProgressBarWidthRatio = self.progressBar.startSize[1] * 2 / fullWidth
        local progressBarRatio = math.max(progress.points / progress.nextTierPoints, minProgressBarWidthRatio)
        self.progressBar:setSize(fullWidth * math.min(progressBarRatio, 1), nil)

        if #activePolicies == 0 then
            self.activePoliciesContainer:setVisible(false)
            self.noActivePoliciesContainer:setVisible(true)
            return
        end

        self.activePoliciesContainer:setVisible(true)
        self.noActivePoliciesContainer:setVisible(false)
        self.noSelectedPolicyText:setVisible(self.activePoliciesRenderer.selectedRow == -1)
        self.policyInfoContainer:setVisible(self.activePoliciesRenderer.selectedRow ~= -1)

        self.activePoliciesRenderer:setData(activePolicies)
        self.activePoliciesTable:reloadData()
    elseif state == MenuRedTape.SUB_CATEGORY.SCHEMES then
        local schemeSystem = g_currentMission.RedTape.SchemeSystem
        local availableSchemes = schemeSystem:getAvailableSchemesForCurrentFarm()
        local activeSchemes = schemeSystem:getActiveSchemesForFarm(g_currentMission:getFarmId())

        local renderData = {
            [MenuRedTape.SCHEME_LIST_TYPE.AVAILABLE] = availableSchemes,
            [MenuRedTape.SCHEME_LIST_TYPE.ACTIVE] = activeSchemes
        }

        self.schemesRenderer:setData(renderData)
        self.schemesTable:reloadData()

        self.schemesContainer:setVisible(self.schemesTable:getItemCount() > 0)
        self.noSchemesContainer:setVisible(self.schemesTable:getItemCount() == 0)
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

function MenuRedTape:onSelectScheme()
    if self.schemesRenderer.selectedRow == -1 then
        return
    end

    if self.schemeDisplaySwitcher:getState() ~= MenuRedTape.SCHEME_LIST_TYPE.AVAILABLE then
        return
    end

    local scheme = self.schemesRenderer.data[MenuRedTape.SCHEME_LIST_TYPE.AVAILABLE][self.schemesRenderer.selectedRow]
    local farmId = g_currentMission:getFarmId()
    g_client:getServerConnection():sendEvent(SchemeSelectedEvent.new(scheme, farmId))
end
