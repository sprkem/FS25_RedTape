RTTaxStatement = {}
RTTaxStatement_mt = Class(RTTaxStatement)

function RTTaxStatement.new()
    local self = {}
    setmetatable(self, RTTaxStatement_mt)

    self.farmId = -1
    self.month = RedTape.getCumulativeMonth()
    self.totalTaxableIncome = 0
    self.totalTaxedIncome = 0
    self.totalExpenses = 0
    self.totalTax = 0
    self.taxRate = 0.2
    self.notes = {}
    self.paid = false
    self.lossRolloverUsed = 0      -- Amount of previous losses applied this year
    self.lossRolloverGenerated = 0 -- New losses generated this year

    return self
end

function RTTaxStatement:saveToXmlFile(xmlFile, key)
    setXMLInt(xmlFile, key .. "#farmId", self.farmId)
    setXMLInt(xmlFile, key .. "#month", self.month)
    setXMLInt(xmlFile, key .. "#totalTaxableIncome", self.totalTaxableIncome)
    setXMLInt(xmlFile, key .. "#totalTaxedIncome", self.totalTaxedIncome)
    setXMLInt(xmlFile, key .. "#totalExpenses", self.totalExpenses)
    setXMLInt(xmlFile, key .. "#totalTax", self.totalTax)
    setXMLBool(xmlFile, key .. "#paid", self.paid)
    setXMLFloat(xmlFile, key .. "#taxRate", self.taxRate)
    setXMLInt(xmlFile, key .. "#lossRolloverUsed", self.lossRolloverUsed)
    setXMLInt(xmlFile, key .. "#lossRolloverGenerated", self.lossRolloverGenerated)

    local notesKey = key .. ".notes"
    for i, note in ipairs(self.notes) do
        local noteKey = string.format("%s.note(%d)", notesKey, i - 1)
        setXMLString(xmlFile, noteKey, note)
    end
end

function RTTaxStatement:loadFromXMLFile(xmlFile, key)
    self.farmId = getXMLInt(xmlFile, key .. "#farmId")
    self.month = getXMLInt(xmlFile, key .. "#month")
    self.totalTaxableIncome = getXMLInt(xmlFile, key .. "#totalTaxableIncome")
    self.totalTaxedIncome = getXMLInt(xmlFile, key .. "#totalTaxedIncome")
    self.totalExpenses = getXMLInt(xmlFile, key .. "#totalExpenses")
    self.totalTax = getXMLInt(xmlFile, key .. "#totalTax")
    self.paid = getXMLBool(xmlFile, key .. "#paid")
    self.taxRate = getXMLFloat(xmlFile, key .. "#taxRate")
    self.lossRolloverUsed = getXMLInt(xmlFile, key .. "#lossRolloverUsed") or 0
    self.lossRolloverGenerated = getXMLInt(xmlFile, key .. "#lossRolloverGenerated") or 0

    self.notes = {}
    local notesKey = key .. ".notes"
    local i = 0
    while true do
        local noteKey = string.format("%s.note(%d)", notesKey, i)
        if not hasXMLProperty(xmlFile, noteKey) then
            break
        end

        local note = getXMLString(xmlFile, noteKey)
        table.insert(self.notes, note)

        i = i + 1
    end

    -- Handle backward compatibility for old save files
    self:handleLegacyLossRollover(xmlFile, key)
end

-- TODO: eventually remove this function
function RTTaxStatement:handleLegacyLossRollover(xmlFile, key)
    -- Check if this is an old-style file by looking for the absence of lossRolloverUsed
    if not hasXMLProperty(xmlFile, key .. "#lossRolloverUsed") then
        local baseTaxableAmount = self.totalTaxedIncome - self.totalExpenses

        if baseTaxableAmount < 0 then
            -- This statement had a loss, we need to add it to the rollover system
            local lossAmount = math.abs(baseTaxableAmount)

            local taxSystem = g_currentMission.RedTape.TaxSystem
            if taxSystem then
                local existingRollover = taxSystem.lossRollover[self.farmId] or 0

                local totalRollover = math.min(existingRollover + lossAmount, 5000000)
                taxSystem.lossRollover[self.farmId] = totalRollover

                self.lossRolloverGenerated = lossAmount
                self.lossRolloverUsed = 0

                table.insert(self.notes, string.format(
                    g_i18n:getText("rt_notes_loss_generated"),
                    g_i18n:formatMoney(lossAmount, 0, true, true),
                    g_i18n:formatMoney(totalRollover, 0, true, true)
                ))
            end
        else
            self.lossRolloverGenerated = 0
            self.lossRolloverUsed = 0
        end
    end
end

function RTTaxStatement:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.totalTaxableIncome)
    streamWriteInt32(streamId, self.totalTaxedIncome)
    streamWriteInt32(streamId, self.totalExpenses)
    streamWriteInt32(streamId, self.totalTax)
    streamWriteBool(streamId, self.paid)
    streamWriteFloat32(streamId, self.taxRate)
    streamWriteInt32(streamId, self.lossRolloverUsed)
    streamWriteInt32(streamId, self.lossRolloverGenerated)

    streamWriteInt32(streamId, RedTape.tableCount(self.notes))
    for _, note in pairs(self.notes) do
        streamWriteString(streamId, note)
    end
end

function RTTaxStatement:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.totalTaxableIncome = streamReadInt32(streamId)
    self.totalTaxedIncome = streamReadInt32(streamId)
    self.totalExpenses = streamReadInt32(streamId)
    self.totalTax = streamReadInt32(streamId)
    self.paid = streamReadBool(streamId)
    self.taxRate = streamReadFloat32(streamId)
    self.lossRolloverUsed = streamReadInt32(streamId)
    self.lossRolloverGenerated = streamReadInt32(streamId)

    local notesCount = streamReadInt32(streamId)
    self.notes = {}
    for i = 1, notesCount do
        local note = streamReadString(streamId)
        table.insert(self.notes, note)
    end
end
