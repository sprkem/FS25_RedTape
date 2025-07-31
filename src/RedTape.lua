RedTape = {}
RedTape.dir = g_currentModDirectory

source(RedTape.dir .. "src/gui/MenuRedTape.lua")

function RedTape:loadMap()
    self.leaseDeals = {}
    self.updateIntervalMs = 1000
	self.updateTime = 5000

    -- g_gui:loadProfiles(RedTape.dir .. "src/gui/guiProfiles.xml")

    local guiRedTape = MenuRedTape.new(g_i18n)
    g_gui:loadGui(RedTape.dir .. "src/gui/MenuRedTape.xml", "menuRedTape", guiRedTape, true)

    RedTape.addIngameMenuPage(guiRedTape, "menuRedTape", { 0, 0, 1024, 1024 },
        RedTape:makeCheckEnabledPredicate(), "pageSettings")

    self.TaxSystem = TaxSystem.new()
    self.SchemeSystem = SchemeSystem.new()
    self.PolicySystem = PolicySystem.new()
    self.InfoGatherer = InfoGatherer.new()
    self.data = self.InfoGatherer:initData()

    g_messageCenter:subscribe(MessageType.HOUR_CHANGED, RedTape.hourChanged)
    g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, RedTape.periodChanged)

    g_currentMission.RedTape = self
end

function RedTape:update(dt)
    if self.updateTime > 0 then
		self.updateTime = self.updateTime - dt
	else
		self.InfoGatherer:runConstantChecks()
        self.updateTime = self.updateIntervalMs
	end
end

function RedTape:makeCheckEnabledPredicate()
    return function() return true end
end

function RedTape:hourChanged()
    if (not g_currentMission:getIsServer()) then return end
end

function RedTape:periodChanged()
    if (not g_currentMission:getIsServer()) then return end
    local rt = g_currentMission.RedTape
    rt.InfoGatherer:gatherData()
    rt.PolicySystem:periodChanged()
    rt.SchemeSystem:periodChanged()
    rt.TaxSystem:periodChanged()
end

function RedTape:saveToXmlFile()
    g_currentMission.RedTape.PolicySystem:saveToXmlFile()
    g_currentMission.RedTape.SchemeSystem:saveToXmlFile()
    g_currentMission.RedTape.TaxSystem:saveToXmlFile()
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

function RedTape:tableHasValue(tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, RedTape.saveToXmlFile)

addModEventListener(RedTape)
