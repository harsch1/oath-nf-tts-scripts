-- GUIDs for needed items. IF SOMETHING IS BROKEN LIKELY THESE ARE NO LONGER CORRECT
GUIDs = {
    atlasBox = "8f8e1a",
    banditBag = "dfe71a",
    favorBag = "a0b9c8",
    relicPile = "7dc3e5",
    table = "daf876",
    map = "d5dacf",
    secretBag = "96a4f2",
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
        Arcane = "6a23a9",
        Beast = "b81778",
        Discord = "c89e0e",
        Hearth = "cd0dec",
        Nomad = "335d60",
        Order = "e651fe"
    },
    scriptingTrigger = '84ebee',
    starsCard = "43c99e",
    archiveBoard = "a70bd6",
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
    favor = "Favor",
    secret = "Secret",
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
    bandit  =       function(i) return {x = -1.8+2*i, y = 3, z = 2.79} end,
    favor  =        function(i) return {x = -3.75, y = 3, z = 2.79-1.25*i} end,
    secret  =       function(i) return {x = -3.75, y = 3, z = 2.79-1.25*i} end,
    denizen =       function(i) return {x = 6.69+4.19*i, y = 0, z = 0} end,
    relic   =       function(i) return {x = 6.69+4.19*i, y = 0, z = 0} end,
    -- relative to atlas portal/box
    preview =       function(i) return {x = 0, y = 2, z = -0.75} end,
    -- relative to map
    dispossessed =  function(i) return {x = -92.64, y= 1.24, z = 75.39} end,
    relicStack =    function(i) return {x = -24.85, y = 1.47,  z = -12.40} end,
    site =          function(i)
                        local sitePositions = {
                            { x = -33.42, y = 0.20, z =  6.25 },
                            { x = -33.42, y = 0.20, z = -0.94 },
                            { x = -07.67, y = 0.20, z =  6.25 },
                            { x = -07.67, y = 0.20, z = -0.94 },
                            { x = -07.67, y = 0.20, z = -8.16 },
                            { x =  18.69, y = 0.20, z =  6.25 },
                            { x =  18.69, y = 0.20, z = -0.94 },
                            { x =  18.69, y = 0.20, z = -8.16 }
                        }
                        return sitePositions[i]
                    end,
    worldDeck =     function(i) return {x = -18.23, y = 1.53, z = -12.50} end,
    -- relative to archive board, indexed by suit
    archiveDeck =   function(suit)
                        local x = archiveBoardSuitOffsetsX[suit]
                        if x == nil then return nil end
                        return {x = x, y = 0.30, z = 5.09}
                    end,
    edificeDeck =   function(suit)
                        local x = archiveBoardSuitOffsetsX[suit]
                        if x == nil then return nil end
                        return {x = x, y = 0.30, z = -5.84}
                    end,
}
archiveBoardSuitOffsetsX = {
    Discord = -15.30,
    Arcane  = -9.23,
    Order   = -3.09,
    Hearth  =  3.09,
    Beast   =  9.22,
    Nomad   =  15.33,
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

-- Site preview shown above the Atlas Box
-- Site bags: a rounded slab with the site art and card back as decals on its top and bottom
siteBagConfig = {
    meshURL = "https://steamusercontent-a.akamaihd.net/ugc/13389043065856405551/5AEBA4343C811EFF0C2B79F9822A0A7D67B06299/",
    size = {x = 8.7125, y = 0.0375, z = 6.7375},
    backURL = "https://raw.githubusercontent.com/harsch1/oath-nf-tts-scripts/refs/heads/2.0/assets/img/Sites/Rounded/landBack.webp",
}

sitePreviewConfig = {
    siteScale    = 1.0,   -- the site preview is a site bag model at this fraction of full size
    denizenScale = {x = 2.06, y = 1.0, z = 2.06},  -- denizens and edifices
    relicScale   = {x = 1.2,  y = 1.0, z = 1.2},
    -- Offsets from the site preview for the i-th (0-based) denizen/edifice and relic.
    -- Depths (z) never overlap: site 0, denizens -0.10 (first, frontmost) back towards the site, relics -0.13 and forward
    denizenOffset = function(i) return {x = 2.15 - 1*i, y = -0.75 - 0.1*i, z = -0.10 + 0.03*i} end,
    relicOffset   = function(i) return {x = 2.35 - 1.5*i, y = -2.25, z = -0.13 - 0.03*i} end,
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