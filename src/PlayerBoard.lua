-- ==============================
-- OATH PLAYER BOARD
--
-- Every state of every player board runs this. Its state is its
-- player's role: 1 Exile, 2 Citizen, 3 Chancellor. Flipping the
-- board asks the player's storage box to change role; the
-- storage box calls ApplyRole to flip it when the role changes
-- from anywhere else.
-- ==============================

require("src/Config/GeneralConfig")
require("src/Utils/HelperFunctions")

local STATE_FOR_ROLE = {EXILE = 1, CITIZEN = 2, CHANCELLOR = 3}
local ROLE_FOR_STATE = {"EXILE", "CITIZEN", "CHANCELLOR"}

-- ==============================
-- LOAD
-- ==============================

function onLoad()
    -- Each state is its own object, unlocked unless saved locked: lock it once it's on its spot on the mat
    -- (after gliding out of the archive, or straight away after a state change)
    LockAtLayoutPosition(self, GetColor(), "playerBoard")

    -- A state change loads the new state as a new object, so tell the storage box this state's role.
    -- (A call from the board counts as fromBoard, so the box won't flip it back.) The box ignores this
    -- while it's still loading, and when it already has this role (as when it flipped the board).
    Wait.frames(function()
        local box = GetStorageBox()
        if box then
            box.call("SetRole", GetRole())
        end
    end, 5)
end

-- ==============================
-- PUBLIC API
-- ==============================

-- This board's lineage color, from its memo
function GetColor()
    return trim(self.memo)
end

function GetRole()
    return ROLE_FOR_STATE[self.getStateId()]
end

-- Flips the board to the state for role (called by the storage box)
function ApplyRole(role)
    local state = STATE_FOR_ROLE[role and string.upper(tostring(role))]
    if state and state ~= self.getStateId() then
        self.setState(state)
    end
end

-- ==============================
-- HELPERS
-- ==============================

-- The player's storage box, if it's out on the table
function GetStorageBox()
    local guid = GUIDs.storageBags[GetColor()]
    return guid and getObjectFromGUID(guid)
end
