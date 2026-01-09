RTI18NExtension = {}
local modName = g_currentModName

RTI18NExtension.redTapeTexts = {
    ["rt_ui_schemePayout"] = true,
    ["finance_schemePayout"] = true,
    ["rt_ui_taxCost"] = true,
    ["finance_taxCost"] = true,
    ["rt_ui_policyFine"] = true,
    ["finance_policyFine"] = true,
    ["rt_ui_grantReceived"] = true,
    ["finance_grantReceived"] = true,
    ["rt_ui_grantApplicationCost"] = true,
    ["finance_grantApplicationCost"] = true
}

function RTI18NExtension:getText(superFunc, text, modEnv)
    if modEnv == nil and RedTape.tableHasKey(RTI18NExtension.redTapeTexts, text) then
        return superFunc(self, text, modName)
    end

    return superFunc(self, text, modEnv)
end

I18N.getText = Utils.overwrittenFunction(I18N.getText, RTI18NExtension.getText)