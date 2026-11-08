-- ==============================
-- OATH BANNERS
--
-- The People's Favor and the Darkest Secret run this (which one
-- it is comes from GUIDs.banners). Each counts the favor or
-- secrets on it, through a scripting zone over it that follows it
-- around, and shows the count on its center right, on whichever
-- side is up. Triples count 3.
--
-- People's Favor, right-click "Return Favor": face up (the Mob),
-- all of it goes to the poorest favor banks one at a time; flipped
-- (the Grand Council), half (rounded down) is set beside it for
-- the previous holder and the rest goes to the banks.
--
-- Darkest Secret, right-click "Resolve Challenge" or "Resolve
-- Campaign", for its Wandering Flame side (face up) and Festival
-- side (flipped).
--
-- Pieces leave one at a time, as singles: a triple is swapped
-- for three singles from the supply first.
-- ==============================

require("src/Config/GeneralConfig")
require("src/Utils/HelperFunctions")

-- How far (world units) the zone reaches above the banner
local ZONE_HEADROOM = 4.3

-- Seconds to wait for a moved banner to settle before refitting its zone wherever it is
local SETTLE_TIMEOUT = 1

-- The count label: where it sits (the banner's own units: x across, z along, on the face that's up), and its look
local LABEL_X = 0.75
local LABEL_Y = 0.22
local LABEL_FONT_SIZE = 300
local LABEL_FONT_COLOR = {1, 1, 1}

-- The corner buttons (challenge top left, campaign top right): how far from the center their middles are (a fraction
-- of half the banner's size), their size in world units, and their color (30% see-through)
-- How high the corner buttons sit above the banner's center (its faces are 0.2 above and below)
local CORNER_HEIGHT = 0.205
local CORNER_INSET = 0.80
local CORNER_SIZE = 0.8
local CORNER_COLOR = {1, 1, 1, 0.4}

-- Button sizes are in thousandths of 2 world units (on an object of scale 1)
local BUTTON_UNITS_PER_WORLD = 500

-- Frames to wait after something enters or leaves the banner before counting, so stacks have finished merging
local COUNT_DELAY = 5

-- Seconds to wait for something carried over the banner to be put down before counting anyway
local DROP_TIMEOUT = 10

-- Frames between pieces leaving the banner, and to wait after swapping a triple for singles
local MOVE_FRAMES = 18
local BREAK_FRAMES = 30

-- How high above its destination a piece is put (it falls the rest of the way)
local DROP_HEIGHT = 0.5

-- Where the Festival token sits on the banner: how far left of its center (a fraction of half its width), and how high
-- above its center it's set down before dropping onto it
local FESTIVAL_TOKEN_X = 0.5
local FESTIVAL_TOKEN_DROP = 1

-- Seconds to wait for a burned secret to reach the supply before removing it anyway
local BURN_TIMEOUT = 3

-- Where the Wandering Flame's challenge sends the secrets to be placed on sites (world position): a pile of singles
local SITE_SECRETS_SPOT = {x = -30, y = 1.23, z = 13.5}

-- "1 secret", "2 secrets"
local function secrets(n)
    return n .. (n == 1 and " secret" or " secrets")
end

-- Message colors
local INFO_COLOR = {1, 0.85, 0.25}
local ERROR_COLOR = {1, 0.3, 0.3}

-- This banner's entry in GUIDs.banners ({banner, zone, piece}), and its zone
local banner = nil
local zone = nil

-- What's on the banner, as last counted
local count = 0

-- Whether a count is already waiting to run, and what's being waited on to be put down (by GUID)
local countScheduled = false
local awaitingDrop = {}

-- Whether a resolution is running, and the pieces it has sent off the banner (by GUID), so they aren't taken again
-- while they're still gliding away
local busy = false
local leaving = {}

-- Run when the resolution started by a corner button has finished (moving the banner to whoever clicked it)
local afterResolution = nil

-- Whether the banner is being carried: its pieces go with it but its zone doesn't until it's put down, so the count
-- holds until then
local carried = false

-- bannerState.showCornerButtons: whether the challenge/campaign corner buttons are shown (toggled from the right-click
-- menu)
bannerState = {showCornerButtons = true}

function onSave()
    return JSON.encode(bannerState)
end

function onLoad(savedData)
    if savedData and savedData ~= "" then
        local success, saved = pcall(JSON.decode, savedData)
        if success and type(saved) == "table" then
            for key, value in pairs(saved) do
                bannerState[key] = value
            end
        end
    end
    for _, entry in pairs(GUIDs.banners) do
        if entry.banner == self.getGUID() then
            banner = entry
        end
    end
    if not banner then
        print(self.getName() .. " " .. self.getGUID() .. " isn't one of GUIDs.banners.")
        return
    end
    zone = getObjectFromGUID(banner.zone)
    if zone then
        zone = GiveZoneNotifier(zone, self)
        FitZone()
    else
        print("The " .. BannerName() .. "'s zone (" .. banner.zone .. ") is missing.")
    end
    CreateLabels()
    RefreshMenu()
    ScheduleCount()
end

function onPickUp()
    carried = true
end

-- When the banner is put down somewhere else, its zone follows it once it settles, and then it counts again
function onDrop()
    RefitWhenSettled()
end

-- Once the banner has come to rest, its zone is refitted over it and it counts again
function RefitWhenSettled()
    local function settled()
        if zone and not zone.isDestroyed() then
            FitZone()
        end
        carried = false
        ScheduleCount()
    end
    Wait.condition(settled, function()
        return self.resting and not self.isSmoothMoving()
    end, SETTLE_TIMEOUT, settled)
end

-- ==============================
-- PUBLIC API
-- ==============================

-- How much favor or how many secrets are on the banner (triples count 3)
function GetCount()
    return count
end

-- The GUIDs of the pieces on the banner, as a set (player mats leave these out of their counts)
function GetPieceGUIDs()
    local guids = {}
    for _, piece in ipairs(GetPieces()) do
        guids[piece.getGUID()] = true
    end
    return guids
end

-- ==============================
-- PIECES AND COUNT
-- ==============================

function BannerName()
    return banner and banner.piece == "Favor" and "People's Favor" or "Darkest Secret"
end

-- Whether the banner is flipped over (the Grand Council or Festival side up)
function IsFlipped()
    return self.getTransformUp().y < 0
end

-- The favor or secrets on the banner: in its zone, not being carried, and not already sent off by a resolution
function GetPieces()
    local pieces = {}
    if not banner or not zone or zone.isDestroyed() then
        return pieces
    end
    for _, object in ipairs(zone.getObjects()) do
        if not object.isDestroyed() and object.held_by_color == nil and object.hasTag(banner.piece)
            and not leaving[object.getGUID()] then
            table.insert(pieces, object)
        end
    end
    return pieces
end

-- Counts once things have settled. The zone calls this with the GUID of what entered or left: something carried
-- over the banner enters while it's held (and held pieces aren't counted), so it's counted again once it's down.
function ScheduleCount(guid)
    local object = guid and getObjectFromGUID(guid)
    if object and not awaitingDrop[guid] and (object.held_by_color ~= nil or not object.resting) then
        awaitingDrop[guid] = true
        local function dropped()
            awaitingDrop[guid] = nil
            ScheduleCount()
        end
        Wait.condition(dropped, function()
            return object.isDestroyed() or (object.held_by_color == nil and object.resting)
        end, DROP_TIMEOUT, dropped)
    end
    if countScheduled then
        return
    end
    countScheduled = true
    Wait.frames(function()
        countScheduled = false
        UpdateCount()
    end, COUNT_DELAY)
end

-- Counts what's on the banner and shows it. A player mat under the banner recounts too, as it leaves these out.
function UpdateCount()
    if carried then
        return
    end
    local total = 0
    for _, piece in ipairs(GetPieces()) do
        total = total + PieceValue(piece)
    end
    local changed = total ~= count
    count = total
    for index = 0, 1 do
        self.editButton({index = index, label = tostring(count)})
    end
    if changed then
        local mat = FindPlayerMatUnder(self)
        if mat then
            mat.call("ScheduleCount")
        end
    end
end

-- ==============================
-- LABELS
-- ==============================

-- Clicking a label does nothing
function IgnoreClick()
end

-- The count, on the center right of each face (button 0 on the front, 1 on the back). Button positions have x
-- flipped: the art's right is the banner's -x on the front and +x on the back.
function CreateLabels()
    self.clearButtons()
    local scale = self.getScale()
    for _, face in ipairs({{x = LABEL_X, y = LABEL_Y, rotation = {0, 0, 0}}, {x = -LABEL_X, y = -LABEL_Y, rotation = {0, 0, 180}}}) do
        self.createButton({
            click_function = "IgnoreClick",
            function_owner = self,
            label = tostring(count),
            position = {face.x, face.y, 0},
            rotation = face.rotation,
            scale = {1 / scale.x, 1, 1 / scale.z},
            width = 0,
            height = 0,
            font_size = LABEL_FONT_SIZE,
            font_color = LABEL_FONT_COLOR,
        })
    end
    if not bannerState.showCornerButtons then
        return
    end
    -- A small see-through button in two top corners of each face: challenge on the art's left, campaign on its right.
    -- On the front the art's right is -x (+x as a button position) and on the back +x; its top is -z on both.
    for _, face in ipairs({{right = 1, y = CORNER_HEIGHT, rotation = {0, 0, 0}}, {right = -1, y = -CORNER_HEIGHT, rotation = {0, 0, 180}}}) do
        for _, corner in ipairs({{side = -1, click = "CornerChallenge"}, {side = 1, click = "CornerCampaign"}}) do
            self.createButton({
                click_function = corner.click,
                function_owner = self,
                label = "",
                position = {face.right * corner.side * CORNER_INSET, face.y, -CORNER_INSET},
                rotation = face.rotation,
                scale = {1 / scale.x, 1, 1 / scale.z},
                width = CORNER_SIZE * BUTTON_UNITS_PER_WORLD,
                height = CORNER_SIZE * BUTTON_UNITS_PER_WORLD,
                color = CORNER_COLOR,
                tooltip = corner.side < 0 and "Resolve Challenge" or "Resolve Campaign",
            })
        end
    end
end

-- Runs resolve(playerColor), then, once it's done, moves the banner to playerColor's play area (MoveToPlayerArea)
local function resolveAndHandOver(playerColor, resolve)
    afterResolution = function()
        MoveToPlayerArea(playerColor)
    end
    resolve(playerColor)
end

-- The corner buttons: challenge and campaign on the Darkest Secret, both returning favor on the People's Favor. Once
-- that's done, the banner goes to whoever clicked.
function CornerChallenge(_, playerColor)
    resolveAndHandOver(playerColor, banner.piece == "Favor" and ReturnFavor or ResolveChallenge)
end

function CornerCampaign(_, playerColor)
    resolveAndHandOver(playerColor, banner.piece == "Favor" and ReturnFavor or ResolveCampaign)
end

-- ==============================
-- ZONE
-- ==============================

-- Fits the zone over the banner: its footprint, from the bottom of its bounding box to ZONE_HEADROOM above the top
function FitZone()
    local bounds, size = self.getBounds(), self.getBoundsNormalized().size
    local bottom = bounds.center.y - bounds.size.y / 2
    zone.setPosition({bounds.center.x, bottom + (size.y + ZONE_HEADROOM) / 2, bounds.center.z})
    zone.setRotation({0, self.getRotation().y, 0})
    zone.setScale({size.x, size.y + ZONE_HEADROOM, size.z})
end

-- ==============================
-- MENU
-- ==============================

function RefreshMenu()
    self.clearContextMenu()
    if banner.piece == "Favor" then
        self.addContextMenuItem("Return Favor", ReturnFavor)
    else
        self.addContextMenuItem("Resolve Challenge", MenuChallenge)
        self.addContextMenuItem("Resolve Campaign", MenuCampaign)
    end
    self.addContextMenuItem("Show/Hide Buttons", ToggleCornerButtons)
end

-- The Darkest Secret's right-click options: on the Festival side, like the corner buttons, the banner then goes to
-- whoever clicked; on the Wandering Flame side it stays put
function MenuChallenge(playerColor)
    if IsFlipped() then
        resolveAndHandOver(playerColor, ResolveChallenge)
    else
        ResolveChallenge(playerColor)
    end
end

function MenuCampaign(playerColor)
    if IsFlipped() then
        resolveAndHandOver(playerColor, ResolveCampaign)
    else
        ResolveCampaign(playerColor)
    end
end

function ToggleCornerButtons()
    bannerState.showCornerButtons = not bannerState.showCornerButtons
    CreateLabels()
end

-- Starts a resolution, unless one is running or there's nothing on the banner. Returns what's on it, or nil.
function BeginResolution(playerColor)
    if busy then
        Player[playerColor].broadcast("The " .. BannerName() .. " is already being resolved.")
        afterResolution = nil
        return nil
    end
    UpdateCount()
    if count <= 0 then
        -- nothing to resolve, but a corner button still hands the banner over
        if afterResolution then
            RunAfterResolution()
        else
            Player[playerColor].broadcast("There's nothing on the " .. BannerName() .. ".")
        end
        return nil
    end
    busy = true
    leaving = {}
    return count
end

function FinishResolution()
    busy = false
    leaving = {}
    ScheduleCount()
    RunAfterResolution()
end

function RunAfterResolution()
    local after = afterResolution
    afterResolution = nil
    if after then
        after()
    end
end

-- ==============================
-- HANDING THE BANNER OVER
-- ==============================

-- The mat in front of playerColor's seat, if they're seated (their hand is at the table) and a player board is on it
function SeatMatWithBoard(playerColor)
    local player = Player[playerColor]
    if not player or not player.seated then
        return nil
    end
    local mat = nil
    for _, hand in ipairs(Hands.getHands()) do
        if hand.getValue() == playerColor then
            for i, handGUID in ipairs(GUIDs.handZones) do
                if handGUID == hand.getGUID() then
                    mat = getObjectFromGUID(GUIDs.playerMats[i])
                end
            end
        end
    end
    if not mat then
        return nil
    end
    local bounds = mat.getBounds()
    for _, board in ipairs(getObjectsWithTag("PlayerBoard")) do
        local position = board.getPosition()
        if math.abs(position.x - bounds.center.x) <= bounds.size.x / 2
            and math.abs(position.z - bounds.center.z) <= bounds.size.z / 2 then
            return mat
        end
    end
    return nil
end

-- Moves the banner, and anything loose sitting on it (what's left of its pieces, the Festival token), onto a banner
-- spot in playerColor's play area (pos.banner on their mat: the left one, or the right if the other banner is on the
-- left), the same side up. Only if they're seated and their seat's mat has a player board.
function MoveToPlayerArea(playerColor)
    local mat = SeatMatWithBoard(playerColor)
    if not mat then
        Player[playerColor].broadcast("The " .. BannerName() .. " stays put: you need to be seated, with a player board on "
            .. "your mat, to take it.")
        return
    end
    -- the left spot, unless the other banner is lying on it (within half a banner's width): then the right one
    local target = getTransformStruct("banner", 1, {position = mat.getPosition()})
    local reach = self.getBoundsNormalized().size.x / 2
    for _, entry in pairs(GUIDs.banners) do
        local other = entry.banner ~= self.getGUID() and getObjectFromGUID(entry.banner)
        if other then
            local position = other.getPosition()
            if math.abs(position.x - target.position.x) < reach and math.abs(position.z - target.position.z) < reach then
                target = getTransformStruct("banner", 2, {position = mat.getPosition()})
                break
            end
        end
    end
    local from = self.getPosition()
    local offset = Vector(target.position.x - from.x, target.position.y - from.y, target.position.z - from.z)

    -- what rides along: loose things in the banner's zone above it (a scripted move doesn't carry them)
    local riders = {}
    for _, object in ipairs(zone and not zone.isDestroyed() and zone.getObjects() or {}) do
        if not object.isDestroyed() and object.getGUID() ~= self.getGUID() and not object.getLock()
            and object.held_by_color == nil
            and object.getPosition().y > from.y then
            table.insert(riders, object)
        end
    end

    -- the count holds while it moves, and its zone follows once it's down
    carried = true
    local rotation = self.getRotation()
    self.setRotationSmooth({rotation.x, target.rotation.y, rotation.z}, false, false)
    self.setPositionSmooth(from + offset, false, false)
    for _, rider in ipairs(riders) do
        rider.setPositionSmooth(rider.getPosition() + offset + Vector(0, 0.3, 0), false, false)
    end
    RefitWhenSettled()
end

-- ==============================
-- MOVING PIECES
-- ==============================

-- The single to take next (a stack's pieces are taken one at a time). If only triples are left, a triple comes back
-- second instead, to be broken up.
local function pickPiece()
    local single, triple = nil, nil
    for _, piece in ipairs(GetPieces()) do
        if piece.hasTag("Triple") then
            triple = triple or piece
        else
            single = single or piece
        end
    end
    if single then
        return single, nil
    end
    return nil, triple
end

-- Sends amount off the banner, one single at a time. destinationFor(index) gives where piece index (from 0) goes;
-- onSent(piece, value), if given, hears about each. Calls done(moved).
function SendValue(amount, destinationFor, onSent, done)
    local moved, index = 0, 0
    local function step()
        if moved >= amount then
            Wait.frames(function()
                done(moved)
            end, 2)
            return
        end
        local piece, onlyTriple = pickPiece()
        if not piece and onlyTriple then
            -- only triples left: swap one for three singles from the supply, dropped onto the banner, and go again
            local supply = getObjectFromGUID(GUIDs.supplies[banner.piece] or "")
            if not supply then
                broadcastToAll("The " .. banner.piece .. " supply is missing, so a triple can't be broken up.", ERROR_COLOR)
                done(moved)
                return
            end
            if onlyTriple.getQuantity() > 1 then
                onlyTriple.takeObject({
                    position = onlyTriple.getPosition() + Vector(0, 3, 0),
                    smooth = false,
                    callback_function = function(taken)
                        taken.destruct()
                    end,
                })
            else
                onlyTriple.destruct()
            end
            local center = self.getPosition()
            for i = 1, 3 do
                supply.takeObject({position = center + Vector((i - 2) * 0.8, 2 + i * 0.3, 0), smooth = false})
            end
            Wait.frames(step, BREAK_FRAMES)
            return
        end
        if not piece then
            broadcastToAll("The " .. BannerName() .. " ran out after " .. moved .. " of " .. amount .. ".", ERROR_COLOR)
            done(moved)
            return
        end
        -- it glides there (one from the top, if it's a stack), but nothing waits for it to arrive (takeObject's callback
        -- would only come once it had): the destination is a little above where it should end up, so it drops the rest
        -- of the way
        local destination = destinationFor(index)
        if piece.getQuantity() > 1 then
            piece = piece.takeObject({position = destination, smooth = true})
        else
            piece.setPositionSmooth(destination, false, false)
        end
        leaving[piece.getGUID()] = true
        local value = PieceValue(piece)
        index = index + 1
        moved = moved + value
        if onSent then
            onSent(piece, value)
        end
        Wait.frames(step, MOVE_FRAMES)
    end
    step()
end

-- ==============================
-- DESTINATIONS
-- ==============================

-- The world direction of the art's right on the side that's up (its -x face up, its +x flipped over)
local function artRight()
    local right = self.getTransformRight()
    return IsFlipped() and right or right * -1
end

-- Where piece index of the previous holder's pieces goes: the layout spot (pos.playerSecret or pos.playerBank) on the
-- mat the banner is on, each a little above the last so they stack. Only used while the banner is on a mat
-- (GiveBackToHolder burns them otherwise); off one, just above the banner.
local function holderSpot(layout, index)
    local mat = FindPlayerMatUnder(self)
    local spot = mat and getTransformStruct(layout, 1, {position = mat.getPosition()}).position or self.getPosition()
    return Vector(spot.x, spot.y + DROP_HEIGHT + index * 0.25, spot.z)
end

local function holderSecretSpot(index)
    return holderSpot("playerSecret", index)
end

-- ==============================
-- PEOPLE'S FAVOR
-- ==============================

-- Mob: everything to the poorest banks. Grand Council: half (rounded down) to the previous holder's favor spot
-- (burned if nobody held it), then the rest to the banks.
function ReturnFavor(playerColor)
    local total = BeginResolution(playerColor)
    if not total then
        return
    end
    local board = getObjectFromGUID(GUIDs.map)
    local banks = board and board.call("GetBanks") or {}
    if #banks == 0 then
        broadcastToAll("The favor banks couldn't be found on the game board.", ERROR_COLOR)
        FinishResolution()
        return
    end
    local toHolder = IsFlipped() and math.floor(total / 2) or 0
    local toBanks = total - toHolder
    -- the previous holder's share goes to their favor spot (pos.playerBank, where a withdraw puts it)
    GiveBackToHolder(toHolder, function(index)
        return holderSpot("playerBank", index)
    end, function(heldBack, burned)
        -- the rest one at a time, each to the bank with the least (the leftmost of those tied), dropped onto its snap point
        local added, target = {}, nil
        SendValue(toBanks, function()
            target = banks[1]
            for i = 2, #banks do
                if banks[i].count < target.count then
                    target = banks[i]
                end
            end
            return Vector(target.x, target.y + DROP_HEIGHT, target.z)
        end, function(_, value)
            target.count = target.count + value
            added[target.suit] = (added[target.suit] or 0) + value
        end, function(returned)
            local perBank = {}
            for _, bank in ipairs(banks) do
                if added[bank.suit] then
                    table.insert(perBank, "+" .. added[bank.suit] .. " to " .. bank.suit)
                end
            end
            if #perBank > 0 then
                broadcastToAll(table.concat(perBank, "\n"), INFO_COLOR)
            end
            local lines = {}
            if heldBack > 0 and burned then
                table.insert(lines, "Nobody held the People's Favor, so the previous holder's " .. heldBack .. " favor burned.")
            elseif heldBack > 0 then
                table.insert(lines, heldBack .. " favor returned to the previous holder.")
            end
            table.insert(lines, returned .. " favor returned to the poorest favor banks.")
            table.insert(lines, "If taken via Challenge, the new holder must place at least " .. (total + 1)
                .. " favor on the People's Favor.")
            broadcastToAll(table.concat(lines, "\n"), INFO_COLOR)
            FinishResolution()
        end)
    end)
end

-- ==============================
-- DARKEST SECRET
-- ==============================

-- Burns amount favor or secrets (they glide to their supply and are removed), then calls done(burned)
function Burn(amount, done)
    -- each glides to just above its supply
    local supply = getObjectFromGUID(GUIDs.supplies[banner.piece] or "")
    local above = (supply and supply.getPosition() or self.getPosition()) + Vector(0, 2, 0)
    SendValue(amount, function()
        return above
    end, function(piece)
        -- removed once it has glided over to the supply
        Wait.condition(function()
            if not piece.isDestroyed() then
                piece.destruct()
            end
        end, function()
            return piece.isDestroyed() or not piece.isSmoothMoving()
        end, BURN_TIMEOUT)
    end, done)
end

-- Gives amount back to the previous holder (piece index goes to spotFor(index)), or burns it if nobody held the banner
-- (it isn't on a player's mat). Calls done(amount sent, whether it was burned).
function GiveBackToHolder(amount, spotFor, done)
    if FindPlayerMatUnder(self) then
        SendValue(amount, spotFor, nil, function(given)
            done(given, false)
        end)
    else
        Burn(amount, function(burned)
            done(burned, true)
        end)
    end
end

-- Puts the Festival token on top of the banner, on the left of its art (clear of the count on the right), so it
-- goes wherever the banner goes
function MoveFestivalToken()
    local token = getObjectFromGUID(GUIDs.festivalToken)
    if not token then
        broadcastToAll("The Festival token (" .. GUIDs.festivalToken .. ") is missing.", ERROR_COLOR)
        return
    end
    local half = self.getBoundsNormalized().size.x / 2
    local spot = self.getPosition() + artRight() * (-half * FESTIVAL_TOKEN_X) + Vector(0, FESTIVAL_TOKEN_DROP, 0)
    token.setPositionSmooth(spot, false, false)
end

-- Wandering Flame: half (rounded down) to SITE_SECRETS_SPOT as singles, for placing on sites, the rest to the previous
-- holder's secret spot (or burned, if nobody held it: it isn't on a player's mat). Festival: the Festival
-- token goes on top of the banner, one secret is burned, and the rest go to the previous holder's secret spot (or are
-- burned too, if nobody held it).
function ResolveChallenge(playerColor)
    local total = BeginResolution(playerColor)
    if not total then
        return
    end
    local function finish(sideName, text)
        broadcastToAll(sideName .. " challenge resolved. " .. text .. "\nThe new holder must place at least "
            .. (total + 1) .. " secrets on the Darkest Secret.", INFO_COLOR)
        FinishResolution()
    end
    if IsFlipped() then
        MoveFestivalToken()
        Burn(math.min(1, total), function(burned)
            GiveBackToHolder(total - burned, holderSecretSpot, function(toHolder, alsoBurned)
                if alsoBurned then
                    finish("Festival", "Nobody held the Darkest Secret, so all " .. secrets(burned + toHolder) .. " burned.")
                else
                    finish("Festival", secrets(burned) .. " burned. " .. toHolder .. " set aside for the previous holder.")
                end
            end)
        end)
        return
    end
    local toSites = math.floor(total / 2)
    SendValue(toSites, function(index)
        return Vector(SITE_SECRETS_SPOT.x, SITE_SECRETS_SPOT.y + DROP_HEIGHT + index * 0.25, SITE_SECRETS_SPOT.z)
    end, nil, function(forSites)
        GiveBackToHolder(total - forSites, holderSecretSpot, function(toHolder, burned)
            local rest = burned and ("Nobody held the Darkest Secret, so the other " .. toHolder .. " burned.")
                or (toHolder .. " set aside for the previous holder.")
            finish("Wandering Flame", secrets(forSites) .. " set aside for placing on sites. " .. rest)
        end)
    end)
end

-- Wandering Flame: all of them burned. Festival: the Festival token goes on top of the banner and half (rounded down)
-- are burned; the rest stay.
function ResolveCampaign(playerColor)
    local total = BeginResolution(playerColor)
    if not total then
        return
    end
    if IsFlipped() then
        MoveFestivalToken()
        Burn(math.floor(total / 2), function(burned)
            broadcastToAll("Festival campaign resolved: " .. secrets(burned) .. " burned, " .. (total - burned)
                .. " left on the banner.", INFO_COLOR)
            FinishResolution()
        end)
        return
    end
    Burn(total, function(burned)
        broadcastToAll("Wandering Flame campaign resolved: " .. secrets(burned) .. " burned.", INFO_COLOR)
        FinishResolution()
    end)
end
