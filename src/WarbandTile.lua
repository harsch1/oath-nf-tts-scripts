-- ==============================
-- OATH WARBAND TRAY / PHYSICAL WARBAND BANK
--
-- Used by each lineage's warband tray, and by the one shared
-- Chancellor tray (memo "Purple"). Each is a bank: it arranges,
-- counts, stores and recovers its warbands.
--
-- A lineage tray is the bank while its player is an Exile. As a
-- Citizen or the Chancellor it stores its warbands in the
-- player's archive and hides; the Chancellor's lineage tray
-- brings the shared Chancellor tray out onto its spot.
-- ==============================

require("src/Config/GeneralConfig")
require("src/Utils/ColorUtils")
require("src/Utils/HelperFunctions")
require("src/Utils/Warbands")

-- The name spawned warbands get (just for show: a warband is recognised by its tag and the color in its memo)
local WARBAND_NAME = "Warband"

-- The area (in tile units) that counts as "on the tray", padded around the bank slots.
local TRAY_BOUNDS = {
    minX = -5,
    maxX = 5,
    minZ = -4,
    maxZ = 4,
}

-- Where wrong-colored warbands are pushed off the tray to (tile x)
local EJECT_X = -12.914

-- ==============================
-- STATE
-- ==============================

local lineageColor = nil
local currentRole = nil

local initialized = false
local repackScheduled = false
local roleChangeBusy = false

-- True for the shared Chancellor tray (memo "Purple"), which is always the Purple bank
local isChancellorTray = false

-- ==============================
-- SAVE
-- ==============================

function onSave()
    return JSON.encode({
        currentRole = currentRole,
    })
end

-- ==============================
-- LOAD
-- ==============================

function onLoad(savedData)
    if not self.hasTag(tags.warbandTray) then
        self.addTag(tags.warbandTray)
    end

    local memoColor = trim(self.memo or "")
    if GetOathColor(memoColor) then
        lineageColor = memoColor
        isChancellorTray = memoColor == "Purple"
    else
        print(self.getName() .. " has no lineage color in its memo (expected e.g. \"Red\"); it won't run its bank.")
    end
    
    if savedData and savedData ~= "" then
        local success, saved = pcall(JSON.decode, savedData)
        if success and saved then
            if saved.currentRole then
                currentRole = saved.currentRole
            end
        end
    end
    if isChancellorTray then
        currentRole = "CHANCELLOR"
    end

    -- LOAD RECONCILIATION
    --
    -- The lineage bag is also the player's archive. While the
    -- Bookshelf is withdrawing a player from it, the archive has
    -- "withdrawing" set: wait until the Bookshelf has pushed all
    -- the warbands out before verifying totals and repacking.
    local function reconcileOnLoad()
        local bag = GetLineageBag()
        -- also wait to land: a Chancellor's tray brings the Chancellor tray out next to itself
        if (bag and bag.getVar("withdrawing")) or self.isSmoothMoving() then
            Wait.frames(reconcileOnLoad, 12)
            return
        end
        initialized = true
        if isChancellorTray then
            UpdateVisibility()
            VerifyPurpleTotal()
            ScheduleRepack()
            return
        end
        Wait.frames(function()
            ReconcileStorageForCurrentRole(function()
                VerifyOwnLineageTotal()
                ScheduleRepack()
            end)
        end, 4)
    end
    Wait.frames(reconcileOnLoad, 12)
end

-- ==============================
-- PUBLIC API
-- ==============================

function GetTrayColor()
    return lineageColor
end

function GetMode()
    return currentRole
end

-- True while a role change is still storing, swapping or recovering warbands (the storage box waits on this)
function IsBusy()
    return roleChangeBusy
end

-- The warbands in this tray's bank (used to store the Chancellor tray's bank)
function GetBankPieces()
    local color = GetActiveTrayColor()
    return color and GetBankPiecesOnThisTray(color) or {}
end

-- ==============================
-- SUPPLY API
-- ==============================

function GetBankCount()
    if isChancellorTray then
        return CountBankPiecesOnThisTray("Purple")
    end
    if currentRole == "EXILE" then
        return CountBankPiecesOnThisTray(lineageColor)
    end
    -- Citizens and the Chancellor use the shared Chancellor tray's bank
    local chancellor = FindChancellorTray()
    if chancellor then
        return chancellor.call("GetBankCount")
    end
    return 0
end

-- ==============================
-- APPLY ROLE
-- ==============================

function ApplyRole(newRole)
    -- Called by whatever changes the player's role (player board, storage bag), e.g.
    -- tile.call("ApplyRole", "CITIZEN"). The bank stores, swaps and recovers warbands, then packs for that role.
    if type(newRole) == "table" then
        newRole = newRole.role or newRole[1]
    end
    newRole = newRole and string.upper(tostring(newRole))
    if newRole ~= "EXILE" and newRole ~= "CITIZEN" and newRole ~= "CHANCELLOR" then
        return
    end
    -- The shared Chancellor tray is always the Chancellor's bank
    if isChancellorTray or not lineageColor or roleChangeBusy then
        return
    end
    if currentRole == newRole then
        -- Ensure the tray is shown or hidden correctly after
        -- reloads or manual state reconciliation.
        UpdateVisibility()
        return
    end
    roleChangeBusy = true
    local oldRole = currentRole

    -- EXILE -> CITIZEN / CHANCELLOR
    if newRole == "CITIZEN" or newRole == "CHANCELLOR" then
        if oldRole ~= "CITIZEN" and oldRole ~= "CHANCELLOR" then
            ConvertLineageMatWarbandsToPurple(function()
                StoreAllLineageBankInBag(function()
                    FinishBecomeImperial(newRole)
                end)
            end)
            return
        end

        -- CHANCELLOR -> CITIZEN
        if oldRole == "CHANCELLOR" and newRole == "CITIZEN" then
            StoreAllLineageBankInBag(function()
                FinishBecomeImperial("CITIZEN", true)
            end)
            return
        end

        -- CITIZEN -> CHANCELLOR
        if oldRole == "CITIZEN" and newRole == "CHANCELLOR" then
            StoreAllLineageBankInBag(function()
                FinishBecomeImperial("CHANCELLOR")
            end)
            return
        end
        roleChangeBusy = false
        return
    end

    -- CITIZEN / CHANCELLOR -> EXILE
    if newRole == "EXILE" then
        if oldRole == "CHANCELLOR" then
            ConvertPurpleMatWarbandsToLineage(function()
                ReturnChancellorTray(function()
                    FinishBecomeExile()
                end)
            end)
        elseif oldRole == "CITIZEN" then
            ConvertPurpleMatWarbandsToLineage(function()
                FinishBecomeExile()
            end)
        else
            FinishBecomeExile()
        end
        return
    end
    roleChangeBusy = false
end

-- ==============================
-- FINISH IMPERIAL
-- ==============================

-- wasChancellor: this player was the Chancellor until now, so the shared tray goes back
function FinishBecomeImperial(newRole, wasChancellor)
    currentRole = newRole
    UpdateVisibility()
    VerifyOwnLineageTotal()
    local function finished()
        roleChangeBusy = false
    end
    if newRole == "CHANCELLOR" then
        BringOutChancellorTray(finished)
    elseif wasChancellor then
        -- Citizens have no tray; a Chancellor turning Citizen sends the shared tray back
        ReturnChancellorTray(finished)
    else
        finished()
    end
end

-- ==============================
-- FINISH EXILE
-- ==============================

function FinishBecomeExile()
    currentRole = "EXILE"
    UpdateVisibility()
    RecoverLineageBank(function()
        VerifyOwnLineageTotal()
        RepackTray()
        roleChangeBusy = false
    end)
end

-- ==============================
-- LOAD / SAVE RECONCILIATION
-- ==============================

function ReconcileStorageForCurrentRole(finishedCallback)
    -- EXILE
    if currentRole == "EXILE" then
        UpdateVisibility()
        if finishedCallback then
            finishedCallback()
        end
        return
    end

    -- CITIZEN
    if currentRole == "CITIZEN" then
        StoreAllLineageBankInBag(function()
            UpdateVisibility()
            if finishedCallback then
                finishedCallback()
            end
        end)
        return
    end

    -- CHANCELLOR
    if currentRole == "CHANCELLOR" then
        StoreAllLineageBankInBag(function()
            UpdateVisibility()
            if not FindChancellorTray() then
                BringOutChancellorTray()
            end
            if finishedCallback then
                finishedCallback()
            end
        end)
        return
    end
    if finishedCallback then
        finishedCallback()
    end
end

-- ==============================
-- EXILE -> PURPLE MAT SWAP
-- ==============================

function ConvertLineageMatWarbandsToPurple(finishedCallback)
    local playerMat = FindMyPlayerMat()
    if not playerMat then
        if finishedCallback then
            finishedCallback()
        end
        return
    end
    local pieces = FindLooseMatWarbands(playerMat, lineageColor)
    ConvertLineageToPurpleStep(pieces, 1, finishedCallback)
end

function ConvertLineageToPurpleStep(pieces, index, finishedCallback)
    if index > #pieces then
        if finishedCallback then
            Wait.frames(finishedCallback, 2)
        end
        return
    end
    local lineagePiece = pieces[index]
    if not isValidObject(lineagePiece) then
        ConvertLineageToPurpleStep(pieces, index + 1, finishedCallback)
        return
    end
    local targetPosition = lineagePiece.getPosition()
    local targetRotation = lineagePiece.getRotation()
    PutLineageObjectInBag(lineagePiece)
    WithdrawPurpleBankPiece(function(replacement)
        if replacement and isValidObject(replacement) then
            replacement.setPosition(targetPosition)
            replacement.setRotation(targetRotation)
        end
        Wait.frames(function()
            ConvertLineageToPurpleStep(pieces, index + 1, finishedCallback)
        end, 1)
    end)
end

-- ==============================
-- PURPLE -> EXILE MAT SWAP
-- ==============================

function ConvertPurpleMatWarbandsToLineage(finishedCallback)
    local playerMat = FindMyPlayerMat()
    if not playerMat then
        if finishedCallback then
            finishedCallback()
        end
        return
    end
    local pieces = FindLooseMatWarbands(playerMat, "Purple")
    ConvertPurpleToLineageStep(pieces, 1, finishedCallback)
end

function ConvertPurpleToLineageStep(pieces, index, finishedCallback)
    if index > #pieces then
        if finishedCallback then
            Wait.frames(finishedCallback, 2)
        end
        return
    end
    local purplePiece = pieces[index]
    if not isValidObject(purplePiece) then
        ConvertPurpleToLineageStep(pieces, index + 1, finishedCallback)
        return
    end
    local targetPosition = purplePiece.getPosition()
    local targetRotation = purplePiece.getRotation()
    ReturnPurpleObjectToBank(purplePiece)
    WithdrawOneLineageFromBag(function(replacement)
        if replacement and isValidObject(replacement) then
            replacement.setPosition(targetPosition)
            replacement.setRotation(targetRotation)
        end
        Wait.frames(function()
            ConvertPurpleToLineageStep(pieces, index + 1, finishedCallback)
        end, 1)
    end)
end

-- ==============================
-- LINEAGE BAG
-- ==============================

function GetLineageBag()
    local guid = GUIDs.playerArchives[lineageColor]
    if not guid then
        return nil
    end
    return getObjectFromGUID(guid)
end

-- ==============================
-- PUT INTO A PLAYER ARCHIVE
--
-- Lineage and Purple reserve bags are the player archives,
-- whose tryObjectEnter refuses everything unless their
-- allowEnter is set. Open the bag just for this put.
-- Requests are counted on the bag so trays sharing a bag
-- don't close it on each other.
-- ==============================

function PutObjectInArchive(bag, object)
    bag.setVar("enterRequests", (bag.getVar("enterRequests") or 0) + 1)
    bag.setVar("allowEnter", true)
    bag.putObject(object)
    Wait.frames(function()
        if not bag or bag.isDestroyed() then
            return
        end
        local remaining = (bag.getVar("enterRequests") or 1) - 1
        bag.setVar("enterRequests", remaining)
        if remaining <= 0 then
            bag.setVar("allowEnter", false)
        end
    end, 2)
end

function PutLineageObjectInBag(object)
    local bag = GetLineageBag()
    if not bag or not isValidObject(object) then
        return false
    end
    if object.hasTag(tags.warbandBank) then
        object.removeTag(tags.warbandBank)
    end
    PutObjectInArchive(bag, object)
    return true
end

-- ==============================
-- STORE ALL LINEAGE BANK PIECES
-- ==============================

function StoreAllLineageBankInBag(finishedCallback)
    local bag = GetLineageBag()
    if not bag then
        if finishedCallback then
            finishedCallback()
        end
        return
    end
    local pieces = GetBankPiecesOnTable(lineageColor)
    StoreObjectsInBagStep(pieces, 1, bag, finishedCallback)
end

function StoreObjectsInBagStep(pieces, index, bag, finishedCallback)
    if index > #pieces then
        if finishedCallback then
            Wait.frames(finishedCallback, 2)
        end
        return
    end
    local object = pieces[index]
    if not isValidObject(object) then
        StoreObjectsInBagStep(pieces, index + 1, bag, finishedCallback)
        return
    end
    if object.hasTag(tags.warbandBank) then
        object.removeTag(tags.warbandBank)
    end
    PutObjectInArchive(bag, object)
    Wait.frames(function()
        StoreObjectsInBagStep(pieces, index + 1, bag, finishedCallback)
    end, 1)
end

-- ==============================
-- WITHDRAW ONE LINEAGE
-- ==============================

function WithdrawOneLineageFromBag(callback)
    local bag = GetLineageBag()
    if not bag then
        callback(nil)
        return
    end
    local entries = GetContainedWarbandEntries(bag)
    if #entries == 0 then
        callback(nil)
        return
    end
    bag.takeObject({
        guid = entries[1].guid,
        position = self.getPosition() + Vector(0, 3, 0),
        smooth = false,
        callback_function = function(object)
            if isValidObject(object) then
                if object.hasTag(tags.warbandBank) then
                    object.removeTag(tags.warbandBank)
                end
                if not object.hasTag(tags.warband) then
                    object.addTag(tags.warband)
                end
            end
            callback(object)
        end,
    })
end

-- ==============================
-- PURPLE RESERVE BAG
-- ==============================

function GetPurpleReserveBag()
    return getObjectFromGUID(GUIDs.playerArchives.Purple)
end

-- ==============================
-- WITHDRAW PURPLE
-- ==============================

function WithdrawPurpleBankPiece(callback)
    local chancellor = FindChancellorTray()
    if chancellor then
        local object = chancellor.call("WithdrawPurpleFromTray")
        if object and isValidObject(object) then
            callback(object)
            return
        end
    end
    local bag = GetPurpleReserveBag()
    if not bag then
        callback(nil)
        return
    end
    local entries = GetContainedWarbandEntries(bag)
    if #entries == 0 then
        callback(nil)
        return
    end
    bag.takeObject({
        guid = entries[1].guid,
        position = self.getPosition() + Vector(0, 3, 0),
        smooth = false,
        callback_function = function(object)
            if isValidObject(object) then
                if object.hasTag(tags.warbandBank) then
                    object.removeTag(tags.warbandBank)
                end
                if not object.hasTag(tags.warband) then
                    object.addTag(tags.warband)
                end
            end
            callback(object)
        end,
    })
end

-- ==============================
-- MUSTER BUTTON
-- ==============================

-- Where the button sits, in the tile's own units: off its bottom right corner (from the seat). The tile lies like the
-- mat: the seat's right is +x for a button (button positions have x flipped) and the edge nearest the seat is +z.
local MUSTER_BUTTON_POSITION = {1.40, 0.1, 1.15}

-- The Chancellor tray's art is laid out differently, so its button sits further right and down
local CHANCELLOR_MUSTER_BUTTON_POSITION = {1.8, 0.1, 1.29}

-- The button's size and its "+", in the tile's own units (they grow with the tile's scale)
local MUSTER_BUTTON_SIZE = 240
local MUSTER_FONT_SIZE = 195

-- Button colors that differ from the player's Oath color, to match their board
local MUSTER_BUTTON_COLORS = {
    Black = "5D7F96",
    Purple = "926183",
}

-- The muster button: moves one warband from this tray's bank to the mat's next free warband spot, set out the way a
-- Citizen's are (NextWarbandSpot). A right-click (altClick) brings one of this tray's warbands on the mat back into its
-- bank instead: the one set out last on the mat's warband spots, or if there's none there, the nearest one lying loose
-- (not in a bank and not being carried) anywhere else on the mat.
function MusterOneWarband(_, playerColor, altClick)
    local color = GetActiveTrayColor()
    if altClick then
        local mat = FindPlayerMatUnder(self)
        local warband = color and mat and LastWarbandOnSpots(mat, color)
        if color and mat and not warband then
            local bounds = mat.getBounds()
            local trayPosition = self.getPosition()
            local nearestDistance = math.huge
            for _, object in ipairs(getObjectsWithTag(tags.warband)) do
                if isValidObject(object) and not object.hasTag(tags.warbandBank) and not isHeld(object)
                    and GetWarbandObjectColor(object) == color then
                    local position = object.getPosition()
                    local onMat = math.abs(position.x - bounds.center.x) <= bounds.size.x / 2
                        and math.abs(position.z - bounds.center.z) <= bounds.size.z / 2
                    local distance = (position.x - trayPosition.x) ^ 2 + (position.z - trayPosition.z) ^ 2
                    if onMat and distance < nearestDistance then
                        warband, nearestDistance = object, distance
                    end
                end
            end
        end
        if not warband then
            Player[playerColor].broadcast("There are no " .. (color or "") .. " warbands on the mat to bring back to the tray.")
            return
        end
        -- a bank piece off the tray glides into its slot when the tray repacks
        warband.addTag(tags.warbandBank)
        ScheduleRepack()
        return
    end
    local pieces = color and GetBankPiecesOnThisTray(color) or {}
    if #pieces == 0 then
        Player[playerColor].broadcast("There are no warbands on this tray to muster.")
        return
    end
    local mat = FindPlayerMatUnder(self)
    local spot = mat and NextWarbandSpot(mat)
    if not spot then
        Player[playerColor].broadcast("There's no free warband spot on the mat.")
        return
    end
    local object = pieces[#pieces]
    object.removeTag(tags.warbandBank)
    object.setRotationSmooth({0, 0, 0}, false, false)
    object.setPositionSmooth(spot, false, false)
    ScheduleRepack()
end

function WithdrawPurpleFromTray()
    if not isChancellorTray then
        return nil
    end
    local pieces = GetBankPiecesOnThisTray("Purple")
    if #pieces == 0 then
        return nil
    end
    local object = pieces[#pieces]
    object.removeTag(tags.warbandBank)
    ScheduleRepack()
    return object
end

-- ==============================
-- RETURN PURPLE
-- ==============================

-- Hands a Purple warband to this player's storage box, which sends it to the Chancellor tray or archive
function ReturnPurpleObjectToBank(object)
    local box = getObjectFromGUID(GUIDs.storageBags[lineageColor] or "")
    if not box or not isValidObject(object) or GetWarbandObjectColor(object) ~= "Purple" then
        return false
    end
    return box.call("RouteWarband", object)
end

-- ==============================
-- CONTAINED WARBAND ENTRIES
-- ==============================

function GetContainedWarbandEntries(bag)
    local result = {}
    if not bag or bag.isDestroyed() then
        return result
    end
    for _, entry in ipairs(bag.getObjects()) do
        if BagEntryHasTag(entry, tags.warband) then
            table.insert(result, entry)
        end
    end
    return result
end

-- ==============================
-- ACCEPT WARBAND
--
-- Storage boxes decide where a warband belongs and hand it
-- to the tray banking its color.
-- ==============================

-- Takes a warband into this tray's bank. Returns false if this tray isn't banking that warband's color right now.
function AcceptWarband(object)
    local color = GetActiveTrayColor()
    if not color or not isValidObject(object) or GetWarbandObjectColor(object) ~= color then
        return false
    end
    object.setVelocity({0, 0, 0})
    object.setAngularVelocity({0, 0, 0})
    object.addTag(tags.warbandBank)
    object.setPosition(TrayOrigin() + Vector(0, 2, 0))
    ScheduleRepack()
    return true
end

-- ==============================
-- PICKUP
-- ==============================

local pendingPickups = {}
local pickupScheduled = false

function onObjectPickUp(playerColor, object)
    local activeColor = GetActiveTrayColor()
    if not activeColor or not initialized or not isValidObject(object) or not object.hasTag(tags.warbandBank) then
        return
    end
    if GetWarbandObjectColor(object) ~= activeColor then
        return
    end
    if not isInTrayBounds(object) then
        return
    end
    object.removeTag(tags.warbandBank)
    pendingPickups[object.getGUID()] = true
    if pickupScheduled then
        return
    end
    pickupScheduled = true
    Wait.frames(function()
        StabilizeActiveBank()
        RepackTray()
        pendingPickups = {}
        pickupScheduled = false
    end, 2)
end

-- ==============================
-- DROP
-- ==============================

local dropScheduled = false

function onObjectDrop(playerColor, object)
    local activeColor = GetActiveTrayColor()
    if
        not activeColor
        or not initialized
        or not isValidObject(object)
        or GetWarbandObjectColor(object) == nil
    then
        return
    end
    if not isInTrayBounds(object) then
        return
    end
    local objectColor = GetWarbandObjectColor(object)
    if objectColor ~= activeColor then
        if object.hasTag(tags.warbandBank) then
            object.removeTag(tags.warbandBank)
        end
        EjectWrongColor(object)
        return
    end
    if not object.hasTag(tags.warbandBank) then
        object.addTag(tags.warbandBank)
    end
    if not dropScheduled then
        dropScheduled = true
        Wait.time(function()
            if not GetActiveTrayColor() then
                dropScheduled = false
                return
            end
            StabilizeActiveBank()
            RepackTray()
            if activeColor == "Purple" then
                VerifyPurpleTotal()
            else
                VerifyOwnLineageTotal()
            end
            dropScheduled = false
        end, 0.3)
    end
end

-- ==============================
-- ACTIVE COLOR
-- ==============================

function GetActiveTrayColor()
    -- The shared Chancellor tray is the Purple bank; a lineage tray is only a bank while Exile
    if isChancellorTray then
        return "Purple"
    end
    if currentRole == "EXILE" then
        return lineageColor
    end
    return nil
end

-- ==============================
-- STABILIZE ACTIVE BANK
-- ==============================

function StabilizeActiveBank()
    local activeColor = GetActiveTrayColor()
    if not activeColor then
        return
    end
    for _, object in ipairs(GetBankPiecesOnThisTray(activeColor)) do
        if isValidObject(object) and not isHeld(object) then
            object.setVelocity({0, 0, 0})
            object.setAngularVelocity({0, 0, 0})
            object.setRotation({0, 0, 0})
        end
    end
end

-- ==============================
-- SMOOTH MOVEMENT / TOLERANCE
-- ==============================

local POSITION_TOLERANCE = 0.01
local ROTATION_TOLERANCE = 1.0

local function angleDiff(a, b)
    local difference = math.abs(a - b) % 360
    if difference > 180 then
        difference = 360 - difference
    end
    return difference
end

-- ==============================
-- REPACK
-- ==============================

function ScheduleRepack()
    if not GetActiveTrayColor() then
        return
    end
    if repackScheduled then
        return
    end
    repackScheduled = true
    Wait.frames(function()
        repackScheduled = false
        RepackTray()
    end, 2)
end

function RepackTray()
    local color = GetActiveTrayColor()
    if not color then
        return
    end
    ArrangeBankOnTray(color, color == "Purple")
    EjectWrongColorsCurrentlyOnTray(color)
    TellMatToRecount()
end

-- The bank has changed, so the player mat under this tray recounts its loyal warbands (it leaves out the bank's)
function TellMatToRecount()
    local mat = FindPlayerMatUnder(self)
    if mat then
        mat.call("ScheduleCount")
    end
end

-- ==============================
-- ARRANGE BANK
-- ==============================

-- Only called by RepackTray, once it has checked this tray is banking colorName
function ArrangeBankOnTray(colorName, imperial)
    local pieces = GetBankPiecesOnThisTray(colorName)
    local seen = {}
    for _, object in ipairs(pieces) do
        seen[object.getGUID()] = true
    end
    for _, object in ipairs(GetBankPiecesOnTable(colorName)) do
        if not seen[object.getGUID()] then
            table.insert(pieces, object)
        end
    end
    for index, object in ipairs(pieces) do
        if isValidObject(object) and not isHeld(object) then
            local slot = pos.warbandTraySlot(index, imperial)
            if slot then
                local worldPosition = TrayToWorld(slot)
                local currentPosition = object.getPosition()
                local dx = currentPosition.x - worldPosition.x
                local dy = currentPosition.y - worldPosition.y
                local dz = currentPosition.z - worldPosition.z
                local positionOkay = (dx * dx + dy * dy + dz * dz) <= (POSITION_TOLERANCE * POSITION_TOLERANCE)
                local currentRotation = object.getRotation()
                local rotationOkay = angleDiff(currentRotation.x, 0) <= ROTATION_TOLERANCE
                    and angleDiff(currentRotation.y, 0) <= ROTATION_TOLERANCE
                    and angleDiff(currentRotation.z, 0) <= ROTATION_TOLERANCE
                if not (positionOkay and rotationOkay) then
                    object.setVelocity({0, 0, 0})
                    object.setAngularVelocity({0, 0, 0})
                    object.setPositionSmooth(worldPosition, false, true)
                    object.setRotationSmooth({0, 0, 0}, false, true)
                end
            end
        end
    end
end

-- ==============================
-- LOOSE MAT WARBANDS
-- ==============================

function FindLooseMatWarbands(playerMat, colorName)
    local result = {}
    for _, object in ipairs(getObjectsWithTag(tags.warband)) do
        if
            isValidObject(object)
            and not object.hasTag(tags.warbandBank)
            and GetWarbandObjectColor(object) == colorName
            and isPositionOnPlayerMat(object.getPosition(), playerMat)
            and not isInTrayBounds(object)
        then
            table.insert(result, object)
        end
    end
    return result
end

-- ==============================
-- VERIFY LINEAGE
-- ==============================

function VerifyOwnLineageTotal()
    -- Without the storage box's memo there's no count to check against (and no art to spawn with)
    local look = lineageColor and GetWarbandLook(lineageColor)
    if not look then
        return
    end
    local tableObjects = GetAllPhysicalWarbandsOfColor(lineageColor)
    local bag = GetLineageBag()
    local bagEntries = bag and GetContainedWarbandEntries(bag) or {}
    local required = look.count
    local total = #tableObjects + #bagEntries
    if total > required then
        local excess = total - required
        for index = #tableObjects, 1, -1 do
            if excess <= 0 then
                break
            end
            local object = tableObjects[index]
            if isValidObject(object) and object.hasTag(tags.warbandBank) and not isHeld(object) then
                object.destruct()
                excess = excess - 1
            end
        end
        if excess > 0 and bag then
            DeleteWarbandEntriesFromBag(bag, excess)
        end
        return
    end
    if total < required then
        local missing = required - total
        if currentRole == "EXILE" then
            SpawnLineageBankOnTray(missing)
        elseif bag then
            SpawnWarbandsIntoBag(lineageColor, missing, bag)
        end
    end
end

-- ==============================
-- VERIFY PURPLE
-- ==============================

function VerifyPurpleTotal()
    local look = GetWarbandLook("Purple")
    if not look then
        return
    end
    local tableObjects = GetAllPhysicalWarbandsOfColor("Purple")
    local bag = GetPurpleReserveBag()
    local bagEntries = bag and GetContainedWarbandEntries(bag) or {}
    local required = look.count
    local total = #tableObjects + #bagEntries
    if total > required then
        local excess = total - required
        for index = #tableObjects, 1, -1 do
            if excess <= 0 then
                break
            end
            local object = tableObjects[index]
            if isValidObject(object) and object.hasTag(tags.warbandBank) and not isHeld(object) then
                object.destruct()
                excess = excess - 1
            end
        end
        if excess > 0 and bag then
            DeleteWarbandEntriesFromBag(bag, excess)
        end
        return
    end
    if total < required then
        local missing = required - total
        if isChancellorTray then
            SpawnPurpleBankOnTray(missing)
        elseif bag then
            SpawnWarbandsIntoBag("Purple", missing, bag)
        end
    end
end

-- ==============================
-- SPAWN LINEAGE BANK
-- ==============================

function SpawnLineageBankOnTray(amount)
    if amount <= 0 or currentRole ~= "EXILE" then
        return
    end
    local existing = CountBankPiecesOnThisTray(lineageColor)
    for i = 1, amount do
        local slot = pos.warbandTraySlot(existing + i, false)
        if slot then
            local object = SpawnWarband(lineageColor, TrayToWorld(slot))
            if object then
                object.addTag(tags.warbandBank)
            end
        end
    end
    Wait.frames(function()
        RepackTray()
    end, 3)
end

-- ==============================
-- SPAWN PURPLE BANK
-- ==============================

function SpawnPurpleBankOnTray(params)
    if not isChancellorTray then
        return
    end
    local amount = type(params) == "table" and tonumber(params.amount) or tonumber(params) or 0
    if amount <= 0 then
        return
    end
    local existing = CountBankPiecesOnThisTray("Purple")
    for i = 1, amount do
        local slot = pos.warbandTraySlot(existing + i, true)
        if slot then
            local object = SpawnWarband("Purple", TrayToWorld(slot))
            if object then
                object.addTag(tags.warbandBank)
            end
        end
    end
    Wait.frames(function()
        RepackTray()
    end, 3)
end

-- ==============================
-- SPAWN INTO BAG
-- ==============================

function SpawnWarbandsIntoBag(colorName, amount, bag)
    if amount <= 0 or not bag then
        return
    end
    SpawnWarbandsIntoBagStep(colorName, amount, bag)
end

function SpawnWarbandsIntoBagStep(colorName, remaining, bag)
    if remaining <= 0 or not bag or bag.isDestroyed() then
        return
    end
    local object = SpawnWarband(colorName, self.getPosition() + Vector(0, 4, 0))
    if not object then
        return
    end
    Wait.frames(function()
        if isValidObject(object) and bag and not bag.isDestroyed() then
            PutObjectInArchive(bag, object)
        end
        Wait.frames(function()
            SpawnWarbandsIntoBagStep(colorName, remaining - 1, bag)
        end, 1)
    end, 2)
end

-- ==============================
-- DELETE BAG ENTRIES
-- ==============================

function DeleteWarbandEntriesFromBag(bag, amount)
    if not bag or amount <= 0 then
        return
    end
    local entries = GetContainedWarbandEntries(bag)
    DeleteBagEntryStep(bag, entries, 1, amount)
end

function DeleteBagEntryStep(bag, entries, index, remaining)
    if remaining <= 0 or index > #entries then
        return
    end
    local entry = entries[index]
    if not entry or not entry.guid then
        DeleteBagEntryStep(bag, entries, index + 1, remaining)
        return
    end
    bag.takeObject({
        guid = entry.guid,
        position = self.getPosition() + Vector(0, 4, 0),
        smooth = false,
        callback_function = function(object)
            if isValidObject(object) then
                object.destruct()
            end
            Wait.frames(function()
                DeleteBagEntryStep(bag, entries, index + 1, remaining - 1)
            end, 1)
        end,
    })
end

-- ==============================
-- PHYSICAL SPAWNER
-- ==============================

function SpawnWarband(colorName, worldPosition)
    local look = GetWarbandLook(colorName)
    if not look then
        return nil
    end
    return spawnObjectData({
        data = {
            Name = "Custom_Model",
            Transform = {
                posX = worldPosition.x,
                posY = worldPosition.y,
                posZ = worldPosition.z,
                rotX = 0,
                rotY = 0,
                rotZ = 0,
                scaleX = 1,
                scaleY = 1,
                scaleZ = 1,
            },
            Nickname = WARBAND_NAME,
            Tags = {
                tags.warband,
            },
            -- its color, which is how it's recognised
            Memo = colorName,
            Description = "",
            ColorDiffuse = Color(1, 1, 1),
            Locked = false,
            Grid = true,
            Snap = true,
            DragSelectable = true,
            Autoraise = true,
            Sticky = true,
            Tooltip = false,
            Hands = false,
            CustomMesh = {
                MeshURL = look.mesh,
                DiffuseURL = look.diffuse,
                NormalURL = "",
                ColliderURL = "",
                Convex = true,
                MaterialIndex = 3,
                TypeIndex = 1,
                CustomShader = {
                    SpecularColor = Color(1, 1, 1),
                    SpecularIntensity = look.specular,
                    SpecularSharpness = 2,
                    FresnelStrength = 0,
                },
                CastShadows = true,
            },
        },
    })
end

-- ==============================
-- BANK LOOKUPS
-- ==============================

function GetBankPiecesOnTable(colorName)
    local result = {}
    for _, object in ipairs(getObjectsWithTag(tags.warband)) do
        if isValidObject(object) and object.hasTag(tags.warbandBank) and GetWarbandObjectColor(object) == colorName then
            table.insert(result, object)
        end
    end
    return result
end

function GetBankPiecesOnThisTray(colorName)
    local result = {}
    if not GetActiveTrayColor() then
        return result
    end
    for _, object in ipairs(getObjectsWithTag(tags.warband)) do
        if
            isValidObject(object)
            and object.hasTag(tags.warbandBank)
            and GetWarbandObjectColor(object) == colorName
            and isInTrayBounds(object)
        then
            table.insert(result, object)
        end
    end
    return result
end

function CountBankPiecesOnThisTray(colorName)
    return #GetBankPiecesOnThisTray(colorName)
end

function GetAllPhysicalWarbandsOfColor(colorName)
    local result = {}
    for _, object in ipairs(getObjectsWithTag(tags.warband)) do
        if isValidObject(object) and GetWarbandObjectColor(object) == colorName then
            table.insert(result, object)
        end
    end
    return result
end

-- ==============================
-- FIND CHANCELLOR
-- ==============================

function FindChancellorTray()
    -- The shared Chancellor tray, if it's out on the table
    for _, tray in ipairs(getObjectsWithTag(tags.warbandTray)) do
        if isValidObject(tray) then
            local success, color = pcall(function()
                return tray.call("GetTrayColor")
            end)
            if success and color == "Purple" then
                return tray
            end
        end
    end
    return nil
end

-- How far the Chancellor tray sits from the Chancellor's own warband tray (pos.chancellorTray - pos.warbandTray)
function ChancellorTrayOffset()
    local tray, chancellor = pos.warbandTray(1), pos.chancellorTray(1)
    return Vector(chancellor.x - tray.x, chancellor.y - tray.y, chancellor.z - tray.z)
end

-- ==============================
-- WRONG COLOR EJECTION
-- ==============================

function EjectWrongColorsCurrentlyOnTray(allowedColor)
    for _, object in ipairs(getObjectsWithTag(tags.warband)) do
        if isValidObject(object) and isInTrayBounds(object) then
            local color = GetWarbandObjectColor(object)
            if color and color ~= allowedColor then
                if object.hasTag(tags.warbandBank) then
                    object.removeTag(tags.warbandBank)
                end
                EjectWrongColor(object)
            end
        end
    end
end

-- Callers (onObjectDrop, EjectWrongColorsCurrentlyOnTray) have already checked this tray is banking
function EjectWrongColor(object)
    if not isValidObject(object) then
        return
    end
    -- pushed off the side of the visible tray
    local localPosition = WorldToTray(object.getPosition(), self.getPosition())
    localPosition.x = EJECT_X
    object.setVelocity({0, 0, 0})
    object.setAngularVelocity({0, 0, 0})
    object.setPosition(TrayToWorld(localPosition, self.getPosition()))
end

-- ==============================
-- FIND PLAYER MAT
-- ==============================

function FindMyPlayerMat()
    -- Tray never moves now, including while Citizen.
    local referencePosition = self.getPosition()
    for _, object in ipairs(getAllObjects()) do
        if
            isValidObject(object)
            and IsPlayerMat(object)
            and isPositionOnPlayerMat(referencePosition, object)
        then
            return object
        end
    end
    return nil
end

-- ==============================
-- PLAYER MAT BOUNDS
-- ==============================

function isPositionOnPlayerMat(position, playerMat)
    local bounds = playerMat.getBounds()
    if not bounds or not bounds.center or not bounds.size then
        return false
    end
    local center = bounds.center
    local size = bounds.size
    local halfX = size.x / 2
    local halfZ = size.z / 2
    return position.x >= center.x - halfX
        and position.x <= center.x + halfX
        and position.z >= center.z - halfZ
        and position.z <= center.z + halfZ
end

-- ==============================
-- TRAY BOUNDS
-- ==============================

function getTrayLocalBounds()
    return TRAY_BOUNDS.minX, TRAY_BOUNDS.maxX, TRAY_BOUNDS.minZ, TRAY_BOUNDS.maxZ
end

function isInTrayBounds(object)
    if not isValidObject(object) then
        return false
    end
    local minX, maxX, minZ, maxZ = getTrayLocalBounds()
    local function inside(localPosition)
        return localPosition.x >= minX and localPosition.x <= maxX and localPosition.z >= minZ and localPosition.z <= maxZ
    end
    -- Around the visible tray, and around its slots (the same place except on the Chancellor tray)
    local position = object.getPosition()
    return inside(WorldToTray(position, self.getPosition())) or inside(WorldToTray(position))
end

-- ==============================
-- TILE UNITS
--
-- Positions on the tray are in world units along this
-- tile's own axes, from its centre. Unlike positionToWorld
-- these ignore the tile's scale.
-- ==============================

-- Where the tray's slots, bounds and eject point are measured from. The Chancellor tray's art sits
-- offset from the Chancellor's own tray (pos.chancellorTray), but its slots stay on that tray's spot.
function TrayOrigin()
    if isChancellorTray then
        return self.getPosition() - ChancellorTrayOffset()
    end
    return self.getPosition()
end

-- origin defaults to TrayOrigin() (where the slots are measured from)
function TrayToWorld(position, origin)
    origin = origin or TrayOrigin()
    local yaw = math.rad(self.getRotation().y)
    return Vector(origin.x + position.x * math.cos(yaw) + position.z * math.sin(yaw), origin.y + position.y, origin.z - position.x * math.sin(yaw) + position.z * math.cos(yaw))
end

function WorldToTray(position, origin)
    origin = origin or TrayOrigin()
    local yaw = math.rad(self.getRotation().y)
    local dx = position.x - origin.x
    local dz = position.z - origin.z
    return Vector(dx * math.cos(yaw) - dz * math.sin(yaw), position.y - origin.y, dx * math.sin(yaw) + dz * math.cos(yaw))
end

-- ==============================
-- HELPERS
-- ==============================

function isHeld(object)
    local color = object.held_by_color
    return color ~= nil and color ~= ""
end

function isValidObject(object)
    return object ~= nil and not object.isDestroyed()
end

-- ==============================
-- VISIBILITY
-- ==============================

-- Every player color, so the tray can be hidden from all of them
local ALL_COLORS = {"White", "Brown", "Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Purple", "Pink", "Grey", "Black"}

-- Shows this tray while it's a bank (Exile, or the Chancellor tray) and hides it otherwise.
-- setInvisibleTo can't hide it from the Game Master (who sees into hidden areas), so it's also tinted see-through.
function UpdateVisibility()
    local visible = GetActiveTrayColor() ~= nil
    self.setInvisibleTo(visible and {} or ALL_COLORS)
    local tint = self.getColorTint()
    self.setColorTint({tint.r, tint.g, tint.b, visible and 1 or 0})
    -- a see-through tint doesn't hide buttons, so the muster button only goes on while it's a bank, in this tray's
    -- player color
    self.clearButtons()
    if visible then
        local hex = MUSTER_BUTTON_COLORS[lineageColor]
        local color = hex and Color.fromHex(hex) or GetOathColor(lineageColor) or Color(0.5, 0.5, 0.5)
        -- a dark "+" on light colors, a white one on the rest
        local light = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b > 0.6
        self.createButton({
            click_function = "MusterOneWarband",
            function_owner = self,
            label = "+",
            tooltip = "Muster one warband onto the mat (right-click: bring one back)",
            position = isChancellorTray and CHANCELLOR_MUSTER_BUTTON_POSITION or MUSTER_BUTTON_POSITION,
            rotation = {0, 0, 0},
            width = MUSTER_BUTTON_SIZE,
            height = MUSTER_BUTTON_SIZE,
            font_size = MUSTER_FONT_SIZE,
            color = color,
            font_color = light and {0, 0, 0} or {1, 1, 1},
        })
    end
end

-- ==============================
-- CHANCELLOR TRAY
--
-- There is one shared Chancellor tray (memo "Purple"), kept in the
-- Chancellor Archive with the Purple warbands while nobody is
-- Chancellor. The Chancellor's lineage tray brings it out onto its
-- own spot and sends it back when they stop being Chancellor.
-- ==============================

-- Gap between the player board and the pieces moved out of the Chancellor tray's way, and between those pieces
local CLEAR_MARGIN = 0.5

-- How far around each Chancellor bank slot counts as in the way (about half a warband)
local SLOT_PADDING = 0.5

-- Object types that are never moved out of the Chancellor tray's way (zones, the table)
local UNMOVABLE_TYPES = {Scripting = true, Hand = true, Fog = true, Surface = true, Layout = true}

-- Moves the unlocked pieces (other than warbands) sitting where chancellorTray now is, or where its 24 bank
-- warbands go (on this tray's spot, past the tray's art), to the right of this player's board: a column
-- starting level with the board's top edge, each piece below the last
function ClearChancellorTraySpot(chancellorTray)
    local board = FindPlayerBoard(lineageColor)
    if not board or not isValidObject(chancellorTray) then
        return
    end
    local area = chancellorTray.getBounds()
    local minX, maxX = area.center.x - area.size.x / 2, area.center.x + area.size.x / 2
    local minZ, maxZ = area.center.z - area.size.z / 2, area.center.z + area.size.z / 2
    local i, slot = 1, pos.warbandTraySlot(1, true)
    while slot do
        local spot = TrayToWorld(slot)
        minX, maxX = math.min(minX, spot.x - SLOT_PADDING), math.max(maxX, spot.x + SLOT_PADDING)
        minZ, maxZ = math.min(minZ, spot.z - SLOT_PADDING), math.max(maxZ, spot.z + SLOT_PADDING)
        i = i + 1
        slot = pos.warbandTraySlot(i, true)
    end
    local boardArea = board.getBounds()
    local x = boardArea.center.x + boardArea.size.x / 2 + CLEAR_MARGIN
    local z = boardArea.center.z + boardArea.size.z / 2
    for _, object in ipairs(getAllObjects()) do
        local position = object.getPosition()
        if
            object ~= chancellorTray
            and object ~= self
            and not UNMOVABLE_TYPES[object.type]
            and not object.getLock()
            and not object.hasTag(tags.warband)
            and position.x >= minX and position.x <= maxX
            and position.z >= minZ and position.z <= maxZ
        then
            local size = object.getBounds().size
            object.setPositionSmooth({x = x + size.x / 2, y = position.y + 0.5, z = z - size.z / 2}, false, true)
            z = z - size.z - CLEAR_MARGIN
        end
    end
end

-- Brings the Chancellor tray onto this tray's spot: over from a previous Chancellor's mat,
-- or out of the Chancellor Archive along with its Purple warbands
function BringOutChancellorTray(finishedCallback)
    local done = finishedCallback or function() end
    local spot = self.getPosition() + ChancellorTrayOffset()
    local chancellor = FindChancellorTray()
    if chancellor then
        chancellor.setPositionSmooth(spot, false, false)
        chancellor.setRotationSmooth(self.getRotation(), false, false)
        Wait.time(function()
            ClearChancellorTraySpot(chancellor)
            chancellor.call("ScheduleRepack")
            done()
        end, 1)
        return
    end

    local reserve = GetPurpleReserveBag()
    local trayEntry = nil
    local warbandEntries = {}
    for _, entry in ipairs(reserve and reserve.getObjects() or {}) do
        if BagEntryHasTag(entry, tags.warbandTray) then
            trayEntry = entry
        elseif BagEntryHasTag(entry, tags.warband) then
            table.insert(warbandEntries, entry)
        end
    end
    if not trayEntry then
        print("The Chancellor tray isn't in the Chancellor Archive.")
        done()
        return
    end

    -- The Chancellor tray waits while this is set, then counts and packs its bank
    reserve.setVar("withdrawing", true)
    reserve.takeObject({
        guid = trayEntry.guid,
        position = spot,
        rotation = self.getRotation(),
        smooth = false,
        callback_function = function(tray)
            tray.setLock(true)
            Wait.frames(function()
                ClearChancellorTraySpot(tray)
            end, 1)
        end,
    })
    local function takeWarband(index)
        local entry = warbandEntries[index]
        if not entry then
            Wait.time(function()
                reserve.setVar("withdrawing", false)
                done()
            end, 1)
            return
        end
        -- the Chancellor tray's slots are on this tray's spot
        local slot = pos.warbandTraySlot(index, true)
        reserve.takeObject({
            guid = entry.guid,
            position = slot and TrayToWorld(slot) or self.getPosition() + Vector(0, 1, 0),
            rotation = {0, 0, 0},
            smooth = true,
            callback_function = function(warband)
                warband.addTag(tags.warbandBank)
            end,
        })
        Wait.frames(function()
            takeWarband(index + 1)
        end, 2)
    end
    takeWarband(1)
end

-- Sends the Chancellor tray and its Purple bank back to the Chancellor Archive. Only called when this
-- player stops being the Chancellor; there's only ever one, so the tray out on the table is theirs.
function ReturnChancellorTray(finishedCallback)
    local done = finishedCallback or function() end
    local chancellor = FindChancellorTray()
    local reserve = GetPurpleReserveBag()
    if not chancellor or not reserve then
        done()
        return
    end
    StoreObjectsInBagStep(chancellor.call("GetBankPieces") or {}, 1, reserve, function()
        PutObjectInArchive(reserve, chancellor)
        Wait.frames(done, 2)
    end)
end

-- Takes this lineage's warbands back out of its archive into the bank
function RecoverLineageBank(finishedCallback)
    local done = finishedCallback or function() end
    local bag = GetLineageBag()
    local entries = GetContainedWarbandEntries(bag)
    local existing = CountBankPiecesOnThisTray(lineageColor)
    local function takeWarband(index)
        local entry = entries[index]
        if not entry then
            Wait.time(done, 1)
            return
        end
        local slot = pos.warbandTraySlot(existing + index, false)
        bag.takeObject({
            guid = entry.guid,
            position = slot and TrayToWorld(slot) or self.getPosition() + Vector(0, 1, 0),
            rotation = {0, 0, 0},
            smooth = true,
            callback_function = function(warband)
                warband.addTag(tags.warbandBank)
            end,
        })
        Wait.frames(function()
            takeWarband(index + 1)
        end, 2)
    end
    takeWarband(1)
end
