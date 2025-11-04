RTSchemeReportEvent = {}
local RTSchemeReportEvent_mt = Class(RTSchemeReportEvent, Event)

InitEventClass(RTSchemeReportEvent, "RTSchemeReportEvent")

function RTSchemeReportEvent.emptyNew()
    local self = Event.new(RTSchemeReportEvent_mt)

    return self
end

function RTSchemeReportEvent.new(schemeId, farmId, report)
    local self = RTSchemeReportEvent.emptyNew()
    self.schemeId = schemeId
    self.farmId = farmId
    self.report = report
    return self
end

function RTSchemeReportEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.schemeId)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, RedTape.tableCount(self.report))

    for _, reportItem in pairs(self.report) do
        streamWriteString(streamId, reportItem.cell1)
        streamWriteString(streamId, reportItem.cell2)
        streamWriteString(streamId, reportItem.cell3)
    end
end

function RTSchemeReportEvent:readStream(streamId, connection)
    self.schemeId = streamReadString(streamId)
    self.farmId = streamReadInt32(streamId)

    local reportCount = streamReadInt32(streamId)
    self.report = {}
    for i = 1, reportCount do
        local reportItem = {
            cell1 = streamReadString(streamId),
            cell2 = streamReadString(streamId),
            cell3 = streamReadString(streamId)
        }
        table.insert(self.report, reportItem)
    end

    self:run(connection)
end

function RTSchemeReportEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTSchemeReportEvent.new(self.schemeId, self.farmId, self.report))
    end

    local schemeSystem = g_currentMission.RedTape.SchemeSystem
    local schemes = schemeSystem:getActiveSchemesForFarm(self.farmId)
    for _, scheme in pairs(schemes) do
        if scheme.id == self.schemeId then
            scheme.lastEvaluationReport = self.report
            break
        end
    end
end
