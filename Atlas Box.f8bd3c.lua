
unlockedTag = "Unlocked"

function onLoad()
    if not self.hasTag(unlockedTag) then
        self.addTag(unlockedTag)
        self.removeTag(unlockedTag)
    end
end

function tryObjectEnter(object)
    if self.hasTag(unlockedTag) then
        return true
    else
        print("Atlas Box manipulation is handled by scripting using the Atlas Portal.\nIf you really want to manually change things, change tags on the Atlas Box to remove its lock.\n")
        return false
    end
end

function tryRandomize(object)
    if self.hasTag(unlockedTag) then
        return true
    else
        return false
    end
end

function onObjectLeaveContainer(container, leave_object)
    if container == self and not self.hasTag(unlockedTag) then
        print("Atlas Box manipulation is handled by scripting using the Atlas Portal.\nIf you really want to manually change things, change tags on the Atlas Box to remove its lock.\n")
        container.putObject(leave_object)
    end
end