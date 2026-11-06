-- ==============================
-- STAMPS
--
-- Role stamps: decals named "stamp:<key>" (a key of stampImages
-- in GeneralConfig), placed on a box's face-up cover or on an
-- archive's spine. Only decals with that prefix are ever touched.
-- ==============================

STAMP_PREFIX = "stamp:"

-- Stamp heights in world units: on a storage box's cover, and on an archive's spine (shrunk to fit its width)
local COVER_STAMP_HEIGHT = 1.4
local SPINE_STAMP_HEIGHT = 1.2

-- The cover stamp's corner: the gap from the cover's top and right edges to a stamp COVER_STAMP_HEIGHT wide
-- (every stamp is centred where that one would be, however wide it is), and how far it may drift further in
local COVER_MARGIN = 0.4
local COVER_JITTER = 0.5

-- How far (degrees) a stamp may turn either way, spinning flat on its surface
local COVER_TURN = 8
local SPINE_TURN = 4

-- The spine stamp's drift along the spine's width
local SPINE_JITTER = 0.1

-- How far above the surface a stamp sits, so it doesn't flicker into it
local SURFACE_GAP = 0.01

local atan2 = math.atan2 or math.atan

-- Makes key the only stamp on object (key nil: no stamp). A matching stamp already there is kept where it is;
-- otherwise placeStamp(object, image) gives the new one's world position, normal, up and size.
function SetStamp(object, key, placeStamp)
    local decals = object.getDecals() or {}
    local kept, hasStamp, changed = {}, false, false
    for _, decal in ipairs(decals) do
        if decal.name:sub(1, #STAMP_PREFIX) ~= STAMP_PREFIX then
            table.insert(kept, decal)
        elseif key and decal.name == STAMP_PREFIX .. key and not hasStamp then
            hasStamp = true
            table.insert(kept, decal)
        else
            changed = true
        end
    end
    local image = key and stampImages[key]
    if image and not hasStamp then
        local placement = placeStamp(object, image)
        table.insert(kept, MakeDecal(object, STAMP_PREFIX .. key, image.url, placement))
        changed = true
    end
    if changed then
        object.setDecals(kept)
    end
end

-- ==============================
-- PLACEMENTS
--
-- In the object's own axes, from its foldbox model's extents
-- (foldboxModels in GeneralConfig): its collider sits inside the
-- visible model, so its bounds can't be used. Sizes and gaps
-- above are world units, so they're divided by the object's scale.
-- ==============================

local function jitter(amount)
    return (math.random() * 2 - 1) * amount
end

-- A random turn of up to maxDegrees either way, as (sin, cos)
local function turn(maxDegrees)
    local angle = math.rad(jitter(maxDegrees))
    return math.sin(angle), math.cos(angle)
end

-- The foldbox model object is using (the player's unless it has the Chancellor's mesh)
local function modelOf(object)
    local mesh = object.getCustomObject().mesh
    for _, model in pairs(foldboxModels) do
        if model.mesh == mesh then
            return model
        end
    end
    return foldboxModels.player
end

-- A stamp on the face-up cover of a storage box on the table, near its top right corner as seen from the
-- player's seat. Lying upside down (rot.warbandReturn), its cover is its -y face, the player's right its -x
-- and the far edge its +z.
function StampOnCover(object, image)
    local model, scale = modelOf(object), object.getScale().x
    local height = COVER_STAMP_HEIGHT
    local width = height * image.width / image.height
    -- an image's coverShift (world units) moves it towards the right edge from there
    local fromRight = COVER_MARGIN + COVER_STAMP_HEIGHT / 2 - (image.coverShift or 0) + math.random() * COVER_JITTER
    local fromTop = COVER_MARGIN + height / 2 + math.random() * COVER_JITTER
    -- its top turned a little within the cover's plane (x and z)
    local sin, cos = turn(COVER_TURN)
    return {
        position = Vector(model.min.x + fromRight / scale, model.min.y - SURFACE_GAP / scale, model.max.z - fromTop / scale),
        normal = Vector(0, -1, 0),
        up = Vector(sin, 0, cos),
        width = width,
        height = height,
    }
end

-- A stamp on the spine (its +x face) of an archive standing on the shelf, in the spine's upper third.
-- Standing (rot 270 on x), its +z points up and the spine's width runs along its y.
function StampOnSpine(object, image)
    local model, scale = modelOf(object), object.getScale().x
    local height = SPINE_STAMP_HEIGHT
    local width = height * image.width / image.height
    -- keep it inside the spine's width
    local maxWidth = (model.max.y - model.min.y) * scale * 0.8
    if width > maxWidth then
        height, width = height * maxWidth / width, maxWidth
    end
    -- its top turned a little within the spine's plane (y and z)
    local sin, cos = turn(SPINE_TURN)
    return {
        position = Vector(
            model.max.x + SURFACE_GAP / scale,
            (model.min.y + model.max.y) / 2 + jitter(SPINE_JITTER) / scale,
            model.max.z - (model.max.z - model.min.z) / 6
        ),
        normal = Vector(1, 0, 0),
        up = Vector(0, sin, cos),
        width = width,
        height = height,
    }
end

-- ==============================
-- DECAL MATHS
--
-- A decal's image faces its own -z, with its top along its +y.
-- Its position and rotation are in the object's own axes, and
-- its scale is multiplied by the object's.
-- ==============================

local function cross(a, b)
    return Vector(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

-- Euler angles (degrees, as TTS uses them) of the rotation whose axes are x, y and z
local function eulerFromAxes(x, y, z)
    -- rows of the matrix whose columns are x, y, z
    local m00, m01, m02 = x.x, y.x, z.x
    local m10, m11, m12 = x.y, y.y, z.y
    local m20, m21, m22 = x.z, y.z, z.z
    local rx = math.asin(math.max(-1, math.min(1, -m12)))
    local ry, rz
    if math.abs(math.cos(rx)) > 1e-6 then
        ry = atan2(m02, m22)
        rz = atan2(m10, m11)
    else
        ry = atan2(-m20, m00)
        rz = 0
    end
    return Vector(math.deg(rx), math.deg(ry), math.deg(rz))
end

-- A decal for object from a placement in its own axes (position, the direction it faces and its top's direction,
-- at right angles), with its size in world units
function MakeDecal(object, name, url, placement)
    local z = placement.normal * -1
    local x = cross(placement.up, z)
    local scale = object.getScale().x
    return {
        name = name,
        url = url,
        position = placement.position,
        rotation = eulerFromAxes(x, placement.up, z),
        scale = Vector(placement.width / scale, placement.height / scale, 1),
    }
end
