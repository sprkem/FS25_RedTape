SchemeSystem = {}
SchemeSystem_mt = Class(SchemeSystem)

SchemeSystem.OPEN_SCHEMES_PER_TIER = 10

function SchemeSystem.new()
    local self = {}
    setmetatable(self, SchemeSystem_mt)
    self.availableSchemes = {
        [PolicySystem.TIER.A] = {},
        [PolicySystem.TIER.B] = {},
        [PolicySystem.TIER.C] = {},
        [PolicySystem.TIER.D] = {}
    }
    self.activeSchemesByFarm = {}

    self:loadFromXMLFile()

    return self
end

function SchemeSystem:loadFromXMLFile()
    if (not g_currentMission:getIsServer()) then return end

    local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
    if savegameFolderPath == nil then
        savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
    end
    savegameFolderPath = savegameFolderPath .. "/"
    local key = "SchemeSystem"

    if fileExists(savegameFolderPath .. "RedTape.xml") then
        local xmlFile = loadXMLFile(key, savegameFolderPath .. "RedTape.xml");

        local i = 0
        while true do
            local schemeKey = string.format(key .. ".schemes.scheme(%d)", i)
            if not hasXMLProperty(xmlFile, schemeKey) then
                break
            end

            local scheme = Scheme.new()
            scheme:loadFromXMLFile(xmlFile, schemeKey)
            table.insert(self.availableSchemes, scheme)
            i = i + 1
        end

        delete(xmlFile)
    end
end

function SchemeSystem:saveToXmlFile()
    if (not g_currentMission:getIsServer()) then return end

    local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory .. "/"
    if savegameFolderPath == nil then
        savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(),
            g_currentMission.missionInfo.savegameIndex .. "/")
    end

    local key = "SchemeSystem";
    local xmlFile = createXMLFile(key, savegameFolderPath .. "RedTape.xml", key);

    local i = 0
    for _, scheme in pairs(self.availableSchemes) do
        local schemeKey = string.format("%s.schemes.scheme(%d)", key, i)
        scheme:saveToXmlFile(xmlFile, schemeKey)
        i = i + 1
    end

    saveXMLFile(xmlFile);
    delete(xmlFile);
end

function SchemeSystem:hourChanged()
end

function SchemeSystem:periodChanged()
    local schemeSystem = g_currentMission.RedTape.SchemeSystem

    for farm, schemes in pairs(schemeSystem.activeSchemesByFarm) do
        for _, scheme in pairs(schemes) do
            scheme:evaluate()
        end
    end

    schemeSystem:generateSchemes()
end

function SchemeSystem:generateSchemes()
    local rt = g_currentMission.RedTape

    for tier, schemes in pairs(self.availableSchemes) do
        local existingCount = rt:tableCount(schemes)
        if existingCount < SchemeSystem.OPEN_SCHEMES_PER_TIER then
            print("Generating new schemes for tier " .. tier)
            local toCreate = SchemeSystem.OPEN_SCHEMES_PER_TIER - existingCount
            for i = 1, toCreate do
                local scheme = Scheme.new()
                scheme.tier = tier
                scheme.schemeIndex = self:getNextSchemeIndex(tier)

                if scheme.schemeIndex == nil then
                    print("No more schemes available for tier " .. tier)
                    break
                end

                scheme:initialise()
                g_client:getServerConnection():sendEvent(SchemeActivatedEvent.new(scheme))
            end
        end
    end
end

function SchemeSystem:getNextSchemeIndex(tier)
    local rt = g_currentMission.RedTape
    local currentSchemeDupeKeys = {}
    for _, scheme in pairs(self.availableSchemes[tier]) do
        table.insert(currentSchemeDupeKeys, scheme.duplicationKey)
    end

    local availableSchemes = {}
    for _, schemeInfo in pairs(Schemes) do
        if rt:tableHasKey(schemeInfo.tiers, tier) and not rt:tableHasValue(currentSchemeDupeKeys, schemeInfo.duplicationKey) then
            table.insert(availableSchemes, schemeInfo)
        end
    end

    local totalProbability = 0
    for _, scheme in pairs(availableSchemes) do
        totalProbability = totalProbability + scheme.probability
    end

    if totalProbability == 0 then
        return nil -- No available schemes to choose from
    end

    local randomValue = math.random() * totalProbability
    local cumulativeProbability = 0
    for _, scheme in pairs(availableSchemes) do
        cumulativeProbability = cumulativeProbability + scheme.probability
        if randomValue <= cumulativeProbability then
            return scheme.id
        end
    end

    return nil
end

-- Called by PolicyActivatedEvent, runs on Client and Server
function SchemeSystem:registerActivatedScheme(scheme)
    table.insert(self.availableSchemes[scheme.tier], scheme)
    local available = scheme:availableForCurrentFarm()
    g_currentMission.RedTape.EventLog:addEvent(nil, EventLogItem.EVENT_TYPE.SCHEME_ACTIVATED,
        string.format(g_i18n:getText("rt_notify_active_scheme"), scheme:getName()), available)
end

-- Called by SchemeSelectedEvent, runs on Client and Server
function SchemeSystem:registerSelectedScheme(scheme, farmId)
    local activeSchemes = self:getActiveSchemesForFarm(farmId)

    local schemeForFarm = scheme:createFarmScheme(farmId)
    table.insert(activeSchemes, schemeForFarm)
end

function SchemeSystem:getActiveSchemesForFarm(farmId)
    if self.activeSchemesByFarm[farmId] == nil then
        self.activeSchemesByFarm[farmId] = {}
    end

    return self.activeSchemesByFarm[farmId]
end

function SchemeSystem:getAvailableSchemesForCurrentFarm()
    local availableForFarm = {}

    local policySystem = g_currentMission.RedTape.PolicySystem
    local farmTier = policySystem:getProgressForCurrentFarm().tier
    for _, scheme in pairs(self.availableSchemes[farmTier]) do
        if scheme:availableForCurrentFarm() then
            table.insert(availableForFarm, scheme)
        end
    end

    return availableForFarm
end
