function dataTableContains(table, x)
    for _, obj in ipairs(table) do
        if obj == x then return true end
    end
    return false
end

function getRandomObjectFromContainer(container, flipped)
    local objects = container.getObjects()
    if #objects == 0 then return nil end  -- Prevent errors when bag is empty
    local selected = objects[math.random(1, #objects)]

    return container.takeObject({
        guid = selected.guid,
        position = vectorSum(container.getPosition(), {x = 0, y = 5, z = 0}),
        rotation = flipped and vectorSum({x = 180, y = 180, z = 0},container.getRotation()) or container.getRotation(),
    })
end

function vectorSum(v1, v2)
    return {
        x = v1.x + v2.x,
        y = v1.y + v2.y,
        z = v1.z + v2.z
    }
end

function removeButtons(...)
    local buttonsToRemove = {...}
    for _, buttonToRemove in ipairs(buttonsToRemove) do
        local buttonIndex = nil
        if self.getButtons() then
            for i, button in ipairs(self.getButtons()) do
                if button and button.label == buttonToRemove.label then
                    buttonIndex = button.index
                    break
                end
            end
            if buttonIndex then self.removeButton(buttonIndex) end
        end
    end
end

function createButtons(...)
    local buttonsToCreate = {...}
    for _, buttonToCreate in ipairs(buttonsToCreate) do
        self.createButton(buttonToCreate)
    end
end

function addTagAndReturn(item, tag)
    item.addTag(tag)
    return item
end

function prettyPrintTable(obj, indent)
    indent = indent or 0
    local formatting = string.rep("  ", indent)

    if type(obj) ~= "table" then
        print(formatting .. tostring(obj))
        return
    end

    print(formatting .. "{")
    for key, value in pairs(obj) do
        local key_str = tostring(key)
        if type(value) == "table" then
            print(formatting .. "  " .. key_str .. " = ")
            prettyPrintTable(value, indent + 1)
        else
            print(formatting .. "  " .. key_str .. " = " .. tostring(value))
        end
    end
    print(formatting .. "}")
end

function roundToNearest180(z)
    -- Round z rotation to nearest 0, 180, or 360
    local nearest = 0
    if math.abs(z - 180) < math.abs(z - 0) and math.abs(z - 180) < math.abs(z - 360) then
        nearest = 180
    elseif math.abs(z - 360) < math.abs(z - 0) then
        nearest = 360
    end
    return nearest
end


-- Get transform for a given tag and index
-- Requires GeneralConfig
function getTransformStruct(tag, index, baseTransform)
    return {
        position = vectorSum(
            pos[tag](index or 1), 
            (baseTransform and baseTransform.position or {x=0,y=0,z=0})
        ),
        rotation = rot[tag],
    }
end

local base82 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+-=/~!@$%^&(){};:,.?'
local base82Plus = base82 .. "#>" --With seperators
local encodingVersion = 2

-- Encodes a number into "Base82" with the above string as a list of all digits
function oEncode(data)
    assert(type(data) == 'number' and data >= 0 and data % 1 == 0,
        'encode expects a non-negative integer')
    if data == 0 then return base82:sub(1, 1) end

    local result = ''
    while data > 0 do
        local remainder = data % 82
        -- Get the nth character (+1 because lua starts index at 1)
        result = base82:sub(remainder + 1, remainder + 1) .. result
        data = math.floor(data / 82)
    end
    return result
end

-- Decodes a string from "Base82" back into a number
function oDecode(data)
    assert(type(data) == 'string' and data ~= '',
        'decode expects a non-empty base64 string')
    local result = 0
    for i = 1, #data do
        local value = base82:find(data:sub(i, i), 1, true)
        assert(value, 'decode received an invalid string')
        result = result * 82 + value - 1
    end
    return result
end

function padEncode(n, width)
    local s = oEncode(n)
    return string.rep("0", width - #s) .. s
end

function oEncode2D(data)
    return padEncode(data, 2)
end

function scramble(s, isDecoding)
    local n = #base82Plus
    local seed = 468529063 -- preselected numeric seed
    local result = ""
    local input = s
    if isDecoding then
        input = input:gsub("%s", "") --Remove whitespace
        assert(input:sub(1,2) == oEncode2D(encodingVersion), 'this export string uses the wrong encoding version')
        input = input:sub(3,-3) -- Remove first and last 2 characters (version number and checksum)
    end
    for i = 1, #input do --For each 'digit' in our data string
        seed = (seed * 16807) % 2147483647 --Pseudo-random shift as we walk through: (multiplier 7^5, modulus 2^31 - 1).
        assert(base82Plus:find(input:sub(i, i), 1, true), "scramble: invalid character in string")
        local idx = base82Plus:find(input:sub(i, i), 1, true) - 1 --Find the index of current digit in our alphabet
        
        if not isDecoding then
            local v = (idx + seed) % n --Shift digit forward using our seed
            result = result .. base82Plus:sub(v + 1, v + 1) --Write the digit
            seed = (seed + idx) % 2147483647 --Modify our seed by the index of the digit
        else
            local realIdx = (idx - seed) % n --Shift digit back using our seed to get the original digit
            result = result .. base82Plus:sub(realIdx + 1, realIdx + 1) --Write the digit
            seed = (seed + realIdx) % 2147483647 --Modify our seed by the original digit
        end
    end
    if not isDecoding then
        result = oEncode2D(encodingVersion) .. result .. oEncode2D(checksum(input))
    else
        local check = s:gsub("%s", ""):sub(-2)
        assert(check == oEncode2D(checksum(result)), 'Checksum failure, message is likely corrupted')
    end
    return result
end

function checksum(s)
    local sum = 0
    for i = 1, #s do
        sum = (sum + i * (base82Plus:find(s:sub(i, i), 1, true) - 1)) % 6724  -- 82^2
    end
    return sum
end
