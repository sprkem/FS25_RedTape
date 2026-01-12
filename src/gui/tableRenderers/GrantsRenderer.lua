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

    -- Get building name from XML file path
    local buildingName = self:getBuildingNameFromXmlFile(grant.xmlFile)
    cell:getAttribute("building"):setText(buildingName)
    
    -- Format price
    cell:getAttribute("price"):setText(g_i18n:formatMoney(grant.price, 0, true, true))

    if self.currentSection == "pending" then
        -- Applied month and assessment month
        cell:getAttribute("applied"):setText(RedTape.monthToString(grant.applicationMonth % 12))
        cell:getAttribute("assessment"):setText(RedTape.monthToString(grant.assessmentMonth % 12))
    elseif self.currentSection == "approved" then
        -- Grant amount and approval date
        cell:getAttribute("amount"):setText(g_i18n:formatMoney(grant.amount or 0, 0, true, true))
        cell:getAttribute("approved"):setText(RedTape.monthToString(grant.assessmentMonth % 12))
    elseif self.currentSection == "historical" then
        -- Amount and status
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

function RTGrantsRenderer:getBuildingNameFromXmlFile(xmlFile)
    -- Extract building name from XML file path
    -- Example: "data/placeables/sheds/shed01.xml" -> "Shed 01"
    if not xmlFile or xmlFile == "" then
        return g_i18n:getText("rt_unknown_building")
    end
    
    local filename = xmlFile:match("([^/]+)%.xml$")
    if filename then
        -- Convert camelCase/snake_case to readable format
        local readable = filename:gsub("(%l)(%u)", "%1 %2")
        readable = readable:gsub("_", " ")
        readable = readable:gsub("(%a)([%w_]*)", function(first, rest)
            return first:upper() .. rest:lower()
        end)
        return readable
    end
    
    return g_i18n:getText("rt_unknown_building")
end