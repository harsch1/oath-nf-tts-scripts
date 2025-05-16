-- GUIDs for needed items. IF SOMETHING IS BROKEN LIKELY THESE ARE NO LONGER CORRECT
GUIDs = {
    atlasBox = "f8bd3c",
    banditBag = "0748d5",
    newAtlasBox = "8f8e1a",
    -- edifices = "1662f7",
    relicBag = "c46336",
    -- shadowBag = "1ce44a",
    siteBag = "12dafe",
    table = "4ee1f2",
    map = "d5dacf",
    dispossessedBag = "e52b07",
    archiveDecks = {
        Arcane = "a79848",
        Beast = "d1f201",
        Discord = "d40870",
        Hearth = "31eab2",
        Nomad = "6deb3d",
        Order = "275175"
    },
    edificeDeck = "1218b6",
    edificeDecks = {
        Arcane = "1218b6",
        Beast = "9ff2ff",
        Discord = "9f8caf",
        Hearth = "f96c21",
        Nomad = "0a6c96",
        Order = "33d062"
    },
    exploringFoundation = 'a19f9a',
    scriptingTrigger = '84ebee',

}

-- Tags to identify items
tags = {
    chronicleCreated = "chronicleCreated",
    edifice = "Edifice",
    relic = "Relic",
    site = "Site",
    unlocked = "Unlocked",
    protected = "Protected",
    debug = "Debug",
    ancient = "Ancient",
    card = "Card",
    slow = "Slow",
    bandit = "Bandit",
}

-- Name strings to use for Atlas Slots depending on their states
atlasSlotNames = {
    empty = "[Empty] Slot",
    full = "[Full] Slot"
}

-- Tables to track things on the portal
portal = {
    edifices = {},
    relics = {},
    sites = {},
}

-- Positions
pos = {
    -- relative to site
    bandit  =       function(i) return {x = -1.5+1.5*i, y = 3, z = 2} end,
    denizen =       function(i) return {x = 5.35+3.3*i, y = 0.25, z = 0} end,
    relic   =       function(i) return {x = 5.35+3.3*i, y = 0.25, z = 0} end,
    -- relative to atlas portal/box
    portal =        function(i) return {x = 0, y = 0.10, z = 0} end,
    preview =       function(i) return {x = 0, y = 1.525, z = -0.56} end,
    -- relative to map
    dispossessed =  function(i) return {x = -117.15, y = 0.55, z = 29.15} end,
    relicStack =    function(i) return {x = -19.7, y = 0.55,  z = -9.9} end,
    site =          function(i)
                        local sitePositions = {
                            { x = -26.55, y = 0.03, z =  5.00 },
                            { x = -26.55, y = 0.03, z = -0.75 },
                            { x = -06.10, y = 0.03, z =  5.00 },
                            { x = -06.10, y = 0.03, z = -0.75 },
                            { x = -06.10, y = 0.03, z = -6.50 },
                            { x =  14.85, y = 0.03, z =  5.00 },
                            { x =  14.85, y = 0.03, z = -0.75 },
                            { x =  14.85, y = 0.03, z = -6.50 }
                        }
                        return sitePositions[i]
                    end,
    worldDeck =     function(i) return {x = -14.53, y = 0.55, z = -9.9} end,
}

-- Rotations
rot = {
    dispossessed =  {x = 0,   y = 180,  z = 180},
    denizen =       {x = 0, y = 180,   z = 0},
    portal =        {x = 0,   y = 180, z = 0},
    preview =       {x = 90,   y = 180, z = 0},
    relic =         {x = 180, y = 0,   z = 0},
    relicStack =    {x = 180, y = 0,   z = 0},
    site =          {x = 0,   y = 180, z = 0},
    worldDeck =     {x = 0,   y = 90,  z = 180},
}

suits = {"Arcane","Beast","Discord","Hearth","Nomad","Order"}

suitColors = {
    Arcane = '#6f3788',
    Beast = "#a23723",
    Discord = "#33190c",
    Hearth = "#e54622",
    Nomad = "#49a281",
    Order = "#263f86",
  }