ActivePoliciesRenderer = {}
ActivePoliciesRenderer_mt = Class(ActivePoliciesRenderer)

function ActivePoliciesRenderer:new(parent)
    local self = {}
    setmetatable(self, ActivePoliciesRenderer_mt)
    self.parent = parent
    self.data = nil
    self.selectedRow = -1;

    return self
end

function ActivePoliciesRenderer:setData(data)
    self.data = data
end

function ActivePoliciesRenderer:getNumberOfSections()
    return 1
end

function ActivePoliciesRenderer:getNumberOfItemsInSection(list, section)
    return #self.data
end

function ActivePoliciesRenderer:getTitleForSectionHeader(list, section)
    return ""
end

function ActivePoliciesRenderer:populateCellForItemInSection(list, section, index, cell)
    local activePolicy = self.data[index]
    local rt = g_currentMission.RedTape

    local nextEvaluationPeriod = rt.monthToString(rt.periodToMonth(activePolicy.nextEvaluationPeriod))

    cell:getAttribute("name"):setText(activePolicy:getName())
    cell:getAttribute("description"):setText(activePolicy:getDescription())
    cell:getAttribute("next"):setText(nextEvaluationPeriod)
end

function ActivePoliciesRenderer:onListSelectionChanged(list, section, index)
    self.selectedRow = index
end
