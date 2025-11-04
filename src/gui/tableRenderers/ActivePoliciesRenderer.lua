RTActivePoliciesRenderer = {}
RTActivePoliciesRenderer_mt = Class(RTActivePoliciesRenderer)

function RTActivePoliciesRenderer.new()
    local self = {}
    setmetatable(self, RTActivePoliciesRenderer_mt)
    self.data = nil
    self.selectedRow = -1;
    self.indexChangedCallback = nil

    return self
end

function RTActivePoliciesRenderer:setData(data)
    self.data = data
end

function RTActivePoliciesRenderer:getNumberOfSections()
    return 1
end

function RTActivePoliciesRenderer:getNumberOfItemsInSection(list, section)
    return #self.data
end

function RTActivePoliciesRenderer:getTitleForSectionHeader(list, section)
    return ""
end

function RTActivePoliciesRenderer:populateCellForItemInSection(list, section, index, cell)
    local activePolicy = self.data[index]
    local farmId = g_currentMission:getFarmId()
    local hasWarnings = activePolicy:getWarningCount(farmId) > 0

    cell:getAttribute("name"):setText(activePolicy:getName())
    if hasWarnings then
        cell:getAttribute("warning"):setVisible(true)
    else
        cell:getAttribute("warning"):setVisible(false)
    end
end

function RTActivePoliciesRenderer:onListSelectionChanged(list, section, index)
    self.selectedRow = index
    if self.indexChangedCallback ~= nil then
        self.indexChangedCallback(index)
    end
end
