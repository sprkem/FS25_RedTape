RTTaxSystem = {}
RTTaxSystem_mt = Class(RTTaxSystem)

RTTaxSystem.TAX_CALCULATION_MONTH = 4
RTTaxSystem.TAX_PAYMENT_MONTH = 9

function RTTaxSystem.new()
    local self = {}
    setmetatable(self, RTTaxSystem_mt)
    self.lineItems = {}
    self.taxStatements = {}
    self.farms = {}

    MoneyType.TAX_PAID = MoneyType.register("taxCost", "rt_ui_taxCost")
    MoneyType.LAST_ID = MoneyType.LAST_ID + 1

    return self
end

function RTTaxSystem:loadFromXMLFile(xmlFile)
    if (not g_currentMission:getIsServer()) then return end

    local key = RedTape.SaveKey .. ".taxSystem"

    self.lineItems = {}

    local i = 0
    while true do
        local lineItemKey = string.format("%s.lineItems.lineItem(%d)", key, i)
        if not hasXMLProperty(xmlFile, lineItemKey) then
            break
        end

        local farmId = getXMLInt(xmlFile, lineItemKey .. "#farmId")
        local month = getXMLInt(xmlFile, lineItemKey .. "#month")

        if self.lineItems[farmId] == nil then
            self.lineItems[farmId] = {}
        end
        if self.lineItems[farmId][month] == nil then
            self.lineItems[farmId][month] = {}
        end

        local lineItem = RTTaxLineItem.new()
        lineItem:loadFromXMLFile(xmlFile, lineItemKey)

        table.insert(self.lineItems[farmId][month], lineItem)

        i = i + 1
    end
end

function RTTaxSystem:saveToXmlFile(xmlFile)
    if (not g_currentMission:getIsServer()) then return end

    local key = RedTape.SaveKey .. ".taxSystem"

    local i = 0
    for farmId, months in pairs(self.lineItems) do
        for month, lineItems in pairs(months) do
            for _, lineItem in ipairs(lineItems) do
                local lineItemKey = string.format("%s.lineItems.lineItem(%d)", key, i)
                setXMLInt(xmlFile, lineItemKey .. "#farmId", farmId)
                setXMLInt(xmlFile, lineItemKey .. "#month", month)
                lineItem:saveToXmlFile(xmlFile, lineItemKey)
                i = i + 1
            end
        end
    end
end

function RTTaxSystem:hourChanged()
end

function RTTaxSystem:periodChanged()
    local month = RedTape.periodToMonth(g_currentMission.environment.currentPeriod)
    if month == RTTaxSystem.TAX_CALCULATION_MONTH then
        self:createAnnualTaxStatements()
    end

    if month == RTTaxSystem.TAX_PAYMENT_MONTH then
        self:processTaxStatements()
    end

    local cumulativeMonth = RedTape.getCumulativeMonth()
    local oldestHistoryMonth = cumulativeMonth - 24

    -- Clean up old tax line items
    for farmId, months in pairs(self.lineItems) do
        for month, _ in pairs(months) do
            if month < oldestHistoryMonth then
                self.lineItems[farmId][month] = nil
            end
        end
    end
end

function RTTaxSystem:recordLineItem(farmId, amount, statistic)
    local cumulativeMonth = RedTape.getCumulativeMonth()
    self.lineItems[farmId] = self.lineItems[farmId] or {}

    if self.lineItems[farmId][cumulativeMonth] == nil then
        self.lineItems[farmId][cumulativeMonth] = {}
    end

    local lineItem = RTTaxLineItem.new()
    lineItem.amount = amount
    lineItem.statistic = statistic

    if not RedTape.tableHasValue(self.farms, farmId) then
        table.insert(self.farms, farmId)
    end

    table.insert(self.lineItems[farmId][cumulativeMonth], lineItem)
end

function RTTaxSystem:getTaxRate(farmId)
    -- Example usage is to look up the farm and find tax rate modifiers
    return 0.2
end

function RTTaxSystem:getTaxedAmount(lineItem, taxStatement)
    -- Example usage is to look up the farm and find earned tax breaks for the lineItem.statistic and reduce taxable amount accordingly
    return lineItem.amount
end

function RTTaxSystem:categoriseLineItem(lineItem, taxStatement)
    local expenseStats = {
        "newVehiclesCost",
        "constructionCost",
        "newHandtoolsCost",
        "wagePayment",
        "newAnimalsCost",
        "animalUpkeep",
        "purchaseSeeds",
        "purchaseFertilizer",
        "purchaseFuel",
        "purchaseSaplings",
        "purchaseWater",
        "purchaseBales",
        "purchasePallets",
        "purchaseConsumable",
        "fieldPurchase",
        "vehicleLeasingCost",
        "loanInterest",
        "vehicleRunningCost",
        "propertyMaintenance",
        "productionCosts"
    }

    local incomeStats = {
        "soldVehicles",
        "soldBuildings",
        "soldHandtools",
        "soldMilk",
        "soldAnimals",
        "harvestIncome",
        "missionIncome",
        "fieldSelling",
        "propertyIncome",
        "soldProducts",
        "incomeBga",
        "soldWood",
        "soldBales",
        "expenses"
    }

    if RedTape.tableHasValue(expenseStats, lineItem.statistic) then
        taxStatement.totalExpenses = taxStatement.totalExpenses + math.abs(lineItem.amount)
    elseif RedTape.tableHasValue(incomeStats, lineItem.statistic) then
        taxStatement.totalTaxableIncome = taxStatement.totalTaxableIncome + math.abs(lineItem.amount)
        taxStatement.totalTaxedIncome = taxStatement.totalTaxedIncome + self:getTaxedAmount(lineItem, taxStatement)
    else
        print("Warning: Uncategorised tax line item statistic '" .. tostring(lineItem.statistic) .. "'")
    end
end

function RTTaxSystem:createAnnualTaxStatements()
    local minMonth = RedTape.getCumulativeMonth() - 12
    local maxMonth = RedTape.getCumulativeMonth() - 1
    for _, farmId in ipairs(self.farms) do
        local taxStatement = RTTaxStatement.new()
        taxStatement.farmId = farmId
        taxStatement.taxRate = self:getTaxRate(farmId)

        local lineItems = self.lineItems[farmId] or {}

        for month, lineItems in pairs(lineItems) do
            if month < minMonth or month > maxMonth then
                continue
            end

            for _, lineItem in ipairs(lineItems) do
                self:categoriseLineItem(lineItem, taxStatement)
            end

            local finalTaxAmount = taxStatement.totalTaxedIncome - taxStatement.totalExpenses
            if finalTaxAmount < 0 then
                finalTaxAmount = 0
            end

            taxStatement.totalTax = math.floor(finalTaxAmount * taxStatement.taxRate)
        end

        g_client:getServerConnection():sendEvent(RTNewTaxStatementEvent.new(taxStatement))
    end
end

-- Called via NewTaxStatementEvent to store on client and server
function RTTaxSystem:storeTaxStatement(taxStatement)
    local farmId = taxStatement.farmId

    -- Replace existing statement for farmId if exists
    for i, existingStatement in ipairs(self.taxStatements) do
        if existingStatement.farmId == farmId then
            self.taxStatements[i] = taxStatement
            return
        end
    end

    table.insert(self.taxStatements, taxStatement)
end

function RTTaxSystem:processTaxStatements()
    if g_currentMission:getIsServer() then
        for _, taxStatement in ipairs(self.taxStatements) do
            if not taxStatement.paid then
                if taxStatement.totalTax > 0 then
                    g_currentMission:addMoneyChange(taxStatement.totalTax, taxStatement.farmId, MoneyType.TAX_PAID,
                        true)
                end
                g_client:getServerConnection():sendEvent(RTTaxStatementPaidEvent.new(taxStatement.farmId))
            end
        end
    end
end

-- Called via RTTaxStatementPaidEvent to mark as paid on client and server
function RTTaxSystem:markTaxStatementAsPaid(farmId)
    for _, taxStatement in ipairs(self.taxStatements) do
        if taxStatement.farmId == farmId then
            taxStatement.paid = true
            return
        end
    end
end

function RTTaxSystem:getCurrentYearTaxToDate(farmId)
    local cumulativeMonth = RedTape.getCumulativeMonth()
    local currentMonth = RedTape.periodToMonth(g_currentMission.environment.currentPeriod)

    local monthsBack = (currentMonth - RTTaxSystem.TAX_CALCULATION_MONTH + 12) % 12
    local minMonth = cumulativeMonth - monthsBack
    local maxMonth = cumulativeMonth

    local taxStatement = RTTaxStatement.new()
    taxStatement.farmId = farmId
    taxStatement.taxRate = self:getTaxRate(farmId)

    local lineItems = self.lineItems[farmId] or {}

    for month, lineItems in pairs(lineItems) do
        if month < minMonth or month > maxMonth then
            continue
        end

        for _, lineItem in pairs(lineItems) do
            self:categoriseLineItem(lineItem, taxStatement)
        end

        local finalTaxAmount = taxStatement.totalTaxedIncome - taxStatement.totalExpenses
        if finalTaxAmount < 0 then
            finalTaxAmount = 0
        end

        taxStatement.totalTax = math.floor(finalTaxAmount * taxStatement.taxRate)
    end
    return taxStatement
end
