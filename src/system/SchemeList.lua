-- Maybe an incentive to use a natural fertiliser. Like sea weed fert, its a real  thing.
-- You could add a big bad that just says sea weed feet but works the same. But include it as a environmental policy.
-- Another one would be to add a grass type, but would be a lot of work. But it could work like herbal lay does.

SchemeIds = {
    DELAYED_MOWING_WILDLIFE = 1, -- SFI, or just only cut twice for a payout
    BALES_OVER_FORAGING = 2,     -- He also got paid for hay making. Basically, he chose to make hay and not silage in some fields. Reasons are less plastic use from wrapping, and the seeds from the wildflowers and grass get spread when baling and loading, and moving the bales.
    NATURAL_GRAZING = 3,         -- Promotes natural grazing practices and biodiversity
    NATURAL_FERTILISER = 4,      -- Encourages the use of natural fertilizers to improve soil health
    CROP_PROMOTION = 5,          -- promotes growing specific crops. possibly split this by tier, and give equipment or cash bonuses
}


Schemes = {

    [SchemeIds.DELAYED_MOWING_WILDLIFE] = {
        id = SchemeIds.DELAYED_MOWING_WILDLIFE,
        name = "rt_scheme_delayed_mowing",
        description = "rt_scheme_desc_delayed_mowing",
        duplicationKey = "DELAYED_HARVEST",
        tiers = {
            [PolicySystem.TIER.A] = {
                bonusPerHa = 12500,
            },
            [PolicySystem.TIER.B] = {
                bonusPerHa = 12300,
            },
            [PolicySystem.TIER.C] = {
                bonusPerHa = 12200,
            },
            [PolicySystem.TIER.D] = {
                bonusPerHa = 12000,
            },
        },
        probability = 1,
        initialise = function(schemeInfo, scheme)
            -- Init of an available scheme, prior to selection by a farm
        end,
        selected = function(schemeInfo, scheme)
            -- Any action when applying the scheme to a farm, e.g. initial payout or equipment
        end,
        evaluate = function(schemeInfo, scheme, tier)
            local rt = g_currentMission.RedTape
            local currentMonth = rt.periodToMonth(g_currentMission.environment.currentPeriod)
            if currentMonth ~= 7 then return end -- Only evaluate in July

            local ig = g_currentMission.RedTape.InfoGatherer
            local gatherer = ig.gatherers[INFO_KEYS.FARMLANDS]
            local farmId = scheme.farmId
            local invalidMonths = { 4, 5, 6 }

            local report = {}
            for _, farmland in pairs(g_farmlandManager.farmlands) do
                if farmland.farmId == farmId then
                    local farmlandData = gatherer:getFarmlandData(farmland.id)
                    local lastHarvestMonth = rt.periodToMonth(farmlandData.lastHarvestPeriod)
                    if farmlandData.lastHarvestPeriod == -1 then
                        lastHarvestMonth = -1
                    end

                    local didHarvest = rt:tableHasValue(invalidMonths, lastHarvestMonth)
                    if farmlandData.retainedSpringGrass and not didHarvest then
                        local bonusPerHa = schemeInfo.tiers[tier].bonusPerHa
                        print("Payout multiplier: " .. tostring(EconomyManager.getPriceMultiplier()))
                        local payout = farmlandData.areaHa * bonusPerHa * EconomyManager.getPriceMultiplier()
                        table.insert(report, {
                            cell1 = string.format(g_i18n:getText("rt_report_name_farmland"), farmland.id),
                            cell2 = g_i18n:formatMoney(payout, 0, true, true)
                        })
                        g_client:getServerConnection():sendEvent(SchemePayoutEvent.new(scheme, farmId, payout))
                    else
                        table.insert(report, {
                            cell1 = string.format(g_i18n:getText("rt_report_name_farmland"), farmland.id),
                            cell2 = g_i18n:formatMoney(0, 0, true, true),
                        })
                    end
                end
            end

            return report
        end
    }

}
