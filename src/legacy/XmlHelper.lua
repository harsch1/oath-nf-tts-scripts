local siteNames = {}

--- Escapes special XML characters in a string.
-- @param str The string to escape.
-- @return The escaped string.
function escapeXml(str)
    if type(str) ~= "string" then return str end
    str = string.gsub(str, "&", "&amp;") -- Must be first
    str = string.gsub(str, "<", "&lt;")
    str = string.gsub(str, ">", "&gt;")
    str = string.gsub(str, "\"", "&quot;")
    str = string.gsub(str, "'", "&apos;")
    return str
end

--- Closes the Atlas Preview UI.
function closeAtlasPreviewUI(player_obj, value, id)
    UI.setAttribute("atlasPreviewPanel", "active", "false")
    UI.setAttribute("atlasPreviewPanel", "visibility", "")
    log("Atlas Preview UI closed.")
end

--- Handles clicks on the site preview buttons.
-- Also closes the UI after a button click.
function handleSiteButtonClick(player_obj, value, id)
    local siteName = (id == "site1Button" and siteNames[1]) or (id == "site2Button" and siteNames[2]) or "Unknown Site"
    if player_obj then
        local message = player_obj.color .. " explored the " .. siteName .. "."
        printToAll(message)
        log(message)
    end
    retrieve(nil, nil, nil, (id == "site1Button" and 0 or 1), false)
    
    
    -- Close the UI after a button click
    closeAtlasPreviewUI(player_obj)
end

--- Displays the Atlas Box Preview UI for exactly two sites.
function showPreviewUI(player_color, imageAndAttachments)
    if not player_color or not Player[player_color] then
        log("showPreviewUI Error: Invalid player_color: " .. tostring(player_color))
        return
    end

    local scriptGuid = self.getGUID() 

    local panelWidth = 940
    local panelHeight = 540

        -- Prepare Custom Assets
    local customAssets = UI.getCustomAssets()
    ----------------------------------------------------------------
    -- 1. helper to build the attachment ribbon for one site
    ----------------------------------------------------------------
    local function buildRibbon(siteIndex, edificeCnt, relicCnt)

        local ribbon = [[
            <HorizontalLayout spacing="15" minheight="10" padding="20 20 0 0"
                            childAlignment="LowerCenter">]]

        for _ = 1, edificeCnt do
            ribbon = ribbon .. [[
                <Image image="halfDenizen" height="100" minHeight="100" preserveAspect="true"/>]]
        end
        for _ = 1, relicCnt do
            ribbon = ribbon .. [[
                <Image image="relicBack" height="100" minHeight="100" preserveAspect="true"/>]]
        end
        return ribbon .. [[</HorizontalLayout>]]
    end


    ----------------------------------------------------------------
    -- 2. iterate over the two sites and build everything on the fly
    ----------------------------------------------------------------
    local siteXmlBlocks = {}   -- holds the finished XML for each site
    siteNames = {}             -- holds the names of the sites

    for i, site in ipairs(imageAndAttachments) do
        local name  = site.object.getName()
        table.insert(siteNames, name)  -- store the name for later use
        local url   = site.image

        -- add the picture to the custom-asset list once
        local exists = false
        for _, asset in ipairs(customAssets) do
            if asset.name == name then exists = true break end
        end
        if not exists then table.insert(customAssets, {name = name, url = url}) end

        -- build this site’s ribbon & outer block
        local ribbon  = buildRibbon(i, site.edificeCount or 0, site.relicCount or 0)

        local siteXml = string.format([[
            <VerticalLayout id="site%dContainer" spacing="0" width="420"
                            childForceExpandWidth="false" childAlignment="LowerCenter">

                <Panel minWidth="420" height="0" rectAlignment="LowerCenter">
                    <Panel width="420" id="site%dRibbon"
                        rectAlignment="LowerCenter" offsetXY="0 -360" height="36">%s</Panel>
                </Panel>

                <Image  id="site%dImage" image="%s" minWidth="435" preserveAspect="true"/>

                <Panel minHeight="70"/>

                <Button id="site%dButton" text="Explore %s"
                        onClick="%s/handleSiteButtonClick"
                        minWidth="435" fontSize="20" minHeight="80"/>
            </VerticalLayout>
        ]], i, i, ribbon, i, name, i, name, scriptGuid)

        table.insert(siteXmlBlocks, siteXml)
    end

    -- push custom assets once
    UI.setCustomAssets(customAssets)
    for _ = 1, 10 do coroutine.yield(0) end   -- small wait for images

    ----------------------------------------------------------------
    -- 3. build the main window with both site blocks injected
    ----------------------------------------------------------------
    local ui_xml = string.format([[
        <Defaults>
            <Text fontStyle="Bold" color="#E0E0E0FF" resizeTextMinSize="10"
                horizontalOverflow="Overflow" verticalOverflow="Overflow"/>
            <Button color="#4CAF50FF" textColor="#FFFFFFFF" fontStyle="Bold"
                    hoverColor="#5CB85CFF" pressColor="#449D44FF"/>
        </Defaults>

        <Panel id="atlasPreviewPanel" rectAlignment="MiddleCenter"
            width="%d" height="%d" color="rgba(0,0,0,0.97)" active="true"
            returnEscKey="true" onReturn="%s/closeAtlasPreviewUI"
            padding="15 15 10 15">

            <VerticalLayout width="100%%" height="100%%" spacing="10">
                <Panel minHeight="50" width="100%%">
                    <Text text="Pick a Site to Explore" fontSize="32" alignment="MiddleCenter" minHeight="200"/>
                    <Button id="closeAtlasPreviewButton" text="X"
                            onClick="%s/closeAtlasPreviewUI"
                            width="40" height="40" rectAlignment="UpperRight" offsetXY="-5 5"
                            color="#D9534FFF" hoverColor="#C9302CFF" pressColor="#AC2925FF"
                            fontSize="18"/>
                </Panel>

                <HorizontalLayout id="siteHolderLayout" height="400"
                                childAlignment="Bottom">
                    %s
                </HorizontalLayout>
            </VerticalLayout>
        </Panel>
    ]], panelWidth, panelHeight, scriptGuid, scriptGuid,
    table.concat(siteXmlBlocks, "\n"))

    UI.setXml(ui_xml)
    UI.setAttribute("atlasPreviewPanel", "visibility", player_color)
    UI.setAttribute("atlasPreviewPanel", "active", "true")
    log("Atlas Preview UI shown to player: "..player_color)
end
