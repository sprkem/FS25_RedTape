TaxSystem = {}
TaxSystem_mt = Class(TaxSystem)

TaxSystem.TAX_PERIOD = 2

function TaxSystem.new()
    local self = {}
    setmetatable(self, TaxSystem_mt)
    self.lineItems = {}

    g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, TaxSystem.periodChanged)

    self:loadFromXMLFile()
    return self
end

function TaxSystem:loadFromXMLFile()
    if (not g_currentMission:getIsServer()) then return end

    local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
    if savegameFolderPath == nil then
        savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
    end
    savegameFolderPath = savegameFolderPath .. "/"
    local key = "TaxSystem"

    if fileExists(savegameFolderPath .. "TaxSystem.xml") then
        local xmlFile = loadXMLFile(key, savegameFolderPath .. "TaxSystem.xml");

        local i = 0
        while true do
            local lineItemKey = string.format(key .. ".lineItems.lineItem(%d)", i)
            if not hasXMLProperty(xmlFile, lineItemKey) then
                break
            end

            local lineItem = TaxLineItem.new()
            lineItem:loadFromXMLFile(xmlFile, lineItemKey)
            table.insert(self.lineItems, lineItem)
            i = i + 1
        end

        delete(xmlFile)
    end
end

function TaxSystem:saveToXmlFile()
    if (not g_currentMission:getIsServer()) then return end

    local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory .. "/"
    if savegameFolderPath == nil then
        savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(),
            g_currentMission.missionInfo.savegameIndex .. "/")
    end

    local key = "TaxSystem";
    local xmlFile = createXMLFile(key, savegameFolderPath .. "TaxSystem.xml", key);

    local i = 0
    for _, group in pairs(self.lineItems) do
        local groupKey = string.format("%s.lineItems.lineItem(%d)", key, i)
        group:saveToXmlFile(xmlFile, groupKey)
        i = i + 1
    end

    saveXMLFile(xmlFile);
    delete(xmlFile);
end

function TaxSystem.periodChanged()
    local taxSystem = g_currentMission.RedTape.TaxSystem
    local period = g_currentMission.environment.currentPeriod
    if period == TaxSystem.TAX_PERIOD then
        -- Trigger tax calculation or any other logic needed for the tax period
        print("Tax due as period has changed to: " .. period)
        -- Here you can add logic to calculate taxes, update UI, etc.
    end
end
