-- ==============================
-- OATH CHANCELLOR ARCHIVE
--
-- The Chancellor Archive on the bookshelf: an archive box (see
-- src/ArchiveBox) that also holds the Chancellor tray and the
-- Purple warbands while nobody is Chancellor. It remembers
-- which color is the Chancellor, even while they're stored, so
-- storage boxes can check there's only one.
-- ==============================

require("src/ArchiveBox")
require("src/Utils/Warbands")

-- archiveState.chancellorColor: the color that is the Chancellor, or nil if nobody is

-- ==============================
-- PUBLIC API
-- ==============================

function GetChancellor()
    return archiveState.chancellorColor
end

-- color is the new Chancellor's color, or "" when nobody is the Chancellor any more
function SetChancellor(color)
    archiveState.chancellorColor = (color ~= nil and color ~= "") and color or nil
    UpdateAppearance()
end

-- The Chancellor's color stamp on the spine (replaces ArchiveBox's, which shows a Citizen's stamp).
-- The Bookshelf never withdraws the Chancellor Archive, but it's hidden like any archive if it is.
function UpdateAppearance()
    SetStamp(self, not archiveState.withdrawn and archiveState.chancellorColor or nil, StampOnSpine)
end

-- Takes one Purple warband out (for a Citizen while the Chancellor tray isn't out):
-- archive.call("TakeWarband", {position = ..., rotation = ...}). Returns false if there are none left.
function TakeWarband(params)
    for _, entry in ipairs(self.getObjects()) do
        if BagEntryHasTag(entry, tags.warband) then
            self.takeObject({
                guid = entry.guid,
                position = params.position,
                rotation = params.rotation,
                smooth = false,
                callback_function = function(object)
                    object.removeTag(tags.warbandBank)
                end,
            })
            return true
        end
    end
    return false
end
