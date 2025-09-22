SchemesRenderer = {}
SchemesRenderer_mt = Class(SchemesRenderer)

function SchemesRenderer.new()
    local self = {}
    setmetatable(self, SchemesRenderer_mt)
    self.data = nil
    self.selectedRow = -1;
    self.indexChangedCallback = nil

    return self
end

function SchemesRenderer:setData(data)
    self.data = data
end

function SchemesRenderer:getNumberOfSections()
    return 1
end

function SchemesRenderer:getNumberOfItemsInSection(list, section)
    local menu = g_currentMission.RedTape.RedTapeMenu
    local selection = menu.schemeDisplaySwitcher:getState()
    return #self.data[selection]
end

function SchemesRenderer:getTitleForSectionHeader(list, section)
    return ""
end

function SchemesRenderer:populateCellForItemInSection(list, section, index, cell)
    local menu = g_currentMission.RedTape.RedTapeMenu
    local selection = menu.schemeDisplaySwitcher:getState()
    local scheme = self.data[selection][index]
    local rt = g_currentMission.RedTape

    cell:getAttribute("name"):setText(scheme:getName())
end

function SchemesRenderer:onListSelectionChanged(list, section, index)
    self.selectedRow = index
    if self.indexChangedCallback ~= nil then
        self.indexChangedCallback(index)
    end
end
