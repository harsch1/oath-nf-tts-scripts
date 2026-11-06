-- ==============================
-- WARBANDS
--
-- Shared by the warband trays and the storage boxes: each
-- color's warband art, and telling a warband's color from it.
-- ==============================

warbandAssetLookup = {
    Purple = "https://dl.dropboxusercontent.com/scl/fi/age6wjmfad10gsrdc8oqi/Warband-Purple.png?rlkey=nth3zrj7w37ch9keoqol731ad&dl=0",
    Red = "https://dl.dropboxusercontent.com/scl/fi/wjjocnvlb9bh505t6wur3/Warband-Red.png?rlkey=qv08yyw9jtk8ysnwuho56yu8y&dl=0",
    Yellow = "https://dl.dropboxusercontent.com/scl/fi/8je0moel7pkjsqi141d4q/Warband-Yellow.png?rlkey=lzjmugumgp2j7tn1p4bq1ce5l&dl=0",
    Black = "https://dl.dropboxusercontent.com/scl/fi/6x8nqx1xxtpkadrxjqvh0/Warband-Black.png?rlkey=y8yr9j317dp6yptd5s5ffvzwr&dl=0",
    Blue = "https://dl.dropboxusercontent.com/scl/fi/xjkj5t4s4m4oq6m95a6l4/Warband-Blue.png?rlkey=gpotyd5meuuzb7y71cwdk7sxa&dl=0",
    Brown = "https://dl.dropboxusercontent.com/scl/fi/dd2ut6h0hn73axi0wanv9/Warband-Brown.png?rlkey=1390z50o9520m4xevau62bz2d&dl=0",
    White = "https://dl.dropboxusercontent.com/scl/fi/jshke5j0ldd63wxib5py3/Warband-White.png?rlkey=xp87qwm3jq9tife9sp04jxl8j&dl=0",
    Pink = "https://dl.dropboxusercontent.com/scl/fi/jpczwrg2s992iii7cee6p/Warband-Pink.png?rlkey=tw5l5bpadh08v0j0vm4loffd9&dl=0",
}

-- The Oath color of a warband out on the table, from its art (nil if it isn't a known warband)
function GetWarbandObjectColor(object)
    if object == nil or object.isDestroyed() then
        return nil
    end
    local data = object.getData()
    if not data or not data.CustomMesh then
        return nil
    end
    local texture = data.CustomMesh.DiffuseURL
    for colorName, expectedTexture in pairs(warbandAssetLookup) do
        if texture == expectedTexture then
            return colorName
        end
    end
    return nil
end

-- Whether a container entry (from getObjects()) has a tag; case-insensitive, like hasTag on objects out on the table
function BagEntryHasTag(entry, wantedTag)
    if not entry or not entry.tags then
        return false
    end
    for _, tag in ipairs(entry.tags) do
        if tag:lower() == wantedTag:lower() then
            return true
        end
    end
    return false
end
