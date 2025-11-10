RTRandomEvent = {}
RTRandomEvent_mt = Class(RTRandomEvent)

function RTRandomEvent.new()
    local self = {}
    setmetatable(self, RTRandomEvent_mt)
    self.farmId = -1
    self.randomEventIndex = -1

    return self
end

function RTRandomEvent:loadFromXMLFile(xmlFile, key)
    self.farmId = getXMLInt(xmlFile, key .. ".farmId") or -1
    self.randomEventIndex = getXMLInt(xmlFile, key .. ".randomEventIndex") or -1
end

function RTRandomEvent:saveToXMLFile(xmlFile, key)
    setXMLInt(xmlFile, key .. ".farmId", self.farmId)
    setXMLInt(xmlFile, key .. ".randomEventIndex", self.randomEventIndex)
end
