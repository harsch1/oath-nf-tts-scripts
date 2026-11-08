-- GUIDs for needed items. IF SOMETHING IS BROKEN LIKELY THESE ARE NO LONGER CORRECT
GUIDs = {
    atlasBox = "8f8e1a",
    bookshelf = "5c209e",
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
    playerArchives = {
        Purple = "84b674", -- Chancellor Archive
        Red = "ad385c",
        Blue = "aede62",
        Yellow = "6426e6",
        Black = "049cfb",
        White = "1b023c",
        Brown = "469f24",
        Pink = "0c2bda"
    },
    storageBags = { -- each color's "Storage and Warband Return" bag
        Red = "185eca",
        Blue = "965bab",
        Yellow = "aa6349",
        Black = "e59d49",
        White = "3ffd1b",
        Brown = "acd7f1",
        Pink = "47c52a"
    },
    -- Seats indexed clockwise around the table, starting at the near-left seat (-59, -50).
    -- handZones[i] and playerMats[i] belong to the same seat.
    handZones = {
        "240688", -- 1: (-59, -50)
        "be49b8", -- 2: (-20, -50)
        "a95808", -- 3: ( 20, -50)
        "37d4a4", -- 4: ( 59, -50)
        "bdac77", -- 5: ( 59,  50)
        "a854b1", -- 6: ( 20,  50)
        "7ea8d3", -- 7: (-20,  50)
        "01d807"  -- 8: (-59,  50)
    },
    playerMats = { -- mat laid out in front of each hand zone
        "2bce21",
        "716319",
        "ce9fc7",
        "d6f2ff",
        "1f3a85",
        "b2fd07",
        "8265dc",
        "2b35bf"
    },
    -- the scripting zone over each of the game board's favor banks, by suit
    favorBankZones = {
        Discord = "8ba3a8",
        Arcane = "eb4918",
        Order = "c73b2a",
        Hearth = "262733",
        Beast = "430785",
        Nomad = "a9e2fc"
    },
    -- the Chancellor's regalia, kept in the Chancellor Archive while nobody is Chancellor
    grandScepter = "f1a8eb",
    imperialReliquary = "abca02",
    -- the banners: each one, the scripting zone over it, and the pieces placed on it (by tag)
    banners = {
        PeoplesFavor = {banner = "8c3365", zone = "4ba6b7", piece = "Favor"},
        DarkestSecret = {banner = "4106bc", zone = "34fee1", piece = "Secret"},
    },
    -- the favor and secret supplies (infinite bags), single and triple
    supplies = {
        Favor = "a0b9c8",
        TripleFavor = "2e70f9",
        Secret = "96a4f2",
        TripleSecret = "4f399b",
    },
    -- moved below the Darkest Secret when its Festival side resolves
    festivalToken = "32f198"

}

-- Each archive's place on the bookshelf, in the shelf's own units, and how it's turned relative to the shelf. The
-- Bookshelf puts them back here whenever it's put down.
shelfArchiveLayout = {
    Purple = {x = 12.355, y = 8.781, z = -0.132},
    Red    = {x = 8.244,  y = 8.840, z = 0.472},
    Blue   = {x = 4.244,  y = 8.840, z = 0.472},
    Yellow = {x = 0.244,  y = 8.840, z = 0.471},
    White  = {x = -3.756, y = 8.840, z = 0.471},
    Black  = {x = -7.756, y = 8.840, z = 0.471},
    Brown  = {x = -11.756, y = 8.840, z = 0.471},
    Pink   = {x = -15.756, y = 8.840, z = 0.469},
}
shelfArchiveRotation = {x = 270, y = -90, z = 0}

-- Player pieces laid out on a player mat, by tag: each uses pos[key](i) and rot[key] (relative to player mat)
-- A player pawn's state for each role (the Chancellor's own pawn stays stored; the Chancellor pawn stands in for it)
pawnStates = {EXILE = 1, CITIZEN = 2}

playerMatLayout = {
    playerBoard        = "playerBoard",
    warbandReturn      = "warbandReturn",
    Favor              = "playerBank",
    Secret             = "playerSecret",
    warbandTray        = "warbandTray",
    supplyReminder     = "supplyReminder",
    OathSupplyMarker   = "supplyMarker",
    Pawn               = "playerPawn",
    -- every warband goes to the bank on the warband tile; i is the warband's number (up to 14 per color)
    Warband            = "warbandBank",
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
    warband = "Warband",
    warbandBank = "WarbandBank",     -- a warband sitting in a warband tile's bank
    warbandTray = "WarbandTray",     -- a warband tile, which runs the bank
    pawn = "Pawn",                   -- a player's pawn (memo: its color), or the Chancellor's (memo: Purple)
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
                        -- 3 regions of 3 slots, top to bottom; the first region has no bottom slot
                        local slot = i < 3 and i - 1 or i
                        local regionX = {-33.42, -07.67, 18.69}
                        local rowZ = {6.25, -0.94, -8.16}
                        return {x = regionX[math.floor(slot/3) + 1], y = 0.20, z = rowZ[slot%3 + 1]}
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
    -- relative to player mat (all mats face the same way); player board and storage set from seat 2's mat
    playerBoard =        function(i) return {x = -3.44, y = 0.06, z = 7.12} end,
    warbandReturn =      function(i) return {x = -15.036, y = 1.942, z = 7.214} end,
    playerBank =         function(i) return {x = -12.46, y = 0.075, z = -0.17} end,
    playerSecret =       function(i) return {x = -12.46, y = 0.294, z = -2.44} end,
    warbandTray =        function(i) return {x = -7.037, y = 0.231, z = -0.578} end,
    -- the shared Chancellor tray, brought onto the Chancellor's mat by their warband tray
    chancellorTray =     function(i) return {x = -6.127, y = 0.231, z = -0.858} end,
    supplyReminder =     function(i) return {x = -10.801, y = 0.14, z = 4.174} end,
    supplyMarker =       function(i) return {x = -10.807, y = 0.414, z = 4.166} end,
    -- the player's pawn, above their favor and secret (also where the Chancellor's pawn comes out if theirs isn't out)
    playerPawn =         function(i) return {x = -12.46, y = 0.5, z = 1.13} end,
    -- the Chancellor's regalia, side by side on grid points at the left end of the mat's lower left grid (where they go
    -- when someone becomes Chancellor; a withdrawn Chancellor's come back where they were)
    imperialReliquary =  function(i) return {x = -13.86, y = 0.3, z = -8.25} end,
    grandScepter =       function(i) return {x = -8.20, y = 0.3, z = -8.25} end,
    -- the banners, side by side just right of the regalia on the mat of the player who takes them with a
    -- challenge/campaign: whichever comes first takes spot 1 (the left), the other spot 2
    banner =             function(i) return i == 2 and {x = 3.4, y = 0.5, z = -8.25} or {x = -3.0, y = 0.5, z = -8.25} end,
    -- slot i of the warband tile's Exile bank, so warbands land on it before the tile repacks them.
    -- The tile is turned 180 (rot.warbandTray), so its x and z point the opposite way to the mat's.
    warbandBank =        function(i)
                            local tray, slot = pos.warbandTray(1), pos.warbandTraySlot(i)
                            return {x = tray.x - slot.x, y = tray.y + slot.y, z = tray.z - slot.z}
                        end,
    -- relative to the warband tile, in tile units (world units along the tile's own axes, from its centre)
    -- Slot i of an Exile bank (columns of 6, 5, 3) or a Chancellor bank (7, 7, 7, 3); the last column fills first
    warbandTraySlot =    function(i, imperial)
                            local columns = imperial and {7, 7, 7, 3} or {6, 5, 3}
                            for column = #columns, 1, -1 do
                                if i <= columns[column] then
                                    return {x = 2.005 - 1.938*(column - 1), y = 0.094, z = -2.035 + 0.775*(i - 1)}
                                end
                                i = i - columns[column]
                            end
                            return nil
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
    -- player mat contents
    playerBoard =        {x = 0,   y = 180, z = 180},
    warbandReturn =      {x = 0,   y = 0,   z = 180},
    playerBank =         {x = 0,   y = 180, z = 0},
    playerSecret =       {x = 0,   y = 180, z = 0},
    warbandTray =        {x = 0,   y = 180, z = 0},
    chancellorTray =     {x = 0,   y = 180, z = 0},
    supplyReminder =     {x = 0,   y = 180, z = 0},
    supplyMarker =       {x = 0,   y = 90,  z = 0},
    playerPawn =         {x = 0,   y = 180, z = 0},
    imperialReliquary =  {x = 0,   y = 180, z = 0},
    grandScepter =       {x = 0,   y = 180, z = 0},
    banner =             {x = 0,   y = 180, z = 0},
    warbandBank =        {x = 0,   y = 0,   z = 0},
}

-- The lay-flat foldbox models (storage boxes and archives), with the extents of each visible model in the object's
-- own axes (the OBJ with x negated). The spine is the +x face; on the table (rot.warbandReturn) the face-up cover
-- is -y, and on the shelf +z points up.
foldboxModels = {
    player = {
        mesh = "https://steamusercontent-a.akamaihd.net/ugc/12740149312919266159/DC0FA0096D716094E727DA43C2E4023C0FEA87B5/",
        collider = "https://steamusercontent-a.akamaihd.net/ugc/13105671905754982910/7410B3DD198B3280A9C86E52EC724E113AB205EB/",
        min = {x = -1.797, y = 0, z = -2.349},
        max = {x = 1.797, y = 1.275, z = 2.341},
    },
    chancellor = {
        mesh = "https://steamusercontent-a.akamaihd.net/ugc/9260875429030359555/68D378C5482A471F681526B97288B0185563AD97/",
        collider = "https://steamusercontent-a.akamaihd.net/ugc/12964030041565530163/B58B1B3E90C44D597D6C4BE0B66B40341001C7DD/",
        min = {x = -1.975, y = 0.006, z = -2.378},
        max = {x = 1.975, y = 1.238, z = 2.378},
    },
}

-- Role stamps (decals): a player's color on the Chancellor's storage box and the Chancellor Archive's spine, and
-- the citizen stamp on a Citizen's storage box and archive spine. Width and height are the
-- image's pixels, for its proportions. coverShift (world units) moves a stamp towards the cover's right edge.
stampImages = {
    Red     = {url = "https://steamusercontent-a.akamaihd.net/ugc/10637544717120814997/FDB9C35066DB4290D0094AE4BB831857F9B5DCB6/", width = 211, height = 255},
    Blue    = {url = "https://steamusercontent-a.akamaihd.net/ugc/9624418332701209983/83D63DEF42E6B58FE4B179FE3273174777E6026A/", width = 264, height = 258},
    Yellow  = {url = "https://steamusercontent-a.akamaihd.net/ugc/9976926303863733185/1924C6B6B983698144730E9D4452A35AD4A94E66/", width = 211, height = 255},
    Black   = {url = "https://steamusercontent-a.akamaihd.net/ugc/10478459436079005061/0906522CB6B67D81215CC482C7AC6C66B9DB7CD2/", width = 234, height = 252},
    White   = {url = "https://steamusercontent-a.akamaihd.net/ugc/16419599633626472993/E3ADEF2143F5FC9B06C218569C3C6ADB5E5965FA/", width = 224, height = 252},
    Brown   = {url = "https://steamusercontent-a.akamaihd.net/ugc/10389049971267908874/72178DC2389B4835390A761F8EE743DC7DDF9540/", width = 235, height = 266},
    Pink    = {url = "https://steamusercontent-a.akamaihd.net/ugc/17468223799216771713/0122BFC59948650A486D961BA0E335FA11DBC98E/", width = 235, height = 261},
    Citizen = {url = "https://steamusercontent-a.akamaihd.net/ugc/11834703087857053328/D22BC0CC7AA76BF520D344D4023DF737ADC4BE01/", width = 125, height = 245, coverShift = 0.5},
    -- the bookshelf's status column
    CitizenWhite = {url = "https://steamusercontent-a.akamaihd.net/ugc/9885851454270946941/AFDA5AEC36FC98CAD42B5FDB2A6D232CD0E2B474/", width = 125, height = 245},
    Chancellor = {url = "https://steamusercontent-a.akamaihd.net/ugc/17659710526627575728/FE447D932F3D08F58D53110E9B4FC2F5315E4A3D/", width = 480, height = 442},
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