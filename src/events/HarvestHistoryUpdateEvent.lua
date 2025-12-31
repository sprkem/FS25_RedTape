RTHarvestHistoryUpdateEvent = {}
local RTHarvestHistoryUpdateEvent_mt = Class(RTHarvestHistoryUpdateEvent, Event)

InitEventClass(RTHarvestHistoryUpdateEvent, "RTHarvestHistoryUpdateEvent")

function RTHarvestHistoryUpdateEvent.emptyNew()
    return Event.new(RTHarvestHistoryUpdateEvent_mt)
end

function RTHarvestHistoryUpdateEvent.new(farmlandId, cropName, month)
    local self = RTHarvestHistoryUpdateEvent.emptyNew()

    self.farmlandId = farmlandId
    self.cropName = cropName
    self.month = month

    return self
end

function RTHarvestHistoryUpdateEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmlandId)
    streamWriteString(streamId, self.cropName)
    streamWriteInt32(streamId, self.month)
end

function RTHarvestHistoryUpdateEvent:readStream(streamId, connection)
    self.farmlandId = streamReadInt32(streamId)
    self.cropName = streamReadString(streamId)
    self.month = streamReadInt32(streamId)
    self:run(connection)
end

function RTHarvestHistoryUpdateEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RTHarvestHistoryUpdateEvent.new(self.farmlandId, self.cropName, self.month))
    end

    local infoGatherer = g_currentMission.RedTape.InfoGatherer
    local farmlandGatherer = infoGatherer.gatherers[INFO_KEYS.FARMLANDS]
    local farmlandData = farmlandGatherer:getFarmlandData(self.farmlandId)

    if #farmlandData.harvestedCropsHistory > 0 then
        local mostRecentEntry = farmlandData.harvestedCropsHistory[1]
        if self.month <= mostRecentEntry.month then
            return
        end
    end

    local harvestEntry = {
        name = self.cropName,
        month = self.month
    }

    table.insert(farmlandData.harvestedCropsHistory, 1, harvestEntry)

    while #farmlandData.harvestedCropsHistory > 5 do
        table.remove(farmlandData.harvestedCropsHistory)
    end
end
