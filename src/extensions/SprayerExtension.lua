SprayerExtension = {}

function SprayerExtension:onTurnedOn()
    print("Sprayer turned on: " .. self:getName())
    g_currentMission.RedTape.InfoGatherer.turnedOnSprayers[self.uniqueId] = self
end
function SprayerExtension:onTurnedOff()
    print("Sprayer turned off: " .. self:getName())
    g_currentMission.RedTape.InfoGatherer.turnedOnSprayers[self.uniqueId] = nil
end

Sprayer.onTurnedOn = Utils.appendedFunction(Sprayer.onTurnedOn, SprayerExtension.onTurnedOn)
Sprayer.onTurnedOff = Utils.appendedFunction(Sprayer.onTurnedOff, SprayerExtension.onTurnedOff)
