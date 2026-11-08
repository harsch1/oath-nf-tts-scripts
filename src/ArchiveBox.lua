-- ==============================
-- OATH ARCHIVE BOX
--
-- Each color's book on the bookshelf. It holds a player's
-- pieces while they're off the table, and remembers their role
-- so it can be asked while the storage box is stored.
--
-- The Chancellor Archive runs this too, with its own additions
-- in src/ChancellorArchive.
-- ==============================

require("src/Config/GeneralConfig")
require("src/Utils/Stamps")

self.interactable = false

-- tryObjectEnter refuses everything unless this is set (by the Bookshelf, trays and storage boxes)
allowEnter = false

local ROLES = {EXILE = true, CITIZEN = true, CHANCELLOR = true}

-- ==============================
-- STATE
--
-- Everything in archiveState is saved, so the Chancellor
-- Archive can keep its own fields here too.
-- ==============================

-- archiveState.cardLayout: the player's cards, relics and lineage cards at their last deposit (from the Bookshelf), by
-- GUID: each one's position and rotation relative to the player board
archiveState = {
    role = "EXILE",
    cardLayout = {},
}

-- ==============================
-- SAVE / LOAD
-- ==============================

function onSave()
    return JSON.encode(archiveState)
end

function onLoad(savedData)
    if savedData and savedData ~= "" then
        local success, saved = pcall(JSON.decode, savedData)
        if success and type(saved) == "table" then
            for key, value in pairs(saved) do
                archiveState[key] = value
            end
        end
    end
    if not ROLES[archiveState.role] then
        archiveState.role = "EXILE"
    end
    UpdateAppearance()
end

function tryObjectEnter(object)
    return allowEnter
end

-- ==============================
-- PUBLIC API
-- ==============================

function GetRole()
    return archiveState.role
end

-- Called by the Bookshelf as it hides this archive (its player is out on the table) or shows it again.
-- Stamps don't follow the Bookshelf's see-through tint, so they're taken off while it's hidden.
function SetWithdrawn(withdrawn)
    archiveState.withdrawn = withdrawn == true
    UpdateAppearance()
end

-- The Bookshelf records the card layout as it deposits this player, reads it back as it withdraws them, then clears it
function SetCardLayout(layout)
    archiveState.cardLayout = layout or {}
end

function GetCardLayout()
    return archiveState.cardLayout or {}
end

function SetRole(newRole)
    newRole = newRole and string.upper(tostring(newRole))
    if not ROLES[newRole] or newRole == archiveState.role then
        return
    end
    archiveState.role = newRole
    UpdateAppearance()
end

-- Puts object into this archive, opening it just for the put. Requests are counted so
-- overlapping puts don't close it on each other.
function StoreObject(object)
    if object == nil or object.isDestroyed() then
        return false
    end
    enterRequests = (enterRequests or 0) + 1
    allowEnter = true
    self.putObject(object)
    Wait.frames(function()
        enterRequests = (enterRequests or 1) - 1
        if enterRequests <= 0 then
            allowEnter = false
        end
    end, 2)
    return true
end

-- ==============================
-- APPEARANCE
-- ==============================

-- A Citizen's archive has the citizen stamp on its spine, unless it's hidden while withdrawn
-- (src/ChancellorArchive replaces this for the Chancellor Archive)
function UpdateAppearance()
    local citizen = archiveState.role == "CITIZEN" and not archiveState.withdrawn
    SetStamp(self, citizen and "Citizen" or nil, StampOnSpine)
end
