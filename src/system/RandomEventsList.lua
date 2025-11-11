RTRandomEventsIds = {
    STOLEN_EQUIPMENT = 1,
}

RTRandomEvents = {
    [RTRandomEventsIds.STOLEN_EQUIPMENT] = {
        id = RTRandomEventsIds.STOLEN_EQUIPMENT,
        name = "Stolen Equipment",
        description = "Some of your equipment has been stolen by thieves. You need to recover it.",
        difficulty = "Medium",
        stages = {
            {
                stage = 1,
                run = function(randomEvent)
                    
                end
            },
            {
                stage = 2,
                run = function(randomEvent)
                end
            },
            {
                stage = 3,
                run = function(randomEvent)
                end
            },
        },
    },
}