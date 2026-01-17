RTGrantsRenderer = {}
RTGrantsRenderer_mt = Class(RTGrantsRenderer)

function RTGrantsRenderer.new()
    local self = {}
    setmetatable(self, RTGrantsRenderer_mt)
    self.data = {
        pending = {},
        approved = {},
        historical = {}
    }
    self.selectedRow = -1
    self.indexChangedCallback = nil
    self.currentSection = "pending" -- pending, approved, historical
    return self
end

function RTGrantsRenderer:setData(data)
    self.data = data or {
        pending = {},
        approved = {},
        historical = {}
    }
end

function RTGrantsRenderer:setCurrentSection(section)
    self.currentSection = section
    self.selectedRow = -1
end

function RTGrantsRenderer:getNumberOfSections()
    return 1
end

function RTGrantsRenderer:getNumberOfItemsInSection(list, section)
    return #self.data[self.currentSection]
end

function RTGrantsRenderer:populateCellForItemInSection(list, section, index, cell)
    local grant = self.data[self.currentSection][index]
    if not grant then
        return
    end

    local buildingName = g_storeManager:getItemByXMLFilename(grant.xmlFile).name
    cell:getAttribute("building"):setText(buildingName)

    cell:getAttribute("price"):setText(g_i18n:formatMoney(grant.price, 0, true, true))

    local applied = grant.applicationMonth % 12
    if applied == 0 then applied = 12 end

    local assessment = grant.assessmentMonth % 12
    if assessment == 0 then assessment = 12 end

    if self.currentSection == "pending" then
        cell:getAttribute("applied"):setText(RedTape.monthToString(applied))
        cell:getAttribute("assessment"):setText(RedTape.monthToString(assessment))
    elseif self.currentSection == "approved" then
        cell:getAttribute("amount"):setText(g_i18n:formatMoney(grant.amount or 0, 0, true, true))
        cell:getAttribute("approved"):setText(RedTape.monthToString(assessment))
    elseif self.currentSection == "historical" then
        local amount = grant.amount or 0
        cell:getAttribute("amount"):setText(g_i18n:formatMoney(amount, 0, true, true))

        local statusText = ""
        if grant.status == RTGrantSystem.STATUS.COMPLETE then
            statusText = g_i18n:getText("rt_grant_status_completed")
        elseif grant.status == RTGrantSystem.STATUS.REJECTED then
            statusText = g_i18n:getText("rt_grant_status_rejected")
        end
        cell:getAttribute("status"):setText(statusText)
    end
end

function RTGrantsRenderer:onListSelectionChanged(list, section, index)
    self.selectedRow = index
    if self.indexChangedCallback ~= nil then
        self.indexChangedCallback(index)
    end
end
