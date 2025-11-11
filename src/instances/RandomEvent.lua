RTRandomEvent = {}
RTRandomEvent_mt = Class(RTRandomEvent)

function RTRandomEvent.new()
    local self = {}
    setmetatable(self, RTRandomEvent_mt)
    self.farmId = -1
    self.randomEventIndex = -1
    self.nextStage = 1
    self.nextCumulativeMonth = -1
    self.hoursToNextRun = 0

    return self
end

function RTRandomEvent:loadFromXMLFile(xmlFile, key)
    self.farmId = getXMLInt(xmlFile, key .. ".farmId") or -1
    self.randomEventIndex = getXMLInt(xmlFile, key .. ".randomEventIndex") or -1
    self.nextStage = getXMLInt(xmlFile, key .. ".nextStage") or -1
    self.nextCumulativeMonth = getXMLInt(xmlFile, key .. ".nextCumulativeMonth") or -1
    self.hoursToNextRun = getXMLInt(xmlFile, key .. ".hoursToNextRun") or 0
end

function RTRandomEvent:saveToXMLFile(xmlFile, key)
    setXMLInt(xmlFile, key .. ".farmId", self.farmId)
    setXMLInt(xmlFile, key .. ".randomEventIndex", self.randomEventIndex)
    setXMLInt(xmlFile, key .. ".nextStage", self.nextStage)
    setXMLInt(xmlFile, key .. ".nextCumulativeMonth", self.nextCumulativeMonth)
    setXMLInt(xmlFile, key .. ".hoursToNextRun", self.hoursToNextRun)
end

function RTRandomEvent:setHoursToNextRun(hours)
    self.hoursToNextRun = hours
    self.nextCumulativeMonth = -1
end

function RTRandomEvent:setNextCumulativeMonth(month)
    self.nextCumulativeMonth = month
    self.hoursToNextRun = 0
end

function RTRandomEvent:run()
end