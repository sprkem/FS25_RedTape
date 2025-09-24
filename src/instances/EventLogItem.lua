EventLogItem = {}
EventLogItem_mt = Class(EventLogItem)

EventLogItem.EVENT_TYPE = {
    NONE = 1,
    POLICY_POINTS = 2,
    POLICY_ACTIVATED = 3,
    POLICY_COMPLETED = 4,
    SCHEME_ACTIVATED = 5,
    SCHEME_PAYOUT = 6
}

EventLogItem.EVENT_TYPE_LABELS = {
    [EventLogItem.EVENT_TYPE.NONE] = "rt_event_type_none",
    [EventLogItem.EVENT_TYPE.POLICY_POINTS] = "rt_event_type_policypoints",
    [EventLogItem.EVENT_TYPE.POLICY_ACTIVATED] = "rt_event_type_policyactivated",
    [EventLogItem.EVENT_TYPE.POLICY_COMPLETED] = "rt_event_type_policycompleted",
    [EventLogItem.EVENT_TYPE.SCHEME_ACTIVATED] = "rt_event_type_schemeactivated",
    [EventLogItem.EVENT_TYPE.SCHEME_PAYOUT] = "rt_event_type_schemepayout"
}

function EventLogItem.new()
    local self = {}
    setmetatable(self, EventLogItem_mt)

    self.farmId = -1
    self.eventType = EventLogItem.EVENT_TYPE.NONE
    self.detail = ""
    self.month = 0
    self.year = 0

    return self
end

function EventLogItem:getTimeStampString()
    local rt = g_currentMission.RedTape
    return string.format("%s %s %d", rt.monthToString(self.month), g_i18n:getText("rt_misc_year"), self.year)
end

function EventLogItem:saveToXmlFile(xmlFile, key)
    setXMLInt(xmlFile, key .. "#farmId", self.farmId)
    setXMLInt(xmlFile, key .. "#eventType", self.eventType)
    setXMLString(xmlFile, key .. "#detail", self.detail)
    setXMLInt(xmlFile, key .. "#month", self.month)
    setXMLInt(xmlFile, key .. "#year", self.year)
end

function EventLogItem:loadFromXMLFile(xmlFile, key)
    self.farmId = getXMLInt(xmlFile, key .. "#farmId")
    self.eventType = getXMLInt(xmlFile, key .. "#eventType")
    self.detail = getXMLString(xmlFile, key .. "#detail")
    self.month = getXMLInt(xmlFile, key .. "#month")
    self.year = getXMLInt(xmlFile, key .. "#year")
end
