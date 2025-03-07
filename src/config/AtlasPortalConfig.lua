-- GUIDs for needed items. IF SOMETHING IS BROKEN LIKELY THESE ARE NO LONGER CORRECT
GUIDs = {
    atlasBox = "f8bd3c",
    edifices = "1662f7",
    relicBag = "c46336",
    shadowBag = "1ce44a",
    siteBag = "12dafe",
    table = "4ee1f2",
    map = "d5dacf",
}

-- Buttons
buttons = {
    retry = {
        click_function = "retry",
        function_owner = self,
        label          = "Fix missing objects \n and click me \n to retry",
        position       = {0, 0, 2.6},
        scale          = {1.0,   1.0, 2.0 },
        rotation       = {0, 0, 0},
        width          = 1000,
        height         = 500,
        font_size      = 110,
        color          = hexToColor("#823030"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Place missing objects and retry", 
    },
    retrieve = {
        click_function = "retrieveInit",
        function_owner = self,
        label          = "→ Explore a Site\nfrom the front.",
        position       = {-1.85, 0, 0.85},
        scale          = {1.0,   1.0,   2.0 },
        rotation       = {0, 0, 0},
        width          = 725,
        height         = 400,
        font_size      = 77,
        color          = hexToColor("#588087"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Retrieve a Site and all objects there from the front of the Atlas Box", 
    },
    retrieveBack = {
        click_function = "retrieveBackInit",
        function_owner = self,
        label          = "→ Revisit a site from the back.",
        position       = {-1.85, 0, 2.},
        scale          = {1.0,   1.0,   2.0 },
        rotation       = {0, 0, 0},
        width          = 725,
        height         = 100,
        font_size      = 50,
        color          = hexToColor("#588087"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Retrieve a Site and all objects there from the back of the Atlas Box", 
    },
    setup = {
        click_function = "chronicleSetup",
        function_owner = self,
        label          = "Setup Initial\nAtlas Box\nand Sites",
        position       = {0, 0, 2.6},
        scale          = {1.0,   1.0, 2.0 },
        rotation       = {0, 0, 0},
        width          = 1000,
        height         = 500,
        font_size      = 130,
        color          = hexToColor("#4a915d"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Set Up the Atlas Box for a new Chronicle", 
    },
    spawnRelics = {
        click_function = "spawnRelics",
        function_owner = self,
        label          = "Retrieve Lost Relics",
        position       = {0, 0, 2.1},
        scale          = {1.0,   1.0, 2.0 },
        rotation       = {0, 0, 0},
        width          = 1050,
        height         = 250,
        font_size      = 80,
        font_color     = hexToColor("#e6bb4a"),
        color          = hexToColor("#8a363b"),
        tooltip        = "Retrieve 10 relics from the Atlas Box if you run out", 
    },
    storeStaged = {
        click_function = "storeInit",
        function_owner = self,
        position       = {-1.85, 0, -0.85},
        scale          = {1.0,   1.0,   2.0 },
        rotation       = {0, 0, 0},
        width          = 725,
        height         = 400,
        font_size      = 77,
        font_color     = {1, 1, 1, 1},
        label          = "←    Confirm?    ←",
        color          = hexToColor("#4a915d"),
        hover_color    = hexToColor("#58b872"),
        tooltip        = "Confirm?", 
    },
    storeUnstaged = {
        click_function = "storeInit",
        function_owner = self,
        position       = {-1.85, 0, -0.85},
        scale          = {1.0,   1.0,   2.0 },
        rotation       = {0, 0, 0},
        width          = 725,
        height         = 400,
        font_size      = 77,
        font_color     = {1, 1, 1, 1},
        label          = "← Into Atlas Box ←",
        color          = hexToColor("#588087"),
        hover_color    = nil,
        tooltip        = "Move Sites, Relics, Edifices and Shadow into the Atlas box", 
    }
}

-- Tags to identify items
tags = {
    chronicleCreated = "chronicleCreated",
    edifice = "Edifice",
    relic = "Relic",
    shadow = "Shadow",
    site = "Site",
    unlocked = "Unlocked",
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
    shadow = {},
    sites = {},
}

-- Positions
pos = {
    -- relative to site
    denizen =       function(i) return {x = 5.35+3.3*i, y = 0.25, z = 0} end,
    relic =         function(i) return {x = -0.15, y = 0.25*i, z = -1.3+1.3*i} end,
    shadow =        function(i) return {x = -2.275, y = 1, z = 0.570} end,
    -- relative to atlas portal
    portal =        function(i) return {x = 0, y = 5, z = 0} end,
    -- relative to map
    relicStack =    function(i) return {x = -19.7, y = 0.55,  z = -9.9} end,
    site =          function(i)
                        local sitePositions = {
                            { x = -26.55, y = 0.21, z =  5.00 },
                            { x = -26.55, y = 0.21, z = -0.75 },
                            { x = -06.10, y = 0.21, z =  5.00 },
                            { x = -06.10, y = 0.21, z = -0.75 },
                            { x = -06.10, y = 0.21, z = -6.50 },
                            { x =  14.85, y = 0.21, z =  5.00 },
                            { x =  14.85, y = 0.21, z = -0.75 },
                            { x =  14.85, y = 0.21, z = -6.50 }
                        }
                        return sitePositions[i]
                    end,
}

-- Rotations
rot = {
    denizen =       {x = 180, y = 0,   z = 0},
    portal =        {x = 0,   y = 180, z = 0},
    relic =         {x = 180, y = 0,   z = 0},
    relicStack =    {x = 180, y = 0,   z = 0},
    shadow =        {x = 0,   y = 180, z = 0},
    site =          {x = 0, y = 180,   z = 0},
}