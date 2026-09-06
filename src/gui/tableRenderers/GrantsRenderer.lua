RTGrantsRenderer = {}
RTGrantsRenderer_mt = Class(RTGrantsRenderer)

function RTGrantsRenderer.new(section)
    local self = {}
    setmetatable(self, RTGrantsRenderer_mt)
    self.data = {
        pending = {},
        approved = {},
        historical = {}
    }
    self.selectedRow = -1
    self.indexChangedCallback = nil
    self.currentSection = section or "pending" -- pending, approved, historical
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
    local sectionData = self.data[self.currentSection]
    if sectionData == nil then
        return 0
    end
    return #sectionData
end

function RTGrantsRenderer:getBuildingName(grant)
    local storeItem = nil
    if grant.xmlFile ~= nil and grant.xmlFile ~= "" then
        storeItem = g_storeManager:getItemByXMLFilename(grant.xmlFile)
    end

    if storeItem ~= nil and storeItem.name ~= nil then
        return storeItem.name
    end

    -- The store item is gone (mod removed or updated, map placeable, ...). Fall back to the
    -- file name so the row still tells the player which building the grant was for.
    local fileName = grant.xmlFile ~= nil and grant.xmlFile:match("([^/\]+)%.xml$") or nil
    if fileName ~= nil then
        return fileName
    end

    return g_i18n:getText("rt_grant_unknown_building")
end

function RTGrantsRenderer:populateCellForItemInSection(list, section, index, cell)
    local grant = self.data[self.currentSection][index]
    if not grant then
        return
    end

    cell:getAttribute("building"):setText(self:getBuildingName(grant))

    cell:getAttribute("price"):setText(g_i18n:formatMoney(grant.price or 0, 0, true, true))

    if self.currentSection == "pending" then
        local applied = (grant.applicationMonth or 0) % 12
        if applied == 0 then applied = 12 end

        local assessment = (grant.assessmentMonth or 0) % 12
        if assessment == 0 then assessment = 12 end

        cell:getAttribute("applied"):setText(RedTape.monthToString(applied))
        cell:getAttribute("assessment"):setText(RedTape.monthToString(assessment))
    elseif self.currentSection == "approved" then
        local assessment = (grant.assessmentMonth or 0) % 12
        if assessment == 0 then assessment = 12 end

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
