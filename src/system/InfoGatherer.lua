InfoGatherer = {}
InfoGatherer_mt = Class(InfoGatherer)

function InfoGatherer.new()
    local self = {}
    setmetatable(self, InfoGatherer_mt)
    return self
end

function InfoGatherer:gatherData(data)
    print("Gathering data for policies...")
    return {}
end
