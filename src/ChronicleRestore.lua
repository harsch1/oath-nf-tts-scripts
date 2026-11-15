-- ==============================
-- CHRONICLE RESTORE
--
-- Sets the table up from a Chronicle export string (encoding
-- version 2 to 4, see chronicle-codec.js). Runs in Global, from
-- the "Restore Chronicle" window (src/Global.xml).
--
-- It moves the real pieces, the way the mod deals them: cards
-- are taken out of the decks and bags they're in (takeObject) and
-- put together into decks (putObject), sites go in and out of the
-- Atlas Box through its script API (TakeSite, StoreSite), and
-- players' pieces go into their archive through its StoreObject.
-- Nothing is spawned or destroyed.
--
-- It's for a fresh copy of the mod: every card starts in its home deck (the archive, edifice and lineage decks, the
-- relic pile), every site in the Atlas Box, and nobody is out on the table. In order:
--   1. Every card, edifice, relic, legacy and site is found, wherever it is.
--   2. The sites come out of the Atlas Box onto locked staging spots above the table.
--   3. Each piece goes where the Chronicle puts it:
--        Empire        each site on the next map slot, with its cards and relics on the spots beside it
--        World Deck, Dispossessed   decks built on their spots on the map, in the string's order
--        Atlas Box     the site bags back in, in order, each holding its cards and relics
--        Reliquary     inside the Imperial Reliquary (taken out of the Chancellor Archive and put back)
--        Players       into their archive, laid out for their mat (MAT_SLOTS)
--        Relic Deck    built last on its spot, with any relic the string doesn't place at the bottom
--      Sites the string doesn't place go back in the Atlas Box. Every other piece not used stays in its home deck.
--   4. The Foundations are turned to match, the Oath's Oathkeeper tile is swapped into play, and roles and scores
--      are set on the Bookshelf.
--   5. The players come out: the Chancellor at the Purple seat, then the Citizens and the Exiles at their own seats,
--      up to SEAT_COUNT players. Anyone empty (no score, cards, legacies or relics), or past that, stays stored.
--
-- Whatever the string doesn't record (see DecodeChronicleString) is left as it is.
-- ==============================

require("src/Chronicle")

local F = ChronicleFormat

-- ==============================
-- FORMAT (must match chronicle-codec.js)
-- ==============================

-- (the alphabet, the scrambling, the checksum and which versions can be read are HelperFunctions': scramble, oDecode)
-- From version 4, extra player sections can follow the named ones, numbered from here (the codec leaves their colors
-- to the client; this mod has none for them for now)
local FIRST_EXTRA_PLAYER = 8
local FIRST_EXTRA_PLAYERS_VERSION = 4
local FOUNDATIONS_WIDTH = 2
local LINEAGE_WIDTH = 2

-- The sections in order; the players' follow, one per F.PLAYER_COLORS
local SECTIONS = {"atlasBox", "world", "worldDeck", "relicDeck", "dispossessed", "reliquary", "foundations"}

local STATUS_ROLES = {[0] = "EXILE", [1] = "CITIZEN", [2] = "CHANCELLOR"}
local ROLE_NAMES = {EXILE = "Exile", CITIZEN = "Citizen", CHANCELLOR = "Chancellor"}

-- ==============================
-- WHERE THINGS GO
-- ==============================

-- How many players come out (the table's seats); the Chancellor sits at CHANCELLOR_SEAT, everyone else at their own
local SEAT_COUNT = 8
local CHANCELLOR_SEAT = "Purple"

-- How many sites the map holds
local MAP_SLOTS = 8

-- A relic beside a site lies face down (a card or edifice uses rot.denizen, face up)
local RELIC_ON_SITE = {x = 0, y = 180, z = 180}

-- How far above its spot a piece is spawned, so it settles onto whatever is there
local DROP_HEIGHT = 0.3

-- Where each of a player's pieces lands on their mat, as offsets from the mat (like pos.playerBoard): the first three
-- cards on the mat's adviser spots right of the board and three more below them, legacies in a row across the card
-- grid under those, and relics in a row along the bottom, right of the regalia and banner spots. A player with more
-- than a row holds starts the row again, a little to the right and higher up.
local MAT_SLOTS = {
    cards = {
        {x = 7.62, z = 7.13}, {x = 11.74, z = 7.13}, {x = 15.86, z = 7.13},
        {x = 7.62, z = 1.0}, {x = 11.74, z = 1.0}, {x = 15.86, z = 1.0},
    },
    legacies = {
        {x = 6.45, z = -4.0}, {x = 9.3, z = -4.0}, {x = 12.15, z = -4.0}, {x = 15.0, z = -4.0},
        {x = 3.6, z = -4.0}, {x = 0.75, z = -4.0},
    },
    relics = {
        {x = 7.0, z = -8.5}, {x = 9.6, z = -8.5}, {x = 12.2, z = -8.5}, {x = 14.8, z = -8.5},
        {x = 4.4, z = -8.5}, {x = 1.8, z = -8.5}, {x = -0.8, z = -8.5},
    },
}
local MAT_PIECE_HEIGHT = 0.3   -- above the board
local MAT_WRAP_SHIFT = 1.4     -- how far right each repeat of a row starts
local MAT_WRAP_LIFT = 0.1      -- and how much higher

-- ==============================
-- NAMES
-- ==============================

local reverse = nil

-- Names by id: items (cards, edifices and relics: {kind, name, suit}), relics by relic id, legacies and sites
local function getReverse()
    if reverse then
        return reverse
    end
    reverse = {items = {}, relics = {}, legacies = {}, sites = {}}
    for suit, group in pairs(cardIndex) do
        for _, card in pairs(group.cards) do
            reverse.items[card.id] = {kind = "card", name = card.name, suit = suit}
        end
    end
    for suit, group in pairs(edificeIndex) do
        for _, card in pairs(group.cards) do
            reverse.items[card.id] = {kind = "edifice", name = card.name, suit = suit}
        end
    end
    for _, relic in pairs(relicIndex.cards) do
        local item = {kind = "relic", name = relic.name, id = relic.id}
        reverse.items[relic.id] = item
        reverse.relics[relic.relicId] = item
    end
    for _, legacy in pairs(legacyIndex.cards) do
        reverse.legacies[legacy.id] = legacy.name
    end
    -- a site with more than one name is shown by the first alphabetically
    for name, index in pairs(siteIndex) do
        if reverse.sites[index] == nil or name < reverse.sites[index] then
            reverse.sites[index] = name
        end
    end
    return reverse
end

local function itemName(id)
    local item = getReverse().items[id]
    return item and item.name or ("card " .. id)
end

local function siteName(index)
    return getReverse().sites[index] or ("site " .. index)
end

local function legacyName(id)
    return getReverse().legacies[id] or ("legacy " .. id)
end

local function relicName(relicId)
    local item = getReverse().relics[relicId]
    return item and item.name or ("relic " .. relicId)
end

local function foundationNumeral(i)
    local foundation = GUIDs.foundations[i]
    return foundation and (foundation.name:match("^Foundation (%w+)") or foundation.name) or tostring(i)
end

local function oathName(number)
    for name, n in pairs(F.OATH_NUMBERS) do
        if n == number then
            return name
        end
    end
    return nil
end

-- ==============================
-- DECODING
-- ==============================

local function fail(message)
    error(message, 0)
end

-- text split at every separator, keeping empty parts (a trailing separator ends with an empty part)
local function split(text, separator)
    local parts, start = {}, 1
    while true do
        local at = text:find(separator, start, true)
        if not at then
            table.insert(parts, text:sub(start))
            return parts
        end
        table.insert(parts, text:sub(start, at - 1))
        start = at + 1
    end
end

local function checkItem(id)
    if not getReverse().items[id] then
        fail("The string has a card the mod doesn't know (id " .. id .. ").")
    end
    return id
end

local function checkCard(id)
    local item = getReverse().items[id]
    if not item or item.kind ~= "card" then
        fail("The string has a deck card the mod doesn't know (id " .. id .. ").")
    end
    return id
end

local function checkRelic(relicId)
    if not getReverse().relics[relicId] then
        fail("The string has a relic the mod doesn't know (id " .. relicId .. ").")
    end
    return relicId
end

-- Sites: {site = index, items = {ids}}, from tokens each ending in '#' (decodeSites)
local function decodeSites(section)
    local sites = {}
    if section == "" then
        return sites
    end
    local tokens = split(section, "#")
    if tokens[#tokens] ~= "" then
        fail("A list of sites in the string doesn't end the way it should.")
    end
    for i = 1, #tokens - 1 do
        local n = oDecode(tokens[i])
        local index = n % 100
        if not getReverse().sites[index] then
            fail("The string has a site the mod doesn't know (index " .. index .. ").")
        end
        n = math.floor(n / 100)
        local items = {}
        while n > 0 do
            table.insert(items, checkItem(n % 1000))
            n = math.floor(n / 1000)
        end
        table.insert(sites, {site = index, items = items})
    end
    return sites
end

-- Ids packed in chunks, the first chunk rightmost (unpackIds)
local function unpackIds(section, radix)
    if #section % F.CHUNK_WIDTH ~= 0 then
        fail("A deck in the string is the wrong length (" .. #section .. " characters).")
    end
    local ids = {}
    for start = #section - F.CHUNK_WIDTH + 1, 1, -F.CHUNK_WIDTH do
        local n = oDecode(section:sub(start, start + F.CHUNK_WIDTH - 1))
        local k = 0
        while k < F.CHUNK_SIZE and n > 0 do
            table.insert(ids, n % radix)
            n = math.floor(n / radix)
            k = k + 1
        end
    end
    return ids
end

-- Ids packed in one number (unpackNumber)
local function unpackNumber(text, radix)
    local n = oDecode(text)
    local ids = {}
    while n > 0 do
        table.insert(ids, n % radix)
        n = math.floor(n / radix)
    end
    return ids
end

local function checkAll(ids, check)
    for _, id in ipairs(ids) do
        check(id)
    end
    return ids
end

local function decodeFoundations(section, version)
    local mask, oath
    if version == 2 then
        mask, oath = oDecode(section), 0
    else
        if #section ~= FOUNDATIONS_WIDTH + 1 then
            fail("The Foundations in the string are the wrong length.")
        end
        mask = oDecode(section:sub(1, FOUNDATIONS_WIDTH))
        oath = oDecode(section:sub(FOUNDATIONS_WIDTH + 1))
    end
    if mask >= 2 ^ #GUIDs.foundations then
        fail("The Foundations in the string aren't ones the mod knows.")
    end
    return {mask = mask, oath = oath}
end

local function decodePlayer(section, version)
    local fields = split(section, "#")
    if #fields ~= 3 then
        fail("A player in the string doesn't have the three parts it should.")
    end
    local head = fields[1]
    local lineageWidth = version == 2 and 0 or LINEAGE_WIDTH
    if #head < 1 + lineageWidth then
        fail("A player in the string is missing their status or score.")
    end
    local status = oDecode(head:sub(1, 1))
    if not STATUS_ROLES[status] then
        fail("A player in the string has a status the mod doesn't know.")
    end
    local legacyField = fields[2]
    local values = #legacyField < F.CHUNK_WIDTH and unpackNumber(legacyField, F.LEGACY_RADIX)
        or unpackIds(legacyField, F.LEGACY_RADIX)
    local legacies = {}
    for _, value in ipairs(values) do
        local id = value % F.LEGACY_FLIPPED
        if not getReverse().legacies[id] then
            fail("The string has a legacy the mod doesn't know (id " .. id .. ").")
        end
        table.insert(legacies, {id = id, flipped = value > F.LEGACY_FLIPPED})
    end
    return {
        status = status,
        -- version 2 has no lineage scores: nil (the Bookshelf's scores are left as they are)
        lineage = lineageWidth > 0 and oDecode(head:sub(2, 1 + lineageWidth)) or nil,
        cards = checkAll(unpackNumber(head:sub(2 + lineageWidth), F.DECK_RADIX), checkCard),
        legacies = legacies,
        relics = checkAll(unpackNumber(fields[3], F.RELIC_RADIX), checkRelic),
    }
end

-- The Chronicle in an export string, by id: {version, atlasBox, world, worldDeck, relicDeck, dispossessed, reliquary,
-- foundations = {mask, oath}, players = {[color] = {status, lineage, cards, legacies = {{id, flipped}}, relics}},
-- extraPlayers = {{number, player}}}. Whatever the string doesn't record is nil, and the restore leaves that part of
-- the table as it is: a section it stops before, a skipped Reliquary step (an empty section), a player's empty
-- section, and a version 2 player's lineage score (an unset Oath is 0). Errors (as a message for the player) if it
-- can't be read.
function DecodeChronicleString(exportString)
    -- (errors with a message for the player if the string's version, characters or checksum are wrong)
    local plain, version = scramble(tostring(exportString or ""), true)
    local sections = split(plain, ">")
    local namedSections = #SECTIONS + #F.PLAYER_COLORS
    if version < FIRST_EXTRA_PLAYERS_VERSION and #sections > namedSections then
        fail("The string has more sections than a Chronicle does.")
    end
    -- An empty section is how the codec writes one it doesn't have before a later one, so for the sites and the decks
    -- (none of which is empty in a real game) it's nil, not recorded, like a missing one
    local function recorded(decode)
        return function(s)
            if s == "" then
                return nil
            end
            return decode(s)
        end
    end
    local decoders = {
        atlasBox = recorded(decodeSites),
        world = recorded(decodeSites),
        worldDeck = recorded(function(s) return checkAll(unpackIds(s, F.DECK_RADIX), checkCard) end),
        relicDeck = recorded(function(s) return checkAll(unpackIds(s, F.RELIC_RADIX), checkRelic) end),
        dispossessed = recorded(function(s) return checkAll(unpackIds(s, F.DECK_RADIX), checkCard) end),
        -- an empty section is a skipped Reliquary step (an empty Reliquary is "0"): nil, not recorded
        reliquary = function(s) return s ~= "" and checkAll(unpackNumber(s, F.RELIC_RADIX), checkRelic) or nil end,
        foundations = function(s) return decodeFoundations(s, version) end,
    }
    local chronicle = {version = version, players = {}, extraPlayers = {}}
    for i, key in ipairs(SECTIONS) do
        if sections[i] ~= nil then
            chronicle[key] = decoders[key](sections[i])
        end
    end
    -- a player the string stops before (or an empty section, which older writers used) isn't recorded: nil
    for i, color in ipairs(F.PLAYER_COLORS) do
        local section = sections[#SECTIONS + i]
        chronicle.players[color] = section and section ~= "" and decodePlayer(section, version) or nil
    end
    for i = namedSections + 1, #sections do
        if sections[i] ~= "" then
            table.insert(chronicle.extraPlayers, {
                number = FIRST_EXTRA_PLAYER + i - namedSections - 1,
                player = decodePlayer(sections[i], version),
            })
        end
    end
    return chronicle
end

-- ==============================
-- WHAT A CHRONICLE HOLDS
-- ==============================

local function plural(count, word)
    return count .. " " .. word .. (count == 1 and "" or "s")
end

-- color's score on the Bookshelf now, or 0
local function shelfScore(color)
    local bookshelf = getObjectFromGUID(GUIDs.bookshelf)
    local success, score = pcall(function()
        return bookshelf.call("GetScore", color)
    end)
    return success and tonumber(score) or 0
end

-- Whether color's player is empty, with nothing to come out for: no score (the Bookshelf's, if the string has none),
-- and no cards, legacies or relics
local function isIdle(player, color)
    local score = player.lineage or (color and shelfScore(color)) or 0
    return score == 0 and #player.cards + #player.legacies + #player.relics == 0
end

-- The order the players come out in: the Chancellor, then the Citizens, then the Exiles, each with their seat
-- (nil: their own), the first SEAT_COUNT of them. Anyone empty (isIdle) stays stored, whatever their role.
local function seatingOrder(chronicle)
    local order = {}
    for status = 2, 0, -1 do
        for _, color in ipairs(F.PLAYER_COLORS) do
            local player = chronicle.players[color]
            if player and player.status == status and #order < SEAT_COUNT and not isIdle(player, color) then
                table.insert(order, {color = color, seat = status == 2 and CHANCELLOR_SEAT or nil})
            end
        end
    end
    return order
end

-- A readable summary of what restoring chronicle sets up, one line each
function ChronicleRestorePreviewLines(chronicle)
    local lines = {}
    local function add(line)
        table.insert(lines, line)
    end
    local function count(list, word)
        return list and plural(#list, word) or "not in the string (left as it is)"
    end
    local empire = {}
    for _, entry in ipairs(chronicle.world or {}) do
        table.insert(empire, siteName(entry.site))
    end
    add("<b>Atlas Box:</b> " .. count(chronicle.atlasBox, "site"))
    add("<b>Empire:</b> " .. (not chronicle.world and "not in the string (left as it is)"
        or #empire > 0 and table.concat(empire, ", ") or "no sites"))
    add("<b>World Deck:</b> " .. count(chronicle.worldDeck, "card")
        .. "   <b>Relic Deck:</b> " .. count(chronicle.relicDeck, "relic")
        .. "   <b>Dispossessed:</b> " .. count(chronicle.dispossessed, "card"))
    add("<b>Reliquary:</b> " .. count(chronicle.reliquary, "relic"))
    if chronicle.foundations then
        local flipped = {}
        for i = 1, #GUIDs.foundations do
            if math.floor(chronicle.foundations.mask / 2 ^ (i - 1)) % 2 == 1 then
                table.insert(flipped, foundationNumeral(i))
            end
        end
        add("<b>Oath:</b> " .. (oathName(chronicle.foundations.oath) or "unset (left as it is)")
            .. "   <b>Foundations flipped:</b> " .. (#flipped > 0 and table.concat(flipped, ", ") or "none"))
    else
        add("<b>Oath and Foundations:</b> not in the string (left as they are)")
    end
    add("")
    local seats = {}
    for _, seating in ipairs(seatingOrder(chronicle)) do
        seats[seating.color] = seating.seat and ("at the " .. seating.seat .. " seat") or "at their own seat"
    end
    local function describe(label, player)
        local dormant = 0
        for _, legacy in ipairs(player.legacies) do
            if legacy.flipped then
                dormant = dormant + 1
            end
        end
        local legacies = plural(#player.legacies, "legacy"):gsub("legacys", "legacies")
        return "<b>" .. label .. ":</b> " .. ROLE_NAMES[STATUS_ROLES[player.status]] .. ", "
            .. (player.lineage and ("score " .. player.lineage) or "score not in the string (left as it is)") .. ". " .. plural(#player.cards, "card") .. ", " .. legacies
            .. (dormant > 0 and (" (" .. dormant .. " dormant)") or "") .. ", " .. plural(#player.relics, "relic") .. "."
    end
    for _, color in ipairs(F.PLAYER_COLORS) do
        local player = chronicle.players[color]
        if not player then
            add("<b>" .. color .. ":</b> not in the string (left as they are, and back where they were if they're out).")
        else
            local seat = seats[color] and ("Comes out " .. seats[color] .. ".")
                or (isIdle(player, color) and "Stays stored (no score and nothing to lay out)."
                or "Stays stored (no seat left).")
            add(describe(color, player) .. " " .. seat)
        end
    end
    for _, extra in ipairs(chronicle.extraPlayers) do
        add(describe("Player " .. extra.number, extra.player) .. " The mod has no color for them, so they aren't restored.")
    end
    return lines
end

-- ==============================
-- THE RESTORE IN PROGRESS
-- ==============================

-- {chronicle, warnings, finished, onStatus, startedAt, frame, ...}, while a restore runs
local restore = nil

local function warn(message)
    table.insert(restore.warnings, message)
end

function IsChronicleRestoreRunning()
    return restore ~= nil
end

-- Every step goes to the chat (grey, "[Restore +12.3s] ...") and the log, and to the restore window's status line
local TRACE = true
local TRACE_COLOR = {0.65, 0.65, 0.65}

-- Seconds, measured in frames (so it's the same whatever the game's clock does)
local FRAMES_PER_SECOND = 60

local function trace(message)
    if not restore then
        return
    end
    local line = string.format("[Restore +%.1fs] %s", restore.frame / FRAMES_PER_SECOND, message)
    if TRACE then
        printToAll(line, TRACE_COLOR)
        log(line)
    end
    if restore.onStatus then
        pcall(restore.onStatus, message)
    end
end

local function finish(failure)
    if not restore then
        return
    end
    trace(failure and ("Stopped: " .. failure) or ("Done, with " .. #restore.warnings .. " warning(s)."))
    local finished, warnings = restore.finished, restore.warnings
    restore = nil
    if finished then
        finished(failure, warnings)
    end
end

-- ==============================
-- RUNNING STEP BY STEP
--
-- The restore is one coroutine, resumed every frame, so each
-- move can wait for the last to land. An error stops it with a
-- message naming the step it was on.
-- ==============================

local function pause(frames)
    for _ = 1, frames or 1 do
        coroutine.yield()
    end
end

local function step(name)
    restore.step = name
    trace(name .. "...")
end

-- Waits (yielding) until pending() returns nil, saying every couple of seconds what it still returns. Gives up after
-- timeout seconds. Returns whether it finished waiting.
local function waitUntil(what, pending, timeout)
    local frames = 0
    while true do
        local left = pending()
        if left == nil then
            return true
        end
        if frames >= timeout * FRAMES_PER_SECOND then
            trace("Gave up waiting for " .. what .. " after " .. timeout .. "s: " .. tostring(left))
            return false
        end
        if frames > 0 and frames % (2 * FRAMES_PER_SECOND) == 0 then
            trace("Still waiting for " .. what .. ": " .. tostring(left))
        end
        frames = frames + 1
        coroutine.yield()
    end
end

local function runRestore(body)
    local co = coroutine.create(body)
    local function resume()
        if not restore then
            return
        end
        restore.frame = restore.frame + 1
        local success, problem = coroutine.resume(co)
        if not success then
            finish("It went wrong while " .. tostring(restore.step):lower() .. ": " .. tostring(problem))
        elseif coroutine.status(co) ~= "dead" then
            Wait.frames(resume, 1)
        end
    end
    resume()
end

-- ==============================
-- THE PIECES ON THE TABLE
-- ==============================

local CARD_TAGS = {card = true, relic = true, lineage = true, edifice = true}

-- What a piece is in the Chronicle, as a pool key: "S<index>" for a site, "L<id>" for a legacy, "I<id>" for a card,
-- edifice or relic. nil if it isn't part of the Chronicle. Takes a name and tags (from data, a bag entry or an object).
local function keyOf(name, tagList, isCardType)
    local ids = F.getLookups()
    local piece = {Tags = tagList}
    if PieceDataHasTag(piece, tags.site) then
        local index = ids.sites[F.nameKey(name or "")]
        return index and ("S" .. index) or nil
    end
    if not isCardType then
        for _, tag in ipairs(tagList or {}) do
            isCardType = isCardType or CARD_TAGS[tag:lower()]
        end
    end
    if not isCardType then
        return nil
    end
    local key = F.nameKey(name or "")
    if PieceDataHasTag(piece, "Lineage") then
        local id = ids.legacies[key]
        return id and ("L" .. id) or nil
    end
    local id = (ids.relics[key] and ids.relics[key].id) or ids.edifices[key] or ids.cards[key]
    return id and ("I" .. id) or nil
end

local function dataKey(data)
    return keyOf(data.Nickname, data.Tags, data.Name == "Card" or data.Name == "CardCustom")
end

local function entryKey(entry)
    return keyOf(entry.name, entry.tags)
end

local CHILD_LISTS = {"ContainedObjects", "ChildObjects"}

-- Objects the restore leaves alone: the Atlas Box's site preview (copies of the cards on top of the box)
local function isExcluded(object)
    return object.getDescription and object.getDescription() == "SITE PREVIEW"
end

-- Whether position is in one of the map slots' site areas (the Empire, as the export reads it)
local function inEmpire(position)
    local map = getObjectFromGUID(GUIDs.map)
    if not map then
        return false
    end
    local mapTransform = {position = map.getPosition()}
    for slot = 1, MAP_SLOTS do
        local center = vectorSum(getTransformStruct("site", slot, mapTransform).position, F.SITE_AREA_OFFSET)
        if math.abs(position.x - center.x) <= F.SITE_AREA_SIZE.x / 2
            and math.abs(position.z - center.z) <= F.SITE_AREA_SIZE.z / 2 then
            return true
        end
    end
    return false
end

-- What the restore leaves as it is because the string doesn't record it: guids (whole objects on the table), nodes
-- (objects inside others), empire (whether the Empire stays), and relicDeck (the Relic Deck that stays)
local function keptParts(chronicle)
    local keep = {guids = {}, nodes = {}, empire = chronicle.world == nil}
    local function keepObject(object)
        if object then
            keep.guids[object.getGUID()] = true
        end
        return object
    end
    if chronicle.atlasBox == nil then
        keep.guids[GUIDs.atlasBox] = true
    end
    if chronicle.relicDeck == nil then
        keep.relicDeck = keepObject(F.findRelicDeck())
    end
    if chronicle.reliquary == nil then
        keep.nodes[GUIDs.imperialReliquary] = true
        keep.guids[GUIDs.imperialReliquary] = true
    end
    for _, color in ipairs(F.PLAYER_COLORS) do
        if chronicle.players[color] == nil then
            keep.guids[GUIDs.playerArchives[color] or ""] = true
        end
    end
    return keep
end

local storageBoxes = nil

-- Whether guid is a player's storage box (never looked into: taking one out runs its script)
local function isStorageBox(guid)
    if not storageBoxes then
        storageBoxes = {}
        for _, boxGuid in pairs(GUIDs.storageBags) do
            storageBoxes[boxGuid] = true
        end
    end
    return storageBoxes[guid] == true
end

-- ==============================
-- STAGING
-- ==============================

-- Above the table, out of the way: where containers in the way, and pieces between places, wait (locked, so they
-- don't fall). Each gets its own spot.
local STAGING_HEIGHT = 18
local STAGING_COLUMNS = 20
local STAGING_SPACING_X, STAGING_SPACING_Z = 6, 9

local function stagingSpot()
    local k = restore.staged
    restore.staged = k + 1
    local base = restore.mapPosition
    return {
        x = base.x - 57 + (k % STAGING_COLUMNS) * STAGING_SPACING_X,
        y = base.y + STAGING_HEIGHT + math.floor(k / (STAGING_COLUMNS * 4)) * 2,
        z = base.z - 27 + (math.floor(k / STAGING_COLUMNS) % 4) * STAGING_SPACING_Z,
    }
end

local function above(position, height)
    return {x = position.x, y = position.y + (height or 1), z = position.z}
end

-- ==============================
-- WHERE THE PIECES ARE
--
-- GUIDs can't tell pieces apart: cards inside decks can share
-- one (the archive decks do), and a piece taken out of a
-- container may get a new one. So each piece is tracked by where
-- it is: a location is {object} for a piece loose on the table,
-- {holder} for one directly inside a container on the table, or
-- {parent, innerGuid} for one inside a container (a site bag, the
-- Reliquary) that's inside another. A piece in a container is
-- taken out by the index of an entry with its name.
-- ==============================

local function addLocation(key, location, kept)
    location.key = key
    table.insert(restore.locations, location)
    local index = kept and restore.keptIndex or restore.index
    index[key] = index[key] or {}
    table.insert(index[key], location)
end

-- Every Chronicle piece on the table, from the table's data, into restore.index (and restore.keptIndex for the ones
-- in parts the string doesn't record) by key. Returns how many there are.
local function scanPieces(keep)
    restore.index, restore.keptIndex = {}, {}
    local count = 0
    for _, object in ipairs(getAllObjects()) do
        if not isExcluded(object) then
            local data = object.getData()
            local topKept = keep.guids[data.GUID] == true
            local key = dataKey(data)
            if key then
                count = count + 1
                addLocation(key, {object = object}, topKept or (keep.empire and inEmpire(object.getPosition())))
            end
            local function walk(node, depth, kept, innerGuid)
                for _, listName in ipairs(CHILD_LISTS) do
                    for _, child in ipairs(node[listName] or {}) do
                        local childKept = kept or keep.nodes[child.GUID] == true
                        local childKey = dataKey(child)
                        if childKey then
                            count = count + 1
                            if depth == 1 then
                                addLocation(childKey, {holder = object, guid = child.GUID}, childKept)
                            elseif depth == 2 then
                                addLocation(childKey, {parent = object, innerGuid = innerGuid}, childKept)
                            else
                                warn(child.Nickname .. " is too deep inside other containers to reach, so it stays there.")
                            end
                        end
                        if not isStorageBox(child.GUID) then
                            walk(child, depth + 1, childKept, depth == 1 and child.GUID or innerGuid)
                        end
                    end
                end
            end
            walk(data, 1, topKept, nil)
        end
    end
    return count
end

-- Points every location inside the container innerGuid (in parent) at that container, now it's out on the table as
-- opened
local function rebindInner(parent, innerGuid, opened)
    for _, location in ipairs(restore.locations) do
        if location.parent == parent and location.innerGuid == innerGuid then
            location.parent, location.innerGuid, location.holder = nil, nil, opened
        end
    end
end

-- How long (frames) to wait for something just taken out of a container to finish spawning
local SPAWN_WAIT_FRAMES = 120

-- Waits (yielding) until object, just taken out of a container, has finished spawning: until then TTS doesn't treat
-- it as what it is (a bag taken out can't be looked into yet)
local function settle(object)
    local frames = 0
    while object and not object.isDestroyed() and object.spawning and frames < SPAWN_WAIT_FRAMES do
        frames = frames + 1
        coroutine.yield()
    end
    return object
end

-- What's in container ({} if it can't be looked into, with a warning)
local function contentsOf(container)
    if not container or container.isDestroyed() then
        return {}
    end
    local success, entries = pcall(function()
        return container.getObjects()
    end)
    if not success or type(entries) ~= "table" then
        warn("Couldn't look into " .. container.getName() .. " (" .. container.getGUID() .. ").")
        return {}
    end
    return entries
end

-- Takes the container innerGuid out of parent onto a staging spot, so what's in it can be reached, and points every
-- location inside it at it. It goes back at the end. Returns it.
local function openContainer(parent, innerGuid)
    local opened = nil
    if parent and not parent.isDestroyed() then
        if parent.getGUID() == GUIDs.atlasBox then
            opened = parent.call("TakeSite", {guid = innerGuid, position = stagingSpot()})
        else
            opened = parent.takeObject({guid = innerGuid, position = stagingSpot(), smooth = false})
        end
    end
    if not opened then
        return nil
    end
    settle(opened)
    opened.setLock(true)
    table.insert(restore.opened, {object = opened, into = parent})
    rebindInner(parent, innerGuid, opened)
    -- the container itself, if it's a piece (a site), is loose now
    for _, location in ipairs(restore.locations) do
        if location.holder == parent and location.guid == innerGuid then
            location.holder, location.guid, location.object = nil, nil, opened
        end
    end
    pause(1)
    return opened
end

-- The next location of a piece for key (the restore's own first, then any in parts the string doesn't record), or
-- nil with a warning saying it's missing from where
local function choose(key, what, where)
    for _, index in ipairs({restore.index, restore.keptIndex}) do
        local locations = index[key]
        if locations and #locations > 0 then
            local location = table.remove(locations, 1)
            location.key = key
            return location
        end
    end
    warn(what .. " wasn't found anywhere on the table (outside the storage boxes), so it's missing from " .. where .. ".")
    return nil
end

-- When a deck is left with one card it turns into that card: any location in the old deck now points at it
local function deckDissolved(deck)
    local remainder = deck.remainder
    for _, location in ipairs(restore.locations) do
        if location.holder == deck then
            location.holder, location.guid, location.object = nil, nil, remainder
        end
    end
end

-- Takes the piece at location out of wherever it is and puts it at position, turned to rotation. Returns the object,
-- or nil (with a warning) if it isn't there any more.
local function fetch(location, position, rotation)
    if location.parent then
        openContainer(location.parent, location.innerGuid)
    end
    if location.object then
        local object = location.object
        if object.isDestroyed() then
            warn("A " .. tostring(location.key) .. " piece went missing before it could be moved.")
            return nil
        end
        object.setLock(false)
        object.setPosition(position)
        if rotation then
            object.setRotation(rotation)
        end
        return object
    end
    local holder = location.holder
    if not holder or holder.isDestroyed() then
        warn("A " .. tostring(location.key) .. " piece's container ("
            .. (holder and (holder.getName() .. " " .. holder.getGUID()) or "none") .. ") went missing before it could be moved.")
        return nil
    end
    local index, entryGuid = nil, nil
    for _, entry in ipairs(contentsOf(holder)) do
        if entryKey(entry) == location.key and (location.guid == nil or entry.guid == location.guid) then
            index, entryGuid = entry.index, entry.guid
            break
        end
    end
    if index == nil then
        warn("A " .. tostring(location.key) .. " piece wasn't in " .. holder.getName() .. " any more.")
        return nil
    end
    local taken
    if holder.getGUID() == GUIDs.atlasBox then
        taken = holder.call("TakeSite", {guid = entryGuid, position = position, rotation = rotation})
    else
        taken = holder.takeObject({index = index, position = position, rotation = rotation, smooth = false})
    end
    if not taken then
        warn("A " .. tostring(location.key) .. " piece couldn't be taken out of " .. holder.getName() .. ".")
        return nil
    end
    -- a card out of a deck is the deck's size (cards in a deck can carry a different size of their own, and would
    -- come out small)
    if holder.type == "Deck" and not holder.isDestroyed() then
        taken.setScale(holder.getScale())
    end
    -- it's loose now; and if it holds pieces itself (a site bag), they're in it
    location.holder, location.guid, location.object = nil, nil, taken
    rebindInner(holder, entryGuid, taken)
    if holder.type == "Deck" and (holder.remainder or holder.isDestroyed()) then
        deckDissolved(holder)
    end
    settle(taken)
    return taken
end

local function isArchive(object)
    for _, guid in pairs(GUIDs.playerArchives) do
        if object.getGUID() == guid then
            return true
        end
    end
    return false
end

local function isAtlasBox(object)
    return object.getGUID() == GUIDs.atlasBox
end

-- Puts object into container (an archive through its StoreObject, the Atlas Box through its StoreSite, a site bag
-- unlocked). Returns the container it's in now (putting a card on a card makes a deck).
local function putInto(container, object)
    local result
    if isArchive(container) then
        container.call("StoreObject", object)
        result = container
    elseif isAtlasBox(container) then
        -- at the back of the box, face down
        container.call("StoreSite", object)
        result = container
    else
        if container.hasTag(tags.site) then
            -- a site bag only takes cards while it's unlocked
            container.setLock(false)
        end
        result = container.putObject(object) or container
    end
    pause(1)
    return result
end

local function guidsOf(entries)
    local guids = {}
    for _, entry in ipairs(entries) do
        table.insert(guids, entry.guid)
    end
    return guids
end

local function sameList(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function reversed(list)
    local result = {}
    for i = #list, 1, -1 do
        table.insert(result, list[i])
    end
    return result
end

-- Makes a deck at position from the pieces at locations, in that order (the first on top, as the export reads it),
-- by putting the real cards on each other. Which end a card goes in when it's put on a deck is learned from the first
-- deck (restore.putsOnTop), which is built again if it came out the wrong way round. Returns the deck (or lone card).
local function buildDeck(locations, position, rotation, nickname, memo)
    if #locations == 0 then
        return nil
    end
    -- the cards come out first (onto staging spots), so they're objects with their own GUIDs on the table
    local cards = {}
    for _, location in ipairs(locations) do
        local card = fetch(location, stagingSpot(), rotation)
        if card then
            card.setLock(true)
            table.insert(cards, card)
        end
    end
    local wanted = {}
    for _, card in ipairs(cards) do
        table.insert(wanted, card.getGUID())
    end
    local function assemble(order)
        local deck = nil
        for _, card in ipairs(order) do
            card.setLock(false)
            card.setPosition(deck and above(position) or position)
            card.setRotation(rotation)
            if deck then
                pause(1)
                deck = deck.putObject(card) or deck
                pause(1)
            else
                deck = card
            end
        end
        return deck
    end
    local onTop = restore.putsOnTop ~= false
    local deck = assemble(onTop and reversed(cards) or cards)
    pause(2)
    if deck and deck.type == "Deck" then
        local got = guidsOf(contentsOf(deck))
        if sameList(got, wanted) then
            restore.putsOnTop = onTop
        elseif sameList(got, reversed(wanted)) and restore.putsOnTop == nil then
            -- learned: cards go in the other end. Take them back out and build it again the other way round.
            restore.putsOnTop = not onTop
            trace("Cards go into a deck the other way round from what was guessed: building the " .. nickname .. " again.")
            local again = {}
            while deck and not deck.isDestroyed() and deck.type == "Deck" do
                local card = deck.takeObject({index = 0, position = stagingSpot(), smooth = false})
                if card then
                    card.setLock(true)
                    again[card.getGUID()] = card
                end
                if deck.remainder then
                    again[deck.remainder.getGUID()] = deck.remainder
                    break
                end
                pause(1)
            end
            local ordered = {}
            for _, guid in ipairs(wanted) do
                if again[guid] then
                    table.insert(ordered, again[guid])
                end
            end
            deck = assemble(restore.putsOnTop and reversed(ordered) or ordered)
            pause(2)
        else
            trace("The " .. nickname .. " didn't come out in the string's order.")
            warn("The " .. nickname .. " isn't in quite the order the string has it.")
        end
    end
    if deck then
        if deck.type == "Deck" then
            deck.setName(nickname)
        end
        if memo then
            deck.setMemo(memo)
        end
    end
    return deck
end

-- ==============================
-- PLAYERS' PIECES
-- ==============================

-- Where a piece goes on its player's mat, relative to their board (as the Bookshelf's card layout keeps it): slot
-- index of slots, face down or up
local function matLayoutSpot(slots, index, faceDown)
    local wrap = math.floor((index - 1) / #slots)
    local slot = slots[(index - 1) % #slots + 1]
    local board = pos.playerBoard(1)
    local dx, dz = slot.x + MAT_WRAP_SHIFT * wrap - board.x, slot.z - board.z
    -- the offset turned into the board's own axes (TransformOnBoard in src/Bookshelf)
    local yaw = math.rad(rot.playerBoard.y)
    return {
        position = {
            x = dx * math.cos(yaw) - dz * math.sin(yaw),
            y = MAT_PIECE_HEIGHT + MAT_WRAP_LIFT * wrap,
            z = dx * math.sin(yaw) + dz * math.cos(yaw),
        },
        rotation = {x = 0, y = 0, z = faceDown and 180 or 0},
    }
end

-- ==============================
-- AFTER THE PIECES ARE IN PLACE
-- ==============================

-- Turns each Foundation face down if the Chronicle has it flipped, otherwise face up
local function setFoundations(mask)
    for i, foundation in ipairs(GUIDs.foundations) do
        local card = getObjectFromGUID(foundation.GUID)
        local flipped = math.floor(mask / 2 ^ (i - 1)) % 2 == 1
        if card then
            local rotation = card.getRotation()
            card.setRotation({x = rotation.x, y = rotation.y, z = flipped and 180 or 0})
        else
            warn(foundation.name .. " wasn't found (is it in a deck?), so turn it " .. (flipped and "face down" or "face up")
                .. " yourself.")
        end
    end
end

-- Puts the Oathkeeper tile for oath in play, swapping it with the one there
local function setOath(oath)
    local wanted = oathName(oath)
    if not wanted then
        return
    end
    local map = getObjectFromGUID(GUIDs.map)
    local center = map and map.getPosition() or {x = 0, y = 0, z = 0}
    local inPlay, inPlayDistance, target = nil, F.OATH_IN_PLAY_RADIUS, nil
    for _, object in ipairs(getAllObjects()) do
        local name = object.getName():match("^Oathkeeper of (.+)$")
        if name then
            name = name:gsub("^the ", "")
            local distance = F.horizontalDistance(object.getPosition(), center)
            if distance <= inPlayDistance then
                inPlay, inPlayDistance = object, distance
            end
            if name == wanted then
                target = object
            end
        end
    end
    if not target then
        warn("The Oathkeeper of " .. wanted .. " tile wasn't found, so put it in play yourself.")
    elseif not inPlay then
        warn("No Oathkeeper tile is in play, so put the Oathkeeper of " .. wanted .. " tile in play yourself.")
    elseif inPlay ~= target then
        local position, rotation = inPlay.getPosition(), inPlay.getRotation()
        inPlay.setPosition(target.getPosition())
        inPlay.setRotation(target.getRotation())
        target.setPosition(position)
        target.setRotation(rotation)
    end
end

-- Each player's score and role on the Bookshelf. A player the string doesn't record, or a score it doesn't have, is
-- left as it is.
local function setScoresAndRoles(bookshelf, chronicle)
    for _, color in ipairs(F.PLAYER_COLORS) do
        local player = chronicle.players[color]
        if player and player.lineage then
            bookshelf.call("SetScore", {color = color, score = player.lineage})
        end
        local role = player and STATUS_ROLES[player.status]
        if role and bookshelf.call("GetRole", color) ~= role
            and not bookshelf.call("SetRole", {color = color, role = role}) then
            warn(color .. "'s role couldn't be set to " .. ROLE_NAMES[role] .. ". Set it on the Bookshelf.")
        end
    end
end

local function objectLabel(object)
    local name = object.getName()
    return (name ~= "" and name or object.type or "object") .. " (" .. object.getGUID() .. ")"
end

-- Seconds to wait for each player to come out before giving up on them
local WITHDRAW_TIMEOUT = 75

-- ==============================
-- THE RESTORE, STEP BY STEP
-- ==============================

local function restoreBody()
    local chronicle = restore.chronicle
    local bookshelf = getObjectFromGUID(GUIDs.bookshelf)
    local map = getObjectFromGUID(GUIDs.map)
    restore.mapPosition = map and map.getPosition() or {x = 0, y = 1.03, z = 0}
    local mapPosition = restore.mapPosition
    local out = bookshelf and bookshelf.getTable("withdrawnMats") or {}
    if next(out) ~= nil then
        warn("Someone was already out on the table. The restore is for a fresh copy of the mod, so check their mat.")
    end

    -- 1. where every piece is now
    step("Looking over the table")
    local keep = keptParts(chronicle)
    local pieceCount = scanPieces(keep)
    local keptList = {}
    for guid in pairs(keep.guids) do
        local object = getObjectFromGUID(guid)
        table.insert(keptList, object and objectLabel(object) or guid)
    end
    if keep.empire then
        table.insert(keptList, "the Empire")
    end
    trace("Found " .. pieceCount .. " Chronicle pieces. Left as they are (not in the string): "
        .. (#keptList > 0 and table.concat(keptList, ", ") or "nothing") .. ".")

    -- 2. the sites come out of the Atlas Box, to be laid out and put back in the string's order
    local atlas = getObjectFromGUID(GUIDs.atlasBox)
    if chronicle.atlasBox and atlas then
        step("Taking the sites out of the Atlas Box")
        local inBox = {}
        for _, locations in pairs(restore.index) do
            for _, location in ipairs(locations) do
                if location.holder == atlas then
                    table.insert(inBox, location)
                end
            end
        end
        for _, location in ipairs(inBox) do
            local site = fetch(location, stagingSpot())
            if site then
                site.setLock(true)
            end
        end
    elseif chronicle.atlasBox then
        warn("The Atlas Box isn't on the table, so its sites couldn't be put away.")
    end

    -- 3. the Empire: each site on the next map slot, locked, and its pieces on the spots beside it
    if chronicle.world then
        step("Laying out the Empire")
        for slot, entry in ipairs(chronicle.world) do
            if slot > MAP_SLOTS then
                warn("The string has more sites in the Empire than the map holds. The rest went in the Atlas Box.")
                break
            end
            local location = choose("S" .. entry.site, siteName(entry.site), "the Empire")
            local base = vectorSum(mapPosition, pos.site(slot))
            local site = location and fetch(location, base, rot.site)
            if site then
                site.setLock(true)
                for i, id in ipairs(entry.items) do
                    local itemLocation = choose("I" .. id, itemName(id), siteName(entry.site))
                    if itemLocation then
                        local offset = pos.denizen(i - 1)
                        local rotation = getReverse().items[id].kind == "relic" and RELIC_ON_SITE or rot.denizen
                        fetch(itemLocation, {x = base.x + offset.x, y = base.y + DROP_HEIGHT, z = base.z + offset.z}, rotation)
                    end
                end
            end
        end
    end

    -- 4. the World Deck and the Dispossessed, from the real cards, in order
    local function chooseAll(ids, keyOf, nameOf, where)
        local locations = {}
        for _, id in ipairs(ids or {}) do
            local location = choose(keyOf(id), nameOf(id), where)
            if location then
                table.insert(locations, location)
            end
        end
        return locations
    end
    local function cardKey(id) return "I" .. id end
    local function relicKey(relicId) return "I" .. getReverse().relics[relicId].id end
    if chronicle.worldDeck then
        step("Making the World Deck")
        buildDeck(chooseAll(chronicle.worldDeck, cardKey, itemName, "the World Deck"),
            vectorSum(mapPosition, pos.worldDeck(0)), rot.worldDeck, "World Deck")
    end
    if chronicle.dispossessed then
        step("Making the Dispossessed")
        buildDeck(chooseAll(chronicle.dispossessed, cardKey, itemName, "the Dispossessed"),
            vectorSum(mapPosition, pos.dispossessed(0)), rot.dispossessed, "Dispossessed")
    end
    -- (the Relic Deck's relics are set aside now; it's made last, so relics the string doesn't place can go at the
    -- bottom)
    local relicDeckLocations = chronicle.relicDeck and chooseAll(chronicle.relicDeck, relicKey, relicName, "the Relic Deck")

    -- 5. the Atlas Box: each site back in, in order, holding its pieces
    if chronicle.atlasBox and atlas then
        step("Filling the Atlas Box")
        for _, entry in ipairs(chronicle.atlasBox) do
            local location = choose("S" .. entry.site, siteName(entry.site), "the Atlas Box")
            local site = location and fetch(location, stagingSpot(), {x = 0, y = 180, z = 0})
            if site then
                site.setLock(true)
                for _, id in ipairs(entry.items) do
                    local itemLocation = choose("I" .. id, itemName(id), siteName(entry.site) .. " in the Atlas Box")
                    local item = itemLocation and fetch(itemLocation, above(site.getPosition(), 2))
                    if item then
                        pause(1)
                        putInto(site, item)
                    end
                end
                site.setLock(false)
                putInto(atlas, site)
            end
        end
        -- any site the string doesn't place goes back in too, at the back
        local extraSites = {}
        for key, locations in pairs(restore.index) do
            if key:sub(1, 1) == "S" then
                for _, location in ipairs(locations) do
                    if location.object and not location.object.isDestroyed() then
                        table.insert(extraSites, siteName(tonumber(key:sub(2))))
                        location.object.setLock(false)
                        putInto(atlas, location.object)
                    end
                end
            end
        end
        if #extraSites > 0 then
            warn("Not in the Chronicle, so put at the back of the Atlas Box: " .. table.concat(extraSites, ", ") .. ".")
        end
    end

    -- 6. the Reliquary: out of the Chancellor Archive (it goes back afterwards), and its relics in
    if chronicle.reliquary then
        step("Filling the Reliquary")
        local reliquary = getObjectFromGUID(GUIDs.imperialReliquary)
            or openContainer(getObjectFromGUID(GUIDs.playerArchives.Purple), GUIDs.imperialReliquary)
        if reliquary then
            for _, relicId in ipairs(chronicle.reliquary) do
                local location = choose(relicKey(relicId), relicName(relicId), "the Reliquary")
                local relic = location and fetch(location, above(reliquary.getPosition(), 2))
                if relic then
                    pause(1)
                    putInto(reliquary, relic)
                end
            end
        else
            warn("The Imperial Reliquary wasn't found, so its relics weren't put in it.")
        end
    end

    -- 7. players: into their archive, with where each piece goes on their mat
    for _, color in ipairs(F.PLAYER_COLORS) do
        local player = chronicle.players[color]
        local archive = player and getObjectFromGUID(GUIDs.playerArchives[color] or "")
        if player and not archive then
            warn(color .. "'s archive isn't on the table, so their cards, legacies and relics weren't put in it.")
        elseif player and #player.cards + #player.legacies + #player.relics > 0 then
            step("Packing " .. color .. "'s archive")
            local layout = {}
            local function add(key, what, slots, index, faceDown)
                local location = choose(key, what, color .. "'s archive")
                local piece = location and fetch(location, stagingSpot(), {x = 0, y = 180, z = faceDown and 180 or 0})
                if piece then
                    layout[piece.getGUID()] = matLayoutSpot(slots, index, faceDown)
                    pause(1)
                    putInto(archive, piece)
                end
            end
            for i, id in ipairs(player.cards) do
                add("I" .. id, itemName(id), MAT_SLOTS.cards, i, false)
            end
            for i, legacy in ipairs(player.legacies) do
                add("L" .. legacy.id, legacyName(legacy.id), MAT_SLOTS.legacies, i, legacy.flipped)
            end
            for i, relicId in ipairs(player.relics) do
                add(relicKey(relicId), relicName(relicId), MAT_SLOTS.relics, i, false)
            end
            archive.call("SetCardLayout", layout)
        end
    end

    -- 8. the Relic Deck, last: its relics in order, then any the string doesn't place (so the relic pile is used up)
    if relicDeckLocations then
        step("Making the Relic Deck")
        local extraRelics = {}
        for key, locations in pairs(restore.index) do
            local item = key:sub(1, 1) == "I" and getReverse().items[tonumber(key:sub(2))]
            if item and item.kind == "relic" then
                for _, location in ipairs(locations) do
                    table.insert(extraRelics, item.name)
                    table.insert(relicDeckLocations, location)
                end
            end
        end
        if #extraRelics > 0 then
            warn("Not in the Chronicle, so put at the bottom of the Relic Deck: " .. table.concat(extraRelics, ", ") .. ".")
        end
        buildDeck(relicDeckLocations, vectorSum(mapPosition, pos.relicStack(0)), rot.relicStack, "Relic Deck", "relicDeck")
    end

    -- 9. what was opened goes back (the Reliquary into the Chancellor Archive); anything still up on the staging spots
    -- is left there with a warning
    for i = #restore.opened, 1, -1 do
        local opened = restore.opened[i]
        if not opened.object.isDestroyed() and opened.into and not opened.into.isDestroyed() then
            opened.object.setLock(false)
            putInto(opened.into, opened.object)
        end
    end
    local leftUp = {}
    for _, object in ipairs(getAllObjects()) do
        if object.getLock() and object.getPosition().y > mapPosition.y + STAGING_HEIGHT - 3 and not isExcluded(object) then
            table.insert(leftUp, objectLabel(object))
        end
    end
    if #leftUp > 0 then
        warn("These were left up above the table (locked): " .. table.concat(leftUp, ", ") .. ". Put them away yourself.")
    end

    -- 10. the Atlas Box shows the Chronicle as created, with its most recent site in the preview
    if atlas and not atlas.isDestroyed() and (chronicle.atlasBox or chronicle.world) then
        step("Finishing the Atlas Box")
        atlas.call("FinishChronicleSetup")
    end

    -- 11. Foundations, the Oath, scores and roles
    step("Setting the Foundations, the Oath, scores and roles")
    if chronicle.foundations then
        setFoundations(chronicle.foundations.mask)
        setOath(chronicle.foundations.oath)
    end
    if not bookshelf then
        warn("The Bookshelf isn't on the table, so nobody's role or score was set and nobody came out.")
        return
    end
    setScoresAndRoles(bookshelf, chronicle)

    -- 12. the players come out, one at a time
    for _, nextUp in ipairs(seatingOrder(chronicle)) do
        -- withdrawn as if clicked from the Purple seat if they're the Chancellor (who stays Purple, at that seat),
        -- otherwise as the Game Master (at their own seat). Only if the Bookshelf really has them as the Chancellor:
        -- a Purple click for anyone else would swap the Purple seat's color.
        local asChancellor = bookshelf.call("GetRole", nextUp.color) == "CHANCELLOR"
        step("Bringing " .. nextUp.color .. " out at " .. (asChancellor and "the Purple seat" or "their own seat"))
        restore.withdrawn = nil
        local started = bookshelf.call("Withdraw", {
            color = nextUp.color,
            player = asChancellor and CHANCELLOR_SEAT or "Black",
            callback = "ChronicleRestoreWithdrawn",
        })
        if not started then
            warn(nextUp.color .. " couldn't be brought out onto the table. Withdraw them from the Bookshelf.")
        else
            waitUntil(nextUp.color .. " to come out", function()
                return restore.withdrawn == nil and "their pieces and storage box" or nil
            end, WITHDRAW_TIMEOUT)
            if (restore.withdrawn or {}).timedOut then
                warn(nextUp.color .. " took a long time to come out. Check their mat.")
            end
            pause(10)
        end
    end
end

-- The Bookshelf calls this back as each player has come out
function ChronicleRestoreWithdrawn(result)
    if restore then
        restore.withdrawn = result or {}
    end
end

-- Starts restoring exportString. finished(failure, warnings) is called at the end: failure is a message if it
-- stopped, nil if it finished. onStatus(message), if given, gets each step as it happens. Returns false and a message
-- if it can't start.
function StartChronicleRestore(exportString, finished, onStatus)
    if restore then
        return false, "A Chronicle is already being restored."
    end
    local success, chronicle = pcall(DecodeChronicleString, exportString)
    if not success then
        return false, tostring(chronicle)
    end
    restore = {
        chronicle = chronicle, warnings = {}, finished = finished, onStatus = onStatus, frame = 0, staged = 0,
        opened = {}, locations = {}, step = "starting",
    }
    local recorded = {}
    for _, key in ipairs(SECTIONS) do
        table.insert(recorded, key .. (chronicle[key] ~= nil and "" or " (not recorded)"))
    end
    for _, color in ipairs(F.PLAYER_COLORS) do
        local player = chronicle.players[color]
        table.insert(recorded, color .. (player and (" " .. ROLE_NAMES[STATUS_ROLES[player.status]]) or " (not recorded)"))
    end
    trace("Started: encoding version " .. chronicle.version .. "; " .. table.concat(recorded, ", ") .. ".")
    for _, extra in ipairs(chronicle.extraPlayers) do
        warn("Player " .. extra.number .. " in the string has no color in the mod, so they weren't restored: their "
            .. "cards, edifices, legacies and relics went home, and their role and score aren't kept anywhere.")
    end
    runRestore(function()
        restoreBody()
        finish(nil)
    end)
    return true
end
