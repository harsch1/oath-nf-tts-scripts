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
