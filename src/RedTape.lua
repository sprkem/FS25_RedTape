RedTape = {}
RedTape.dir = g_currentModDirectory
RedTape.SaveKey = "RedTape"

source(RedTape.dir .. "src/gui/MenuRedTape.lua")

function RedTape:loadMap()
    g_currentMission.RedTape = self

    MessageType.EVENT_LOG_UPDATED = nextMessageTypeId()
    MessageType.SCHEMES_UPDATED = nextMessageTypeId()

    self.leaseDeals = {}
    self.constantChecksUpdateIntervalMs = 2000     -- interval for constant checks
    self.constantChecksUpdateTime = 5000           -- initial interval post load
    self.infrequentChecksUpdateIntervalMs = 300000 -- interval for infrequent checks
    self.infrequentChecksUpdateTime = 30000        -- initial interval for infrequent checks
    self.sprayAreaCheckInterval = 500              -- interval for spray area checks
    self.sprayCheckTime = 0                        -- initial time for spray area checks
    self.fillTypeCache = nil

    g_gui:loadProfiles(RedTape.dir .. "src/gui/guiProfiles.xml")

    local guiRedTape = MenuRedTape.new(g_i18n)
    g_gui:loadGui(RedTape.dir .. "src/gui/MenuRedTape.xml", "menuRedTape", guiRedTape, true)

    RedTape.addIngameMenuPage(guiRedTape, "menuRedTape", { 0, 0, 1024, 1024 },
        RedTape:makeCheckEnabledPredicate(), "pageSettings")
    guiRedTape:initialize()

    self.TaxSystem = TaxSystem.new()
    self.SchemeSystem = SchemeSystem.new()
    self.PolicySystem = PolicySystem.new()
    self.InfoGatherer = InfoGatherer.new()
    self.EventLog = EventLog.new()
    self.RedTapeMenu = guiRedTape

    g_messageCenter:subscribe(MessageType.HOUR_CHANGED, RedTape.hourChanged)
    g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, RedTape.periodChanged)

    self:loadFromXMLFile()
end

function RedTape:update(dt)
    if self.constantChecksUpdateTime > 0 then
        self.constantChecksUpdateTime = self.constantChecksUpdateTime - dt
    else
        self.InfoGatherer:runConstantChecks()
        self.constantChecksUpdateTime = self.constantChecksUpdateIntervalMs
    end

    if self.infrequentChecksUpdateTime > 0 then
        self.infrequentChecksUpdateTime = self.infrequentChecksUpdateTime - dt
    else
        self.InfoGatherer:runInfrequentChecks()
        self.infrequentChecksUpdateTime = self.infrequentChecksUpdateIntervalMs
    end

    self.SchemeSystem:checkPendingVehicles()
end

function RedTape:makeCheckEnabledPredicate()
    return function() return true end
end

function RedTape:hourChanged()
    if (not g_currentMission:getIsServer()) then return end
    local rt = g_currentMission.RedTape

    rt.InfoGatherer:hourChanged()
end

function RedTape:periodChanged()
    local rt = g_currentMission.RedTape
    rt.EventLog:pruneOld()

    if (not g_currentMission:getIsServer()) then return end
    rt.InfoGatherer:periodChanged()
    rt.PolicySystem:periodChanged()
    rt.SchemeSystem:periodChanged()
    rt.TaxSystem:periodChanged()
end

function RedTape:populateFillTypeCache()
    self.fillTypeCache = {}
    for k, v in pairs(g_fillTypeManager.indexToTitle) do
        self.fillTypeCache[v] = k
    end
end

function RedTape:getFillTypeCache()
    if self.fillTypeCache == nil then
        self:populateFillTypeCache()
    end
    return self.fillTypeCache
end

function RedTape:loadFromXMLFile()
    if (not g_currentMission:getIsServer()) then return end

    local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
    if savegameFolderPath == nil then
        savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
    end
    savegameFolderPath = savegameFolderPath .. "/"

    if fileExists(savegameFolderPath .. RedTape.SaveKey .. ".xml") then
        local xmlFile = loadXMLFile(RedTape.SaveKey, savegameFolderPath .. RedTape.SaveKey .. ".xml");
        g_currentMission.RedTape.PolicySystem:loadFromXMLFile(xmlFile)
        g_currentMission.RedTape.SchemeSystem:loadFromXMLFile(xmlFile)
        g_currentMission.RedTape.TaxSystem:loadFromXMLFile(xmlFile)
        g_currentMission.RedTape.EventLog:loadFromXMLFile(xmlFile)
        g_currentMission.RedTape.InfoGatherer:loadFromXMLFile(xmlFile)

        delete(xmlFile)
    end
end

function RedTape:saveToXmlFile()
    if (not g_currentMission:getIsServer()) then return end

    local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory .. "/"
    if savegameFolderPath == nil then
        savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(),
            g_currentMission.missionInfo.savegameIndex .. "/")
    end

    local xmlFile = createXMLFile(RedTape.SaveKey, savegameFolderPath .. RedTape.SaveKey .. ".xml", RedTape.SaveKey);

    g_currentMission.RedTape.PolicySystem:saveToXmlFile(xmlFile)
    g_currentMission.RedTape.SchemeSystem:saveToXmlFile(xmlFile)
    g_currentMission.RedTape.TaxSystem:saveToXmlFile(xmlFile)
    g_currentMission.RedTape.EventLog:saveToXmlFile(xmlFile)
    g_currentMission.RedTape.InfoGatherer:saveToXmlFile(xmlFile)

    saveXMLFile(xmlFile);
    delete(xmlFile);
end

-- from Courseplay
function RedTape.addIngameMenuPage(frame, pageName, uvs, predicateFunc, insertAfter)
    local targetPosition = 0

    -- remove all to avoid warnings
    for k, v in pairs({ pageName }) do
        g_inGameMenu.controlIDs[v] = nil
    end

    for i = 1, #g_inGameMenu.pagingElement.elements do
        local child = g_inGameMenu.pagingElement.elements[i]
        if child == g_inGameMenu[insertAfter] then
            targetPosition = i + 1;
            break
        end
    end

    g_inGameMenu[pageName] = frame
    g_inGameMenu.pagingElement:addElement(g_inGameMenu[pageName])

    g_inGameMenu:exposeControlsAsFields(pageName)

    for i = 1, #g_inGameMenu.pagingElement.elements do
        local child = g_inGameMenu.pagingElement.elements[i]
        if child == g_inGameMenu[pageName] then
            table.remove(g_inGameMenu.pagingElement.elements, i)
            table.insert(g_inGameMenu.pagingElement.elements, targetPosition, child)
            break
        end
    end

    for i = 1, #g_inGameMenu.pagingElement.pages do
        local child = g_inGameMenu.pagingElement.pages[i]
        if child.element == g_inGameMenu[pageName] then
            table.remove(g_inGameMenu.pagingElement.pages, i)
            table.insert(g_inGameMenu.pagingElement.pages, targetPosition, child)
            break
        end
    end

    g_inGameMenu.pagingElement:updateAbsolutePosition()
    g_inGameMenu.pagingElement:updatePageMapping()

    g_inGameMenu:registerPage(g_inGameMenu[pageName], nil, predicateFunc)

    local iconFileName = Utils.getFilename('images/menuIcon.dds', RedTape.dir)
    g_inGameMenu:addPageTab(g_inGameMenu[pageName], iconFileName, GuiUtils.getUVs(uvs))

    for i = 1, #g_inGameMenu.pageFrames do
        local child = g_inGameMenu.pageFrames[i]
        if child == g_inGameMenu[pageName] then
            table.remove(g_inGameMenu.pageFrames, i)
            table.insert(g_inGameMenu.pageFrames, targetPosition, child)
            break
        end
    end

    g_inGameMenu:rebuildTabList()
end

function RedTape.periodToMonth(period)
    period = period + 2
    if period > 12 then
        period = period - 12
    end
    return period
end

function RedTape.monthToString(month)
    if month == 1 then
        return g_i18n:getText("ui_month1")
    elseif month == 2 then
        return g_i18n:getText("ui_month2")
    elseif month == 3 then
        return g_i18n:getText("ui_month3")
    elseif month == 4 then
        return g_i18n:getText("ui_month4")
    elseif month == 5 then
        return g_i18n:getText("ui_month5")
    elseif month == 6 then
        return g_i18n:getText("ui_month6")
    elseif month == 7 then
        return g_i18n:getText("ui_month7")
    elseif month == 8 then
        return g_i18n:getText("ui_month8")
    elseif month == 9 then
        return g_i18n:getText("ui_month9")
    elseif month == 10 then
        return g_i18n:getText("ui_month10")
    elseif month == 11 then
        return g_i18n:getText("ui_month11")
    elseif month == 12 then
        return g_i18n:getText("ui_month12")
    end
end

function RedTape.tableHasValue(tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function RedTape.tableHasKey(tab, key)
    return tab[key] ~= nil
end

function RedTape.tableCount(tab)
    local count = 0

    if type(tab) ~= "table" then
        print("RedTape.tableCount called on non-table value")
        return 0
    end

    for _, _ in pairs(tab) do
        count = count + 1
    end
    return count
end

function RedTape.generateId()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return (string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end))
end

function RedTape.getCumulativeMonth()
    local month = RedTape.periodToMonth(g_currentMission.environment.currentPeriod)
    local year = g_currentMission.environment.currentYear - 1
    return (year * 12) + month
end

FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, RedTape.saveToXmlFile)

addModEventListener(RedTape)
