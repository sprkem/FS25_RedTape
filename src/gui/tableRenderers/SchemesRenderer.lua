RTSchemesRenderer = {}
RTSchemesRenderer_mt = Class(RTSchemesRenderer)

function RTSchemesRenderer.new()
    local self = {}
    setmetatable(self, RTSchemesRenderer_mt)
    self.data = nil
    self.selectedRow = -1;
    self.indexChangedCallback = nil

    return self
end

function RTSchemesRenderer:setData(data)
    self.data = data
end

function RTSchemesRenderer:getNumberOfSections()
    return 1
end

function RTSchemesRenderer:getNumberOfItemsInSection(list, section)
    local menu = g_currentMission.RedTape.RedTapeMenu
    local selection = menu.schemeDisplaySwitcher:getState()
    return #self.data[selection]
end

function RTSchemesRenderer:getTitleForSectionHeader(list, section)
    return ""
end

function RTSchemesRenderer:populateCellForItemInSection(list, section, index, cell)
    local menu = g_currentMission.RedTape.RedTapeMenu
    local selection = menu.schemeDisplaySwitcher:getState()
    local scheme = self.data[selection][index]
    local rt = g_currentMission.RedTape

    cell:getAttribute("name"):setText(scheme:getName())
    cell:getAttribute("watched"):setVisible(scheme.watched)
end

function RTSchemesRenderer:onListSelectionChanged(list, section, index)
    self.selectedRow = index
    if self.indexChangedCallback ~= nil then
        self.indexChangedCallback(index)
    end
end
