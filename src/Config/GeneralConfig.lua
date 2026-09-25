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
        Arcane = "eb5f90",
        Beast = "e5dedf",
        Discord = "334c58",
        Hearth = "f1d3b2",
        Nomad = "850506",
        Order = "3bb246"
    },
    edificeDeck = "1218b6",
    edificeDecks = {
        Arcane = "7b1cba",
        Beast = "b81778",
        Discord = "c89e0e",
        Hearth = "cd0dec",
        Nomad = "335d60",
        Order = "e651fe"
    },
    scriptingTrigger = '84ebee',
    starsCard = "43c99e",
    foundations = {
        {name = "Foundation I: Imperial Maps", GUID = "6278ae"},
        {name = "Foundation II: Powerful Tribes", GUID = "1774bc"},
        {name = "Foundation III: Quiet Ambitions", GUID = "3e4736"},
        {name = "Foundation IV: Teeming World", GUID = "fbb3c4"},
        {name = "Foundation V: Mob's Favor", GUID = "2a9f5d"},
        {name = "Foundation VI: Wandering Flame", GUID = "8bc248"},
    },
    playerBoards = { -- Base/Citizen
        {color = "Red", idx=02, GUID = {"0b2c43", "0867dd"}},
        {color = "Blue", idx=03, GUID = {"eab256", "508780"}},
        {color = "Yellow", idx=06, GUID = {"e77125", "623e25"}},
        {color = "Black", idx=04, GUID = {"75dec1", "2cdc7e"}},
        {color = "White", idx=05, GUID = {"2c0051", "d69751"}},
        {color = "Brown", idx=07, GUID = {"88b6e5", "9f2e36"}},
        {color = "Pink", idx=01, GUID = {"54d2ac", "bad9a4"}}
    }

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
    worldDeck =     {x = 0,   y = 270,  z = 180},
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