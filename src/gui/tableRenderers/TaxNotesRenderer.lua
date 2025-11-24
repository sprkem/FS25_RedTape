RTTaxNotesRenderer = {}
RTTaxNotesRenderer_mt = Class(RTTaxNotesRenderer)

function RTTaxNotesRenderer.new()
    local self = {}
    setmetatable(self, RTTaxNotesRenderer_mt)
    self.data = nil
    self.selectedRow = -1;

    return self
end

function RTTaxNotesRenderer:setData(data)
    self.data = data
end

function RTTaxNotesRenderer:getNumberOfSections()
    return 1
end

function RTTaxNotesRenderer:getNumberOfItemsInSection(list, section)
    return #self.data
end

function RTTaxNotesRenderer:getTitleForSectionHeader(list, section)
    return ""
end

function RTTaxNotesRenderer:populateCellForItemInSection(list, section, index, cell)
    local note = self.data[index]

    cell:getAttribute("note"):setText(note)
end