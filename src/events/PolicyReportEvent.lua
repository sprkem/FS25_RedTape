RTPolicyReportEvent = {}
local RTPolicyReportEvent_mt = Class(RTPolicyReportEvent, Event)

InitEventClass(RTPolicyReportEvent, "RTPolicyReportEvent")

function RTPolicyReportEvent.emptyNew()
    local self = Event.new(RTPolicyReportEvent_mt)

    return self
end

function RTPolicyReportEvent.new(policyIndex, farmId, report)
    local self = RTPolicyReportEvent.emptyNew()
    self.policyIndex = policyIndex
    self.farmId = farmId
    self.report = report
    return self
end

function RTPolicyReportEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.policyIndex)
    streamWriteInt32(streamId, RedTape.tableCount(self.report))

    for _, reportItem in pairs(self.report) do
        streamWriteString(streamId, reportItem.cell1)
        streamWriteString(streamId, reportItem.cell2)
        streamWriteString(streamId, reportItem.cell3)
    end
end

function RTPolicyReportEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.policyIndex = streamReadInt32(streamId)

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

function RTPolicyReportEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTPolicyReportEvent.new(self.policyIndex, self.farmId, self.report))
    end

    local policySystem = g_currentMission.RedTape.PolicySystem
    for _, policy in pairs(policySystem.policies) do
        if policy.policyIndex == self.policyIndex then
            policy.evaluationReports[self.farmId] = self.report
            break
        end
    end
end
