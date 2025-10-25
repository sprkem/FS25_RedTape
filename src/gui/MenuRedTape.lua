MenuRedTape = {}
MenuRedTape.currentTasks = {}
MenuRedTape._mt = Class(MenuRedTape, TabbedMenuFrameElement)

MenuRedTape.SUB_CATEGORY = {
    POLICIES = 1,
    SCHEMES = 2,
    TAX = 3,
    EVENTLOG = 4
}

MenuRedTape.SCHEME_LIST_TYPE = {
    AVAILABLE = 1,
    ACTIVE = 2
}
MenuRedTape.SCHEME_STATE_TEXTS = { "ui_contractsNew", "ui_contractsActive" }

MenuRedTape.HEADER_SLICES = {
    [MenuRedTape.SUB_CATEGORY.POLICIES] = "gui.icon_ingameMenu_contracts",
    [MenuRedTape.SUB_CATEGORY.SCHEMES] = "gui.icon_ingameMenu_finances",
    [MenuRedTape.SUB_CATEGORY.TAX] = "gui.icon_ingameMenu_prices",
    [MenuRedTape.SUB_CATEGORY.EVENTLOG] = "gui.icon_ingameMenu_contracts",
}
MenuRedTape.HEADER_TITLES = {
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

    self.eventLogRenderer = RTEventLogRenderer.new()
    self.activePoliciesRenderer = RTActivePoliciesRenderer.new()
    self.schemesRenderer = RTSchemesRenderer.new()
    self.schemeReportRenderer = RTReportRenderer.new()
    self.policyReportRenderer = RTReportRenderer.new()
    self.taxNotesRenderer = RTTaxNotesRenderer.new()

    self.vehicleElements = {}

    return self
end

function MenuRedTape:displaySelectedPolicy()
    local index = self.activePoliciesTable.selectedIndex
    local rt = g_currentMission.RedTape

    if index ~= -1 then
        local policy = self.activePoliciesRenderer.data[index]

        if policy ~= nil then
            self.policyInfoContainer:setVisible(true)
            self.noSelectedPolicyText:setVisible(false)
            self.selectedPolicyName:setText(policy:getName())
            self.selectedPolicyDescription:setText(policy:getDescription())

            local nextEval = policy.nextEvaluationMonth % 12
            if nextEval == 0 then
                nextEval = 12
            end

            self.selectedPolicyReportNextDate:setText(string.format(g_i18n:getText("rt_header_next_evaluation_date"),
                RedTape.monthToString(nextEval)))

            if rt.tableCount(policy.lastEvaluationReport) == 0 then
                self.policyReportContainer:setVisible(false)
                self.noPolicyReportContainer:setVisible(true)
                self.selectedPolicyReportDescription:setVisible(false)
            else
                self.policyReportContainer:setVisible(true)
                self.noPolicyReportContainer:setVisible(false)
                self.policyReportRenderer:setData(policy.lastEvaluationReport)
                self.selectedPolicyReportDescription:setVisible(true)
                self.selectedPolicyReportDescription:setText(policy:getReportDescription())
                self.policyReportTable:reloadData()
            end
        else
            self.policyInfoContainer:setVisible(false)
            self.noSelectedPolicyText:setVisible(true)
        end
    end
end

function MenuRedTape:displaySelectedScheme()
    local index = self.schemesTable.selectedIndex
    local rt = g_currentMission.RedTape

    if index ~= -1 then
        local selection = self.schemeDisplaySwitcher:getState()
        local scheme = self.schemesRenderer.data[selection][index]

        if scheme ~= nil then
            self.schemeInfoContainer:setVisible(true)
            self.noSelectedSchemeText:setVisible(false)
            self.selectedSchemeName:setText(scheme:getName())
            self.selectedSchemeDescription:setText(scheme:getDescription())

            if selection == MenuRedTape.SCHEME_LIST_TYPE.AVAILABLE then
                self.activeSchemeInfo:setVisible(false)
                self:updateSchemeEquipmentBox(scheme)
            elseif selection == MenuRedTape.SCHEME_LIST_TYPE.ACTIVE then
                self.activeSchemeInfo:setVisible(true)
                self.schemeEquipmentBox:setVisible(false)

                local nextEval = scheme:getNextEvaluationMonth()
                self.selectedSchemeReportNextDate:setText(string.format(g_i18n:getText("rt_header_next_evaluation_date"),
                    RedTape.monthToString(nextEval)))

                if rt.tableCount(scheme.lastEvaluationReport) == 0 then
                    self.schemeReportContainer:setVisible(false)
                    self.noSchemeReportContainer:setVisible(true)
                    self.selectedSchemeReportDescription:setVisible(false)
                else
                    self.schemeReportContainer:setVisible(true)
                    self.noSchemeReportContainer:setVisible(false)
                    self.schemeReportRenderer:setData(scheme.lastEvaluationReport)
                    self.selectedSchemeReportDescription:setVisible(true)
                    self.selectedSchemeReportDescription:setText(scheme:getReportDescription())
                    self.schemeReportTable:reloadData()
                end
            end
        else
            print("Scheme is nil")
            self.schemeInfoContainer:setVisible(false)
            self.noSelectedSchemeText:setVisible(true)
        end
    end
end

function MenuRedTape:updateSchemeEquipmentBox(scheme)
    for _, v in pairs(self.vehicleElements) do
        v:delete()
    end
    self.vehicleElements = {}
    self.schemeVehiclesBox:invalidateLayout()
    local schemeInfo = RTSchemes[scheme.schemeIndex]

    local vehicles = scheme:getVehiclesToSpawn()

    if vehicles == nil or #vehicles == 0 then
        self.schemeEquipmentBox:setVisible(false)
        return
    end

    local totalWidth = 0
    for _, storeItem in ipairs(vehicles) do
        local vehicleImage = storeItem.imageFilename
        if storeItem.configurations ~= nil then
            for k, _ in pairs(storeItem.configurations) do
                local configId = storeItem.configurations[k]
                local config = storeItem.configurations[k][configId]
                if config ~= nil and (config.vehicleIcon ~= nil and config.vehicleIcon ~= "") then
                    vehicleImage = config.vehicleIcon
                    break
                end
            end
        end
        local newElement = self.vehicleTemplate:clone(self.schemeVehiclesBox)
        newElement:setImageFilename(vehicleImage)
        newElement:setImageColor(nil, nil, nil, nil, 1)
        totalWidth = totalWidth + newElement.absSize[1] + newElement.margin[1] + newElement.margin[3]
        table.insert(self.vehicleElements, newElement)
    end
    self.schemeVehiclesBox:setSize(totalWidth)
    self.schemeVehiclesBox:invalidateLayout()
    if self.schemeVehiclesBox.maxFlowSize > self.schemeVehiclesBox.parent.absSize[1] and self.schemeVehiclesBox.pivot[1] ~= 0 then
        self.schemeVehiclesBox:setPivot(0, 0.5)
    elseif self.schemeVehiclesBox.maxFlowSize <= self.schemeVehiclesBox.parent.absSize[1] and self.schemeVehiclesBox.pivot[1] ~= 0.5 then
        self.schemeVehiclesBox:setPivot(0.5, 0.5)
    end
    self.schemeVehiclesBox:setPosition(0)

    self.schemeEquipmentBox:setVisible(true)
end

function MenuRedTape:onGuiSetupFinished()
    MenuRedTape:superClass().onGuiSetupFinished(self)

    self.farmEventsTable:setDataSource(self.eventLogRenderer)
    self.farmEventsTable:setDelegate(self.eventLogRenderer)

    self.activePoliciesTable:setDataSource(self.activePoliciesRenderer)
    self.activePoliciesTable:setDelegate(self.activePoliciesRenderer)

    self.activePoliciesRenderer.indexChangedCallback = function(index)
        self:displaySelectedPolicy()
    end

    self.schemesTable:setDataSource(self.schemesRenderer)
    self.schemesTable:setDelegate(self.schemesRenderer)

    self.schemesRenderer.indexChangedCallback = function(index)
        self:displaySelectedScheme()
    end

    self.schemeReportTable:setDataSource(self.schemeReportRenderer)
    self.schemeReportTable:setDelegate(self.schemeReportRenderer)

    self.policyReportTable:setDataSource(self.policyReportRenderer)
    self.policyReportTable:setDelegate(self.policyReportRenderer)

    self.taxNotesTable:setDataSource(self.taxNotesRenderer)
    self.taxNotesTable:setDelegate(self.taxNotesRenderer)
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

    self.vehicleTemplate:unlinkElement()
end

function MenuRedTape:getMenuButtonInfo()
    return self.menuButtonInfo[self.subCategoryPaging:getState()]
end

function MenuRedTape:onFrameOpen()
    -- local xmlFile = loadXMLFile("Temp", "dataS/gui/InGameMenuContractsFrame.xml")
    -- saveXMLFileTo(xmlFile, g_currentMission.missionInfo.savegameDirectory .. "/InGameMenuContractsFrame.xml")
    -- delete(xmlFile);

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
    g_messageCenter:subscribe(MessageType.TAXES_UPDATED, self.updateContent, self)
    g_messageCenter:subscribe(MessageType.POLICIES_UPDATED, self.updateContent, self)
    self:updateContent()
    self:setMenuButtonInfoDirty()
    -- FocusManager:setFocus(self.subCategoryPaging)
end

function MenuRedTape:onFrameClose()
    MenuRedTape:superClass().onFrameClose(self)
    g_messageCenter:unsubscribeAll(self)
end

function MenuRedTape:onClickPolicies()
    self.subCategoryPaging:setState(MenuRedTape.SUB_CATEGORY.POLICIES, true)

    self:setMenuButtonInfoDirty()
end

function MenuRedTape:onClickSchemes()
    self.subCategoryPaging:setState(MenuRedTape.SUB_CATEGORY.SCHEMES, true)

    self:setMenuButtonInfoDirty()
end

function MenuRedTape:onClickTax()
    self.subCategoryPaging:setState(MenuRedTape.SUB_CATEGORY.TAX, true)

    self:setMenuButtonInfoDirty()
end

function MenuRedTape:onClickEventLog()
    self.subCategoryPaging:setState(MenuRedTape.SUB_CATEGORY.EVENTLOG, true)

    self:setMenuButtonInfoDirty()
end

function MenuRedTape:updateSubCategoryPages(subCategoryIndex)
    self:updateContent()
    self:setMenuButtonInfoDirty()
    -- FocusManager:setFocus(self.subCategoryPaging)
end

function MenuRedTape:onSwitchSchemeDisplay()
    self.schemesTable:reloadData()
    local hasItem = self.schemesTable:getItemCount() > 0
    self.schemesContainer:setVisible(hasItem)
    self.noSchemesContainer:setVisible(not hasItem)
    if hasItem then
        self.schemesTable:setSelectedIndex(1)
    end
    self:displaySelectedScheme()
    self.btnSelectSchemeForFarm.disabled = self.schemeDisplaySwitcher:getState() ~=
        MenuRedTape.SCHEME_LIST_TYPE.AVAILABLE
    self:setMenuButtonInfoDirty()
end

function MenuRedTape:updateContent()
    local state = self.subCategoryPaging:getState()

    self.categoryHeaderIcon:setImageSlice(nil, MenuRedTape.HEADER_SLICES[state])
    self.categoryHeaderText:setText(g_i18n:getText(MenuRedTape.HEADER_TITLES[state]))

    for k, v in pairs(self.subCategoryPages) do
        v:setVisible(k == state)
    end

    if state == MenuRedTape.SUB_CATEGORY.POLICIES then
        local policySystem = g_currentMission.RedTape.PolicySystem
        local activePolicies = policySystem.policies
        local progress = policySystem:getProgressForCurrentFarm()

        self.complianceTier:setText(string.format(g_i18n:getText("rt_header_current_tier"),
            RTPolicySystem.TIER_NAMES[progress.tier]))
        self.progressText:setText(string.format("%d/%d", progress.points, progress.nextTierPoints))
        local fullWidth = self.progressBarBg.size[1] - self.progressBar.margin[1] * 2
        local minProgressBarWidthRatio = self.progressBar.startSize[1] * 2 / fullWidth
        local progressBarRatio = math.max(progress.points / progress.nextTierPoints, minProgressBarWidthRatio)
        self.progressBar:setSize(fullWidth * math.min(progressBarRatio, 1), nil)

        self.activePoliciesRenderer:setData(activePolicies)
        self.activePoliciesTable:reloadData()

        self:displaySelectedPolicy()

        self.activePoliciesContainer:setVisible(self.activePoliciesTable:getItemCount() > 0)
        self.noActivePoliciesContainer:setVisible(self.activePoliciesTable:getItemCount() == 0)
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

        self:displaySelectedScheme()

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
    elseif state == MenuRedTape.SUB_CATEGORY.TAX then
        local taxSystem = g_currentMission.RedTape.TaxSystem
        local farmId = g_currentMission:getFarmId()
        local statement = taxSystem.taxStatements[farmId]

        local currentYearStatement = taxSystem:getCurrentYearTaxToDate(farmId)
        self.taxEstimate:setText(g_i18n:formatMoney(currentYearStatement.totalTax, 0, true, true))

        if statement == nil then
            self.taxStatementContainer:setVisible(false)
            self.noTaxStatementContainer:setVisible(true)
            return
        end

        self.taxStatementContainer:setVisible(true)
        self.noTaxStatementContainer:setVisible(false)

        self.taxTotalExpenses:setText(g_i18n:formatMoney(statement.totalExpenses, 0, true, true))
        self.taxTotalTaxable:setText(g_i18n:formatMoney(statement.totalTaxableIncome, 0, true, true))
        self.taxTotalTaxed:setText(g_i18n:formatMoney(statement.totalTaxedIncome, 0, true, true))
        self.taxTaxRate:setText(string.format("%.2f%%", statement.taxRate * 100))
        self.taxTotalTaxDue:setText(g_i18n:formatMoney(statement.totalTax, 0, true, true))
        self.taxStatementStatus:setText(statement.paid and
            g_i18n:getText("rt_tax_statement_status_paid") or g_i18n:getText("rt_tax_statement_status_unpaid"))

        if #statement.notes == 0 then
            self.taxNotesContainer:setVisible(false)
            self.noTaxNotesContainer:setVisible(true)
        else
            self.taxNotesContainer:setVisible(true)
            self.noTaxNotesContainer:setVisible(false)
            self.taxNotesRenderer:setData(statement.notes)
            self.taxNotesTable:reloadData()
        end
    end

    self:updateMenuButtons()
end

function MenuRedTape:updateMenuButtons()
    local state = self.subCategoryPaging:getState()

    if state == MenuRedTape.SUB_CATEGORY.POLICIES then
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
    local vehicles = scheme:getVehiclesToSpawn()
    local schemeSystem = g_currentMission.RedTape.SchemeSystem

    -- TODO test full shop
    if not schemeSystem.isSpawnSpaceAvailable(vehicles) then
        InfoDialog.show(g_i18n:getText("rt_no_vehicle_room"))
        return
    end

    local farmId = g_currentMission:getFarmId()
    g_client:getServerConnection():sendEvent(RTSchemeSelectedEvent.new(scheme, farmId))

    InfoDialog.show(g_i18n:getText("rt_info_scheme_selected"))
end
