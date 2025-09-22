EventLogRenderer = {}
EventLogRenderer_mt = Class(EventLogRenderer)

function EventLogRenderer.new()
    local self = {}
    setmetatable(self, EventLogRenderer_mt)
    self.data = nil
    self.selectedRow = -1;
    self.indexChangedCallback = nil

    return self
end

function EventLogRenderer:setData(data)
    self.data = data
end

function EventLogRenderer:getNumberOfSections()
    return 1
end

function EventLogRenderer:getNumberOfItemsInSection(list, section)
    return #self.data
end

function EventLogRenderer:getTitleForSectionHeader(list, section)
    return ""
end

function EventLogRenderer:populateCellForItemInSection(list, section, index, cell)
    local eventLogItem = self.data[index]

    cell:getAttribute("timestamp"):setText(eventLogItem:getTimeStampString())
    cell:getAttribute("eventType"):setText(g_i18n:getText(EventLogItem.EVENT_TYPE_LABELS[eventLogItem.eventType]))
    cell:getAttribute("detail"):setText(eventLogItem.detail)
end

function EventLogRenderer:onListSelectionChanged(list, section, index)
    self.selectedRow = index
    if self.indexChangedCallback ~= nil then
        self.indexChangedCallback(index)
    end
end
