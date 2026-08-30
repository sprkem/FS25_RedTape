RedTape.SETTINGS = {}
RedTape.CONTROLS = {}

RedTape.menuItems = {
    'taxEnabled',
    'taxRecordingEnabled',
    'policiesAndSchemesEnabled',
    'grantsEnabled',
    'baseTaxRate',
    'productivityRecovery',
    'manureStorageLimit',
    'slurryRestrictionStart'
}

-- Everything above is a core setting. The per policy enforcement toggles built further down are
-- appended to menuItems (so saving, loading and syncing pick them up automatically) but are also
-- tracked on their own so the settings menu can group them under their own header.
RedTape.coreMenuItems = { table.unpack(RedTape.menuItems) }
RedTape.policyMenuItems = {}
RedTape.policySettingIdByPolicyId = {}

RedTape.multiplayerPermissions = {
    'redTapeSettings'
}

Farm.PERMISSION['RED_TAPE_SETTINGS'] = "redTapeSettings"
table.insert(Farm.PERMISSIONS, Farm.PERMISSION.RED_TAPE_SETTINGS)

--SERVER SETTINGS
RedTape.SETTINGS.taxEnabled = {
    ['default'] = 1,
    ['serverOnly'] = true,
    ['permission'] = 'redTapeSettings',
    ['values'] = { true, false },
    ['strings'] = {
        g_i18n:getText("ui_on"),
        g_i18n:getText("ui_off")
    }
}

RedTape.SETTINGS.taxRecordingEnabled = {
    ['default'] = 1,
    ['serverOnly'] = true,
    ['permission'] = 'redTapeSettings',
    ['values'] = { true, false },
    ['strings'] = {
        g_i18n:getText("ui_on"),
        g_i18n:getText("ui_off")
    }
}

RedTape.SETTINGS.policiesAndSchemesEnabled = {
    ['default'] = 1,
    ['serverOnly'] = true,
    ['permission'] = 'redTapeSettings',
    ['values'] = { true, false },
    ['strings'] = {
        g_i18n:getText("ui_on"),
        g_i18n:getText("ui_off")
    }
}

RedTape.SETTINGS.grantsEnabled = {
    ['default'] = 1,
    ['serverOnly'] = true,
    ['permission'] = 'redTapeSettings',
    ['values'] = { true, false },
    ['strings'] = {
        g_i18n:getText("ui_on"),
        g_i18n:getText("ui_off")
    }
}

RedTape.SETTINGS.baseTaxRate = {
    ['default'] = 2,
    ['serverOnly'] = true,
    ['permission'] = 'redTapeSettings',
    ['values'] = { 10, 20, 30, 40 },
    ['strings'] = {
        "10%",
        "20%",
        "30%",
        "40%"
    }
}

RedTape.SETTINGS.productivityRecovery = {
    ['default'] = 1,
    ['serverOnly'] = true,
    ['permission'] = 'redTapeSettings',
    ['values'] = { 1, 2, 4, 6, 8, 0 },
    ['strings'] = {
        "1x",
        "2x",
        "4x",
        "6x",
        "8x",
        g_i18n:getText("rt_setting_instant")
    }
}

-- The restricted slurry window is a UK-style closed period. Other countries run the same
-- kind of ban but start it in a different month, so the start is configurable and the window
-- length stays fixed.
RedTape.SETTINGS.slurryRestrictionStart = {
    ['default'] = 9,
    ['serverOnly'] = true,
    ['permission'] = 'redTapeSettings',
    ['values'] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 },
    ['strings'] = {
        g_i18n:getText("ui_month1"),
        g_i18n:getText("ui_month2"),
        g_i18n:getText("ui_month3"),
        g_i18n:getText("ui_month4"),
        g_i18n:getText("ui_month5"),
        g_i18n:getText("ui_month6"),
        g_i18n:getText("ui_month7"),
        g_i18n:getText("ui_month8"),
        g_i18n:getText("ui_month9"),
        g_i18n:getText("ui_month10"),
        g_i18n:getText("ui_month11"),
        g_i18n:getText("ui_month12")
    }
}

RedTape.SETTINGS.manureStorageLimit = {
    ['default'] = 1,
    ['serverOnly'] = true,
    ['permission'] = 'redTapeSettings',
    ['values'] = { 5000, 10000, 20000, 50000, 100000 },
    ['strings'] = {
        "5,000",
        "10,000",
        "20,000",
        "50,000",
        "100,000"
    }
}

--- PER POLICY ENFORCEMENT TOGGLES
-- One on/off setting per entry in RTPolicies so a server can pick which rules it actually wants
-- to enforce. Generated rather than hand written, so adding a policy to RTPolicies is all that is
-- needed to get a setting for it. They share a single tooltip translation, formatted with the
-- policy name, and use the policy name itself as their label.
do
    local policyKeysById = {}
    for key, policyId in pairs(RTPolicyIds) do
        policyKeysById[policyId] = key
    end

    -- Sorted by policy id so both the menu order and the multiplayer stream order are stable
    local sortedPolicyIds = {}
    for policyId in pairs(RTPolicies) do
        table.insert(sortedPolicyIds, policyId)
    end
    table.sort(sortedPolicyIds)

    for _, policyId in ipairs(sortedPolicyIds) do
        local policyInfo = RTPolicies[policyId]
        local settingId = 'policyEnabled_' .. (policyKeysById[policyId] or tostring(policyId))
        local policyName = g_i18n:getText(policyInfo.name)

        RedTape.SETTINGS[settingId] = {
            ['default'] = 1,
            ['serverOnly'] = true,
            ['permission'] = 'redTapeSettings',
            ['values'] = { true, false },
            ['strings'] = {
                g_i18n:getText("ui_on"),
                g_i18n:getText("ui_off")
            },
            -- Policy toggles have no translations of their own, so the label and tooltip are
            -- supplied here instead of being looked up from rt_setting_/rt_toolTip_ keys
            ['title'] = policyName,
            ['toolTip'] = string.format(g_i18n:getText("rt_toolTip_policyEnabled"), policyName),
            ['policyId'] = policyId
        }

        RedTape.policySettingIdByPolicyId[policyId] = settingId
        table.insert(RedTape.policyMenuItems, settingId)
        table.insert(RedTape.menuItems, settingId)
    end
end

--- Whether a policy is currently enforced. A policy with no setting (or with a setting that has
--- not been read yet) counts as enforced, so a missing value can never silently switch a rule off.
function RedTape.isPolicyEnforced(policyId)
    local settingId = RedTape.policySettingIdByPolicyId[policyId]
    if settingId == nil then
        return true
    end

    local value = g_currentMission.RedTape.settings[settingId]
    if value == nil then
        return true
    end

    return value
end

function RedTape.SETTINGS.writeToStream(streamId)
    local settings = g_currentMission.RedTape.settings
    streamWriteBool(streamId, settings.taxEnabled)
    streamWriteBool(streamId, settings.taxRecordingEnabled)
    streamWriteBool(streamId, settings.policiesAndSchemesEnabled)
    streamWriteBool(streamId, settings.grantsEnabled)
    streamWriteFloat32(streamId, settings.baseTaxRate)
    streamWriteInt32(streamId, settings.productivityRecovery)
    streamWriteInt32(streamId, settings.manureStorageLimit)
    streamWriteInt32(streamId, settings.slurryRestrictionStart)

    for _, id in ipairs(RedTape.policyMenuItems) do
        streamWriteBool(streamId, settings[id] ~= false)
    end
end

function RedTape.SETTINGS.readFromStream(streamId)
    local settings = g_currentMission.RedTape.settings
    settings.taxEnabled = streamReadBool(streamId)
    settings.taxRecordingEnabled = streamReadBool(streamId)
    settings.policiesAndSchemesEnabled = streamReadBool(streamId)
    settings.grantsEnabled = streamReadBool(streamId)
    settings.baseTaxRate = streamReadFloat32(streamId)
    settings.productivityRecovery = streamReadInt32(streamId)
    settings.manureStorageLimit = streamReadInt32(streamId)
    settings.slurryRestrictionStart = streamReadInt32(streamId)

    for _, id in ipairs(RedTape.policyMenuItems) do
        settings[id] = streamReadBool(streamId)
    end
end

function RedTape.getStateIndex(id, value)
    local value = value or g_currentMission.RedTape.settings[id]
    local values = RedTape.SETTINGS[id].values
    if type(value) == 'number' then
        local index = RedTape.SETTINGS[id].default
        local initialdiff = math.huge
        for i, v in pairs(values) do
            local currentdiff = math.abs(v - value)
            if currentdiff < initialdiff then
                initialdiff = currentdiff
                index = i
            end
        end
        return index
    else
        for i, v in pairs(values) do
            if value == v then
                return i
            end
        end
    end
    return RedTape.SETTINGS[id].default
end

--- Settings that carry their own label and tooltip (the generated policy toggles) use those;
--- everything else falls back to its rt_setting_/rt_toolTip_ translation keys.
function RedTape.getSettingTitle(id)
    return RedTape.SETTINGS[id].title or g_i18n:getText("rt_setting_" .. id)
end

function RedTape.getSettingToolTip(id)
    return RedTape.SETTINGS[id].toolTip or g_i18n:getText("rt_toolTip_" .. id)
end

RedTapeControls = {}
function RedTapeControls.onMenuOptionChanged(self, state, menuOption)
    local id = menuOption.id
    local setting = RedTape.SETTINGS
    local value = setting[id].values[state]

    if value ~= nil then
        g_currentMission.RedTape.settings[id] = value
    end

    g_client:getServerConnection():sendEvent(RTSettingsEvent.new())
end

local function updateFocusIds(element)
    if not element then
        return
    end
    element.focusId = FocusManager:serveAutoFocusId()
    for _, child in pairs(element.elements) do
        updateFocusIds(child)
    end
end

function RedTape.injectMenu()
    local inGameMenu = g_gui.screenControllers[InGameMenu]
    local settingsPage = inGameMenu.pageSettings
    -- The name is required as otherwise the focus manager would ignore any control which has RedTape as a callback target, believing it belonged to a different UI
    RedTapeControls.name = settingsPage.name

    function RedTape.addBinaryMenuOption(id)
        local callback = "onMenuOptionChanged"
        local titleText = RedTape.getSettingTitle(id)
        local toolTipText = RedTape.getSettingToolTip(id)
        local options = RedTape.SETTINGS[id].strings

        local originalBox = settingsPage.checkWoodHarvesterAutoCutBox

        local menuOptionBox = originalBox:clone(settingsPage.gameSettingsLayout)
        menuOptionBox.id = id .. "box"

        local menuBinaryOption = menuOptionBox.elements[1]
        menuBinaryOption.id = id
        menuBinaryOption.target = RedTapeControls


        menuBinaryOption:setCallback("onClickCallback", callback)
        menuBinaryOption:setDisabled(false)


        local toolTip = menuBinaryOption.elements[1]
        toolTip:setText(toolTipText)

        local setting = menuOptionBox.elements[2]
        setting:setText(titleText)

        menuBinaryOption:setTexts({ table.unpack(options) })
        menuBinaryOption:setState(RedTape.getStateIndex(id))

        RedTape.CONTROLS[id] = menuBinaryOption

        -- Assign new focus IDs to the controls as clone() copies the existing ones which are supposed to be unique
        updateFocusIds(menuOptionBox)
        table.insert(settingsPage.controlsList, menuOptionBox)
        return menuOptionBox
    end

    function RedTape.addMultiMenuOption(id)
        local callback = "onMenuOptionChanged"
        local titleText = RedTape.getSettingTitle(id)
        local toolTipText = RedTape.getSettingToolTip(id)
        local options = RedTape.SETTINGS[id].strings

        local originalBox = settingsPage.multiVolumeVoiceBox

        local menuOptionBox = originalBox:clone(settingsPage.gameSettingsLayout)
        menuOptionBox.id = id .. "box"

        local menuMultiOption = menuOptionBox.elements[1]
        menuMultiOption.id = id
        menuMultiOption.target = RedTapeControls


        menuMultiOption:setCallback("onClickCallback", callback)
        menuMultiOption:setDisabled(false)


        local toolTip = menuMultiOption.elements[1]
        toolTip:setText(toolTipText)

        local setting = menuOptionBox.elements[2]
        setting:setText(titleText)

        menuMultiOption:setTexts({ table.unpack(options) })
        menuMultiOption:setState(RedTape.getStateIndex(id))

        RedTape.CONTROLS[id] = menuMultiOption

        -- Assign new focus IDs to the controls as clone() copies the existing ones which are supposed to be unique
        updateFocusIds(menuOptionBox)
        table.insert(settingsPage.controlsList, menuMultiOption)
        return menuOptionBox
    end

    -- Add section. controlKey has to be unique per header, otherwise a later header would
    -- replace an earlier one in RedTape.CONTROLS and never reach the focus manager.
    local function addSectionTitle(text, controlKey)
        local sectionTitle = nil
        for idx, elem in ipairs(settingsPage.gameSettingsLayout.elements) do
            if elem.name == "sectionHeader" then
                sectionTitle = elem:clone(settingsPage.gameSettingsLayout)
                break
            end
        end

        if sectionTitle == nil then
            sectionTitle = TextElement.new()
            sectionTitle:applyProfile("fs25_settingsSectionHeader", true)
            sectionTitle.name = "sectionHeader"
            settingsPage.gameSettingsLayout:addElement(sectionTitle)
        end

        sectionTitle:setText(text)
        -- Apply a new focus ID in either case - either the element doesn't have one right now, or it has an already used one
        -- This is required for proper keyboard/controller navigation in the menu
        sectionTitle.focusId = FocusManager:serveAutoFocusId()
        table.insert(settingsPage.controlsList, sectionTitle)
        -- The title needs to be passed to the focus manager later on, otherwise skipping over the section title with up/down keys will fail
        RedTape.CONTROLS[controlKey] = sectionTitle
    end

    local function addMenuOption(id)
        if #RedTape.SETTINGS[id].values == 2 then
            RedTape.addBinaryMenuOption(id)
        else
            RedTape.addMultiMenuOption(id)
        end
    end

    addSectionTitle(g_i18n:getText("rt_help_title_red_tape"), "rtSectionHeader")

    for _, id in ipairs(RedTape.coreMenuItems) do
        addMenuOption(id)
    end

    -- The per policy toggles get their own header, as the policy name alone is the label
    addSectionTitle(g_i18n:getText("rt_header_policies"), "rtPolicySectionHeader")

    for _, id in ipairs(RedTape.policyMenuItems) do
        addMenuOption(id)
    end

    settingsPage.gameSettingsLayout:invalidateLayout()

    -- MULTIPLAYER PERMISSIONS
    local multiplayerPage = inGameMenu.pageMultiplayer

    function RedTape.addMultiplayerPermission(id)
        local newPermissionName = id .. 'PermissionCheckbox'
        local i18n_title = "permission_redTape_" .. id

        local original = multiplayerPage.cutTreesPermissionCheckbox.parent
        local newPermissionRow = original:clone(multiplayerPage.permissionsBox)

        local newPermissionCheckbox = newPermissionRow.elements[1]
        newPermissionCheckbox.id = newPermissionName

        local newPermissionLabel = newPermissionRow.elements[2]
        newPermissionLabel:setText(g_i18n:getText(i18n_title))

        table.insert(multiplayerPage.permissionRow, newPermissionRow)

        multiplayerPage.controlIDs[newPermissionName] = true
        multiplayerPage.permissionCheckboxes[id] = newPermissionCheckbox
        multiplayerPage.checkboxPermissions[newPermissionCheckbox] = id
    end

    for _, id in pairs(RedTape.multiplayerPermissions) do
        RedTape.addMultiplayerPermission(id)
    end

    -- ENABLE/DISABLE OPTIONS FOR CLIENTS
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
        local isAdmin = g_currentMission:getIsServer() or g_currentMission.isMasterUser

        for _, id in pairs(RedTape.menuItems) do
            local menuOption = RedTape.CONTROLS[id]
            menuOption:setState(RedTape.getStateIndex(id))

            if RedTape.SETTINGS[id].disabled then
                menuOption:setDisabled(true)
            elseif RedTape.SETTINGS[id].serverOnly and g_server == nil then
                menuOption:setDisabled(not isAdmin)
            else
                local permission = RedTape.SETTINGS[id].permission
                local hasPermission = g_currentMission:getHasPlayerPermission(permission)

                local canChange = isAdmin or hasPermission or false
                menuOption:setDisabled(not canChange)
            end
        end
    end)
end

-- Allow keyboard navigation of menu options
FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
    if gui == "ingameMenuSettings" then
        -- Let the focus manager know about our custom controls now (earlier than this point seems to fail)
        for _, control in pairs(RedTape.CONTROLS) do
            if not control.focusId or not FocusManager.currentFocusData.idToElementMapping[control.focusId] then
                if not FocusManager:loadElementFromCustomValues(control, nil, nil, false, false) then
                    print(
                        "Could not register control %s with the focus manager. Selecting the control might be bugged",
                        control.id or control.name or control.focusId)
                end
            end
        end
        -- Invalidate the layout so the up/down connections are analyzed again by the focus manager
        local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
        settingsPage.gameSettingsLayout:invalidateLayout()
    end
end)

