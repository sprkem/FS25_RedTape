ReportRenderer = {}
ReportRenderer_mt = Class(ReportRenderer)

function ReportRenderer.new()
    local self = {}
    setmetatable(self, ReportRenderer_mt)
    self.data = nil
    self.selectedRow = -1;
    self.indexChangedCallback = nil

    return self
end

function ReportRenderer:setData(data)
    self.data = data
end

function ReportRenderer:getNumberOfSections()
    return 1
end

function ReportRenderer:getNumberOfItemsInSection(list, section)
    return #self.data
end

function ReportRenderer:getTitleForSectionHeader(list, section)
    return ""
end

function ReportRenderer:populateCellForItemInSection(list, section, index, cell)
    local reportItem = self.data[index]
    cell:getAttribute("cell1"):setText(reportItem.cell1)
    cell:getAttribute("cell2"):setText(reportItem.cell2)
    cell:getAttribute("cell3"):setText(reportItem.cell3)
end

function ReportRenderer:onListSelectionChanged(list, section, index)
    self.selectedRow = index
    if self.indexChangedCallback ~= nil then
        self.indexChangedCallback(index)
    end
end
