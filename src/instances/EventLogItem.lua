RTEventLogItem = {}
RTEventLogItem_mt = Class(RTEventLogItem)

RTEventLogItem.EVENT_TYPE = {
    NONE = 1,
    POLICY_POINTS = 2,
    POLICY_ACTIVATED = 3,
    POLICY_COMPLETED = 4,
    SCHEME_ACTIVATED = 5,
    SCHEME_PAYOUT = 6,
    SCHEME_EXPIRED = 7,
    POLICY_WARNING = 8,
    POLICY_FINE = 9,
    GRANT_APPROVED = 10,
    GRANT_REJECTED = 11,
    GRANT_COMPLETED = 12
}

RTEventLogItem.EVENT_TYPE_LABELS = {
    [RTEventLogItem.EVENT_TYPE.NONE] = "rt_event_type_none",
    [RTEventLogItem.EVENT_TYPE.POLICY_POINTS] = "rt_event_type_policypoints",
    [RTEventLogItem.EVENT_TYPE.POLICY_ACTIVATED] = "rt_event_type_policyactivated",
    [RTEventLogItem.EVENT_TYPE.POLICY_COMPLETED] = "rt_event_type_policycompleted",
    [RTEventLogItem.EVENT_TYPE.SCHEME_ACTIVATED] = "rt_event_type_schemeactivated",
    [RTEventLogItem.EVENT_TYPE.SCHEME_PAYOUT] = "rt_event_type_schemepayout",
    [RTEventLogItem.EVENT_TYPE.SCHEME_EXPIRED] = "rt_event_type_schemeexpired",
    [RTEventLogItem.EVENT_TYPE.POLICY_WARNING] = "rt_event_type_policywarning",
    [RTEventLogItem.EVENT_TYPE.POLICY_FINE] = "rt_event_type_policyfine",
    [RTEventLogItem.EVENT_TYPE.GRANT_APPROVED] = "rt_event_type_grantapproved",
    [RTEventLogItem.EVENT_TYPE.GRANT_REJECTED] = "rt_event_type_grantrejected",
    [RTEventLogItem.EVENT_TYPE.GRANT_COMPLETED] = "rt_event_type_grantcompleted"
}

function RTEventLogItem.new()
    local self = {}
    setmetatable(self, RTEventLogItem_mt)

    self.farmId = -1
    self.eventType = RTEventLogItem.EVENT_TYPE.NONE
    self.detail = ""
    self.month = 0
    self.year = 0
    self.hour = 0

    return self
end

function RTEventLogItem:getTimeStampString()
    local rt = g_currentMission.RedTape
    return string.format("%s %s %d", rt.monthToString(self.month), g_i18n:getText("rt_misc_year"), self.year)
end

function RTEventLogItem:saveToXmlFile(xmlFile, key)
    setXMLInt(xmlFile, key .. "#farmId", self.farmId)
    setXMLInt(xmlFile, key .. "#eventType", self.eventType)
    setXMLString(xmlFile, key .. "#detail", self.detail)
    setXMLInt(xmlFile, key .. "#month", self.month)
    setXMLInt(xmlFile, key .. "#year", self.year)
    setXMLInt(xmlFile, key .. "#hour", self.hour)
end

function RTEventLogItem:loadFromXMLFile(xmlFile, key)
    self.farmId = getXMLInt(xmlFile, key .. "#farmId")
    self.eventType = getXMLInt(xmlFile, key .. "#eventType")
    self.detail = getXMLString(xmlFile, key .. "#detail")
    self.month = getXMLInt(xmlFile, key .. "#month")
    self.year = getXMLInt(xmlFile, key .. "#year")
    self.hour = getXMLInt(xmlFile, key .. "#hour") or 0
end

function RTEventLogItem:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.eventType)
    streamWriteString(streamId, self.detail)
    streamWriteInt32(streamId, self.month)
    streamWriteInt32(streamId, self.year)
    streamWriteInt32(streamId, self.hour)
end

function RTEventLogItem:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.eventType = streamReadInt32(streamId)
    self.detail = streamReadString(streamId)
    self.month = streamReadInt32(streamId)
    self.year = streamReadInt32(streamId)
    self.hour = streamReadInt32(streamId)
end
