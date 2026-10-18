zPie = CreateFrame("Frame", "zPieCoreFrame", UIParent)
zPie.TITLE = "|cffc77dffz|rPie"
zPie.rings = {}
zPie.currentRing = nil
zPie.hoveredSlice = nil
zPie.activeDegree = nil
zPie.centerX = 0
zPie.centerY = 0
zPie.BTN_SIZE = 40
zPie.DEADZONE = 18
zPie.RAID_MARKER_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
zPie.RAID_MARKERS = {
    { name = "Skull",    markerIndex = 8 },
    { name = "Cross",    markerIndex = 7 },
    { name = "Square",   markerIndex = 6 },
    { name = "Moon",     markerIndex = 5 },
    { name = "Triangle", markerIndex = 4 },
    { name = "Diamond",  markerIndex = 3 },
    { name = "Circle",   markerIndex = 2 },
    { name = "Star",     markerIndex = 1 },
}

zPie.TAP_THRESHOLD = 0.20
zPie.openTime = 0
zPie.activeSlots = {}
zPie.spellCache = {}
zPie.pendingItem = nil
zPie.updateDriver = CreateFrame("Frame", "zPieUpdateDriver", UIParent)
zPie.updateDriver:Hide()

function zPie:RefreshUpdateDriver()
    if self.currentRing or self.pendingItem then
        self.updateDriver:Show()
    else
        self.updateDriver:Hide()
    end
end

BINDING_HEADER_ZSUITE = "zSuite"
for i = 1, 10 do
    setglobal("BINDING_NAME_ZPIE_RING_" .. i, zPie.TITLE .. ": Ring " .. i)
end

zPie.arrowOffsets = {
    ["Interface\\Minimap\\MinimapArrow"] = 0,                             
    ["Interface\\Minimap\\ROTATING-MINIMAPGUIDEARROW"] = 0,               
    ["Interface\\MoneyFrame\\Arrow-Right-Up"] = math.pi / 2,              
    ["Interface\\ChatFrame\\ChatFrameExpandArrow"] = math.pi / 2,         
}

zPieScanner = CreateFrame("GameTooltip", "zPieScanner", UIParent, "GameTooltipTemplate")
zPieScanner:SetOwner(UIParent, "ANCHOR_NONE")

function zPie:MigrateLegacyBindings()
    local bindingsChanged = false
    for i = 1, 10 do
        local oldCommand = "AUTO" .. "PIE_RING_" .. i
        local newCommand = "ZPIE_RING_" .. i
        local key1, key2 = GetBindingKey(oldCommand)
        if key1 then
            SetBinding(key1, newCommand)
            bindingsChanged = true
        end
        if key2 then
            SetBinding(key2, newCommand)
            bindingsChanged = true
        end
    end

    if bindingsChanged then
        SaveBindings(GetCurrentBindingSet())
    end
end

function zPie:CreateRingData(index, name, items)
    return {
        name = name or ("Ring " .. index),
        anchor = "MOUSE",
        items = items or {},
        radius = 75,
        tapBehavior = "FIRST",
    }
end

function zPie:CreateRaidMarkerItems()
    local items = {}
    for i, marker in ipairs(self.RAID_MARKERS) do
        items[i] = {
            name = marker.name,
            icon = self.RAID_MARKER_TEXTURE,
            type = "RAID_MARKER",
            markerIndex = marker.markerIndex,
        }
    end
    return items
end

function zPie:GetRingCount()
    if not zPieDB then return 10 end
    return math.max(10, tonumber(zPieDB.ringCount) or 10)
end

function zPie:CreateRing(name, items)
    if not zPieDB then self:SanitizeDB() end
    local index = self:GetRingCount() + 1
    zPieDB[index] = self:CreateRingData(index, name, items)
    zPieDB.ringCount = index

    if self.selectionTooltip then
        self:InitButtons(index, index)
    end
    return index
end

-- zPieDB remains the active settings table for compatibility with existing code.
-- The account store owns each character table; legacy data is copied before sanitizing.
function zPie:CopyProfile(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, entry in pairs(value) do copy[key] = self:CopyProfile(entry) end
    return copy
end

function zPie:InitializeProfiles()
    local name, realm = UnitName("player"), GetRealmName()
    if not name or name == "Unknown" or not realm or realm == "" then return false end
    local key = name .. " - " .. realm
    if not zPieProfilesDB then
        zPieProfilesDB = { version = 1, characters = {}, saved = {} }
        if type(zPieDB) == "table" then
            zPieProfilesDB.legacyBackup = self:CopyProfile(zPieDB)
            zPieProfilesDB.characters[key] = self:CopyProfile(zPieDB)
        end
    end
    zPieProfilesDB.characters = zPieProfilesDB.characters or {}
    zPieProfilesDB.saved = zPieProfilesDB.saved or {}
    self.characterProfileKey = key
    if not zPieProfilesDB.characters[key] then zPieProfilesDB.characters[key] = {} end
    zPieDB = zPieProfilesDB.characters[key]
    return true
end

function zPie:SaveProfile(name, overwrite)
    if not self.characterProfileKey or not name then return nil end
    name = string.gsub(name, "^%s*(.-)%s*$", "%1")
    if name == "" then return nil end
    if zPieProfilesDB.saved[name] and not overwrite then return nil, "exists" end
    zPieProfilesDB.saved[name] = self:CopyProfile(zPieDB)
    return name
end

function zPie:LoadProfile(kind, key)
    if not self.characterProfileKey or self.currentRing then return false end
    local source
    if kind == "saved" then source = zPieProfilesDB.saved[key]
    elseif kind == "character" then source = zPieProfilesDB.characters[key]
    elseif kind == "legacy" then source = zPieProfilesDB.legacyBackup end
    if not source then return false end
    local replacement = self:CopyProfile(source)
    -- Automatic recovery snapshots must never overwrite an earlier backup.
    local backupBase = "Before load - " .. self.characterProfileKey
    local backupName, suffix = backupBase, 2
    while zPieProfilesDB.saved[backupName] do
        backupName = backupBase .. " (" .. suffix .. ")"
        suffix = suffix + 1
    end
    self:SaveProfile(backupName)
    zPieDB = replacement
    zPieProfilesDB.characters[self.characterProfileKey] = zPieDB
    self:SanitizeDB()
    self:InitButtons()
    self:RefreshDBIcons()
    return true
end

function zPie:SanitizeDB()
    if not zPieDB then zPieDB = {} end
    if not zPieDB.arrowStyle then zPieDB.arrowStyle = "Interface\\Minimap\\MinimapArrow" end
    if not zPieDB.arrowBehavior then zPieDB.arrowBehavior = "SMOOTH" end
    if zPieDB.showSelectionNames == nil then zPieDB.showSelectionNames = true end

    local ringCount = tonumber(zPieDB.ringCount) or 10
    for key in pairs(zPieDB) do
        if type(key) == "number" and key > ringCount then ringCount = key end
    end
    ringCount = math.max(10, math.floor(ringCount))
    zPieDB.ringCount = ringCount

    for i = 1, ringCount do
        if not zPieDB[i] then
            zPieDB[i] = self:CreateRingData(i)
        end
        if not zPieDB[i].items then zPieDB[i].items = {} end
        if not zPieDB[i].radius then zPieDB[i].radius = 75 end
        if not zPieDB[i].tapBehavior then zPieDB[i].tapBehavior = "FIRST" end
    end

    -- Version 1 briefly placed this default in an empty original ring. Move it
    -- out to its own appended ring if that build was loaded before this one.
    local markerRingVersion = tonumber(zPieDB.raidMarkerRingVersion) or 0
    if markerRingVersion < 2 then
        local markerItems = nil
        if markerRingVersion == 1 then
            for i = 1, ringCount do
                local ring = zPieDB[i]
                if ring and ring.name == "Raid Marks" and ring.items and
                   ring.items[1] and ring.items[1].type == "RAID_MARKER" then
                    markerItems = ring.items
                    zPieDB[i] = self:CreateRingData(i)
                    break
                end
            end
        end

        ringCount = ringCount + 1
        zPieDB[ringCount] = self:CreateRingData(
            ringCount, "Raid Marks", markerItems or self:CreateRaidMarkerItems())
        zPieDB.ringCount = ringCount
        zPieDB.raidMarkerRingIndex = ringCount
        zPieDB.raidMarkerRingVersion = 2
    end

    -- Version 3 places Skull at twelve o'clock and proceeds clockwise in
    -- reverse marker order: Cross, Square, Moon, Triangle, Diamond, Circle, Star.
    if markerRingVersion < 3 then
        local markerRingIndex = tonumber(zPieDB.raidMarkerRingIndex)
        if not markerRingIndex or not zPieDB[markerRingIndex] then
            for i = 1, zPieDB.ringCount do
                local ring = zPieDB[i]
                if ring and ring.name == "Raid Marks" then
                    markerRingIndex = i
                    break
                end
            end
        end

        if markerRingIndex and zPieDB[markerRingIndex] then
            zPieDB[markerRingIndex].items = self:CreateRaidMarkerItems()
            zPieDB.raidMarkerRingIndex = markerRingIndex
        end
        zPieDB.raidMarkerRingVersion = 3
    end
end

function zPie:CacheSpells()
    local tempCache = {}
    local i = 1
    local count = 0
    while true do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL or "spell")
        if not spellName then break end
        tempCache[spellName] = i
        i = i + 1
        count = count + 1
    end
    
    if count > 0 then
        self.spellCache = tempCache
    end
end

function zPie:RefreshDBIcons()
    if not zPieDB then return end
    for r = 1, self:GetRingCount() do
        if zPieDB[r] and zPieDB[r].items then
            for s = 1, 8 do
                local item = zPieDB[r].items[s]
                if item and item.name then
                    if item.type == "SPELL_OR_ITEM" and self.spellCache[item.name] then
                        local tex = GetSpellTexture(self.spellCache[item.name], BOOKTYPE_SPELL or "spell")
                        if tex and tex ~= "" then
                            item.icon = tex
                        end
                    elseif item.type == "MACRO" or item.type == "SUPER_MACRO" then
                        local idx = item.macroIndex or GetMacroIndexByName(item.name)
                        if idx and idx > 0 then
                            local currentName, tex = GetMacroInfo(idx)
                            if currentName and currentName ~= "" then
                                -- Keep item.name in sync: if the macro was renamed externally, follow it
                                if currentName ~= item.name then
                                    item.name = currentName
                                end
                            end
                            if tex and tex ~= "" then
                                item.icon = tex
                            end
                            item.macroIndex = idx
                            item.type = "MACRO"
                        elseif type(GetSuperMacroInfo) == "function" and
                               GetSuperMacroInfo(item.name, "body") then
                            local tex = GetSuperMacroInfo(item.name, "texture")
                            if tex and tex ~= "" then item.icon = tex end
                            item.macroIndex = nil
                            item.type = "SUPER_MACRO"
                        end
                    end
                end
            end
        end
    end
end

function zPie:GetBufferSlot()
    for i = 120, 73, -1 do
        if not HasAction(i) then return i end
    end
    return 120
end

local function IsPlayerBuffActive(iconTexture)
    if not iconTexture or iconTexture == "" then return false end

    for i = 1, 32 do
        local buffIcon = UnitBuff("player", i)
        if not buffIcon then break end
        if buffIcon == iconTexture then return true end
    end

    return false
end

local function IsSkillActive(iconTexture)
    if not iconTexture or iconTexture == "" then return false end
    
    local numForms = GetNumShapeshiftForms()
    if numForms and numForms > 0 then
        for i = 1, numForms do
            local icon, _, isActive = GetShapeshiftFormInfo(i)
            if isActive and icon == iconTexture then return true end
        end
    end

    if type(GetTrackingTexture) == "function" then
        local trackTex = GetTrackingTexture()
        if trackTex and trackTex ~= "" and trackTex == iconTexture then
            return true
        end
    end
    
    return IsPlayerBuffActive(iconTexture)
end

local function SetRotatedTexCoords(tex, angle)
    local cosA = math.cos(angle)
    local sinA = math.sin(angle)
    
    local function rotate(x, y)
        x = x - 0.5
        y = y - 0.5
        return (x * cosA - y * sinA) + 0.5, (x * sinA + y * cosA) + 0.5
    end
    
    local ULx, ULy = rotate(0, 0)
    local LLx, LLy = rotate(0, 1)
    local URx, URy = rotate(1, 0)
    local LRx, LRy = rotate(1, 1)
    
    tex:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
end

function zPie:InitButtons(firstRing, lastRing)
    if not self.selectionTooltip then
    self.selectionTooltip = CreateFrame("Frame", "zPieSelectionTooltip", UIParent)
    self.selectionTooltip:SetHeight(18)
    self.selectionTooltip:SetFrameStrata("TOOLTIP")
    self.selectionTooltip:SetClampedToScreen(true)
    self.selectionTooltip:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    self.selectionTooltip:SetBackdropColor(0.03, 0.03, 0.03, 0.6)
    self.selectionTooltip:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.6)

    local selectionText = self.selectionTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selectionText:SetPoint("CENTER", self.selectionTooltip, "CENTER", 0, 0)
    self.selectionTooltip.text = selectionText
    self.selectionTooltip:Hide()

    self.compassFrame = CreateFrame("Frame", "zPieCompassFrame", UIParent)
    self.compassFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.compassFrame.arrow = self.compassFrame:CreateTexture(nil, "BACKGROUND")
    self.compassFrame.arrow:SetWidth(32)
    self.compassFrame.arrow:SetHeight(32)
    self.compassFrame.arrow:Hide()
    end

    firstRing = firstRing or 1
    lastRing = lastRing or self:GetRingCount()
    for r = firstRing, lastRing do
        if not self.rings[r] then
        self.rings[r] = {}
        for s = 1, 8 do
            local name = "zPieRing" .. r .. "Slot" .. s
            local btn = CreateFrame("Button", name, UIParent)
            btn:SetWidth(self.BTN_SIZE)
            btn:SetHeight(self.BTN_SIZE)
            btn:SetFrameStrata("FULLSCREEN_DIALOG")
            btn:EnableMouse(false)
            btn:Hide()

            local icon = btn:CreateTexture(name.."Icon", "BACKGROUND")
            icon:SetAllPoints(btn)
            btn.icon = icon

            local border = btn:CreateTexture(name.."Border", "BORDER")
            border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
            border:SetWidth(self.BTN_SIZE * 1.65)
            border:SetHeight(self.BTN_SIZE * 1.65)
            border:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.border = border

            local cd = CreateFrame("Model", name.."CD", btn, "CooldownFrameTemplate")
            cd:SetAllPoints(btn)
            btn.cd = cd

            local count = btn:CreateFontString(name.."Count", "OVERLAY", "NumberFontNormal")
            count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
            btn.count = count

            local activeTex = btn:CreateTexture(name.."Active", "OVERLAY")
            activeTex:SetTexture("Interface\\Buttons\\CheckButtonHilight")
            activeTex:SetBlendMode("ADD")
            activeTex:SetAllPoints(btn)
            activeTex:Hide()
            btn.activeTex = activeTex

            local hl = btn:CreateTexture(name.."HL", "OVERLAY")
            hl:SetTexture("Interface\\Buttons\\CheckButtonHilight")
            hl:SetBlendMode("ADD")
            hl:SetAllPoints(btn)
            hl:Hide()
            btn.hl = hl

            local equippedOutline = {}

            local equippedTop = btn:CreateTexture(nil, "OVERLAY")
            equippedTop:SetTexture(0.2, 1, 0.2, 1)
            equippedTop:SetHeight(1)
            equippedTop:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
            equippedTop:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
            table.insert(equippedOutline, equippedTop)

            local equippedBottom = btn:CreateTexture(nil, "OVERLAY")
            equippedBottom:SetTexture(0.2, 1, 0.2, 1)
            equippedBottom:SetHeight(1)
            equippedBottom:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
            equippedBottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
            table.insert(equippedOutline, equippedBottom)

            local equippedLeft = btn:CreateTexture(nil, "OVERLAY")
            equippedLeft:SetTexture(0.2, 1, 0.2, 1)
            equippedLeft:SetWidth(1)
            equippedLeft:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
            equippedLeft:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
            table.insert(equippedOutline, equippedLeft)

            local equippedRight = btn:CreateTexture(nil, "OVERLAY")
            equippedRight:SetTexture(0.2, 1, 0.2, 1)
            equippedRight:SetWidth(1)
            equippedRight:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
            equippedRight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
            table.insert(equippedOutline, equippedRight)

            for _, outlineTexture in ipairs(equippedOutline) do
                outlineTexture:Hide()
            end
            btn.equippedOutline = equippedOutline
            
            local arrow = btn:CreateTexture(name.."Arrow", "OVERLAY")
            arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
            arrow:SetWidth(32)
            arrow:SetHeight(32)
            arrow:Hide()
            btn.arrow = arrow

            self.rings[r][s] = btn
        end
        end
    end
end

function zPie:HideAll()
    for r, ringButtons in pairs(self.rings) do
        for s = 1, 8 do
            ringButtons[s]:Hide()
            ringButtons[s].hl:Hide()
            ringButtons[s].activeTex:Hide()
            ringButtons[s].arrow:Hide()
            for _, outlineTexture in ipairs(ringButtons[s].equippedOutline) do
                outlineTexture:Hide()
            end
        end
    end
    self.currentRing = nil
    self.hoveredSlice = nil

    if self.selectionTooltip then self.selectionTooltip:Hide() end
    
    if self.compassFrame then
        self.compassFrame.arrow:Hide()
        self.compassFrame:Hide()
    end
    self.activeDegree = nil
    self:Hide()
    self:RefreshUpdateDriver()
end

function zPie:ShowSelectionTooltip(btn, itemData)
    local tooltip = self.selectionTooltip
    if not tooltip or not btn or not itemData or not itemData.name or
       not zPieDB.showSelectionNames then
        if tooltip then tooltip:Hide() end
        return
    end

    tooltip.text:SetText(itemData.name)
    tooltip:SetWidth(math.max(40, tooltip.text:GetStringWidth() + 12))
    tooltip:ClearAllPoints()
    tooltip:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY)

    tooltip:Show()
end

function zPie:GetMacroBody(itemData)
    if not itemData or not itemData.name then return nil end

    if itemData.type == "SUPER_MACRO" and type(GetSuperMacroInfo) == "function" then
        return GetSuperMacroInfo(itemData.name, "body")
    end

    local macroIndex = itemData.macroIndex or GetMacroIndexByName(itemData.name)
    if macroIndex and macroIndex > 0 then
        local _, _, body = GetMacroInfo(macroIndex)
        return body
    end

    if type(GetSuperMacroInfo) == "function" then
        return GetSuperMacroInfo(itemData.name, "body")
    end
end

function zPie:GetMacroTooltipArg(itemData)
    local body = self:GetMacroBody(itemData)
    if not body then return nil end

    -- Prefix a newline so the same pattern handles the first and later lines.
    local _, _, arg = string.find("\n" .. body, "\n%s*#showtooltip%s+([^\r\n]+)")
    if not arg then return nil end

    arg = string.gsub(arg, "^%s+", "")
    arg = string.gsub(arg, "%s+$", "")
    if arg == "" then return nil end
    return arg
end

function zPie:GetDisplayLookupName(itemData)
    if not itemData or not itemData.name then return nil end
    if itemData.type == "MACRO" or itemData.type == "SUPER_MACRO" then
        return self:GetMacroTooltipArg(itemData)
    end
    return itemData.name
end

function zPie:GetItemTexture(itemName)
    if not itemName then return nil end

    if type(CleveRoids) == "table" and type(CleveRoids.GetItem) == "function" then
        local item = CleveRoids.GetItem(itemName)
        if item and item.texture and item.texture ~= "" then return item.texture end
    end

    for invSlot = 0, 19 do
        local link = GetInventoryItemLink("player", invSlot)
        if self:ItemLinkMatches(link, itemName) then
            return GetInventoryItemTexture("player", invSlot)
        end
    end

    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if self:ItemLinkMatches(link, itemName) then
                local texture = GetContainerItemInfo(bag, slot)
                return texture
            end
        end
    end
end

function zPie:GetResolvedTexture(lookupName)
    if not lookupName then return nil end

    if self.spellCache and self.spellCache[lookupName] then
        local texture = GetSpellTexture(self.spellCache[lookupName], BOOKTYPE_SPELL or "spell")
        if texture and texture ~= "" then return texture end
    end

    if type(CleveRoids) == "table" and type(CleveRoids.GetSpell) == "function" then
        local spell = CleveRoids.GetSpell(lookupName)
        if spell and spell.texture and spell.texture ~= "" then return spell.texture end
    end

    return self:GetItemTexture(lookupName)
end

function zPie:GetIcon(itemData)
    if not itemData or not itemData.name then return "Interface\\Icons\\INV_Misc_QuestionMark" end

    if itemData.type == "RAID_MARKER" then
        return itemData.icon or self.RAID_MARKER_TEXTURE
    end

    local lookupName = self:GetDisplayLookupName(itemData)
    local resolvedTexture = self:GetResolvedTexture(lookupName)
    if resolvedTexture then return resolvedTexture end

    if itemData.type == "MACRO" then
        local idx = itemData.macroIndex or GetMacroIndexByName(itemData.name)
        if idx and idx > 0 then
            local _, tex = GetMacroInfo(idx)
            if tex and tex ~= "" and
               string.lower(tex) ~= "interface\\icons\\inv_misc_questionmark" then
                return tex
            end
        end
    elseif itemData.type == "SUPER_MACRO" and type(GetSuperMacroInfo) == "function" then
        local tex = GetSuperMacroInfo(itemData.name, "texture")
        if tex and tex ~= "" then return tex end
    end
    
    if itemData.icon and itemData.icon ~= "" then
        return itemData.icon
    end
    
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function zPie:SetIconTexture(texture, itemData, inset)
    if not texture then return end

    texture:SetTexture(self:GetIcon(itemData))
    if itemData and itemData.type == "RAID_MARKER" and itemData.markerIndex then
        local markerIndex = tonumber(itemData.markerIndex) or 1
        if type(SetRaidTargetIconTexture) == "function" then
            SetRaidTargetIconTexture(texture, markerIndex)
        else
            local zeroIndex = markerIndex - 1
            local column = zeroIndex - (math.floor(zeroIndex / 4) * 4)
            local top = math.floor(zeroIndex / 4) * 0.25
            local left = column * 0.25
            texture:SetTexCoord(left, left + 0.25, top, top + 0.25)
        end
    else
        local crop = inset or 0
        texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
    end
end

function zPie:GetActionData(itemData)
    local count, start, duration, enable = "", 0, 0, 0
    if not itemData or not itemData.name then return count, start, duration, enable end
    if itemData.type == "RAID_MARKER" then return count, start, duration, enable end

    local lookupName = self:GetDisplayLookupName(itemData)
    if not lookupName then return count, start, duration, enable end

    if self.spellCache[lookupName] then
        start, duration, enable = GetSpellCooldown(self.spellCache[lookupName], BOOKTYPE_SPELL or "spell")
        return count, start, duration, enable
    end

    local itemCount = 0
    local isItem = false

    for invSlot = 1, 19 do
        local link = GetInventoryItemLink("player", invSlot)
        if self:ItemLinkMatches(link, lookupName) then
            isItem = true
            if start == 0 then
                start, duration, enable = GetInventoryItemCooldown("player", invSlot)
            end
        end
    end

    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if self:ItemLinkMatches(link, lookupName) then
                isItem = true
                local _, cnt = GetContainerItemInfo(bag, slot)
                itemCount = itemCount + (cnt or 1)
                if start == 0 then
                    start, duration, enable = GetContainerItemCooldown(bag, slot)
                end
            end
        end
    end
    
    if isItem and itemCount > 1 then count = itemCount end
    return count, start, duration, enable
end

function zPie:ItemLinkMatches(link, itemName)
    if not link or not itemName then return false end

    local _, _, linkedName = string.find(link, "%[(.-)%]")
    return linkedName == itemName
end

function zPie:IsItemEquipped(itemData)
    local lookupName = self:GetDisplayLookupName(itemData)
    if not lookupName then return false end

    for invSlot = 0, 19 do
        local link = GetInventoryItemLink("player", invSlot)
        if self:ItemLinkMatches(link, lookupName) then
            return true
        end
    end

    return false
end

function zPie:ExecuteMacro(itemData)
    local macroIndex = itemData.macroIndex
    if macroIndex then
        local currentName = GetMacroInfo(macroIndex)
        if currentName ~= itemData.name then macroIndex = nil end
    end
    if not macroIndex then
        macroIndex = GetMacroIndexByName(itemData.name)
        if not macroIndex or macroIndex == 0 then macroIndex = nil end
    end

    if macroIndex then
        itemData.macroIndex = macroIndex
        itemData.type = "MACRO"
        if type(RunMacro) == "function" then
            RunMacro(macroIndex)
            return true
        elseif type(SuperMacro_RunMacro) == "function" then
            SuperMacro_RunMacro(macroIndex)
            return true
        end
    end

    if type(GetSuperMacroInfo) == "function" and
       GetSuperMacroInfo(itemData.name, "body") then
        itemData.macroIndex = nil
        itemData.type = "SUPER_MACRO"
        if type(RunSuperMacro) == "function" then
            RunSuperMacro(itemData.name)
            return true
        end
    end

    if type(CleveRoids) == "table" and
       type(CleveRoids.ExecuteMacroByName) == "function" then
        CleveRoids.ExecuteMacroByName(macroIndex or itemData.name)
        return true
    end

    if type(RunMacro) == "function" then
        RunMacro(macroIndex or itemData.name)
        return true
    end

    return false
end

function zPie:FindItem(itemName)
    -- Prefer an equipped copy so usable equipment (such as trinkets) activates
    -- instead of resolving to another copy in the bags.
    for invSlot = 0, 19 do
        local link = GetInventoryItemLink("player", invSlot)
        if self:ItemLinkMatches(link, itemName) then
            return "INVENTORY", invSlot
        end
    end

    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if self:ItemLinkMatches(link, itemName) then
                return "BAG", bag, slot
            end
        end
    end
end

function zPie:IsEquippableItemLink(link)
    if not link then return false end

    if type(IsEquippableItem) == "function" and IsEquippableItem(link) then
        return true
    end

    local _, _, itemId = string.find(link, "item:(%d+)")
    local nampowerAPI = CleveRoids and CleveRoids.NampowerAPI
    if itemId and type(nampowerAPI) == "table" and
       type(nampowerAPI.GetItemEquipSlot) == "function" then
        local equipSlot = nampowerAPI.GetItemEquipSlot(tonumber(itemId))
        if equipSlot then return true end
    end

    local _, _, _, _, _, _, _, _, equipLocation = GetItemInfo(link)
    return equipLocation and equipLocation ~= ""
end

function zPie:UseItem(itemData, location, first, second)
    if type(CloseStackSplitFrame) == "function" then CloseStackSplitFrame() end
    if CursorHasItem and CursorHasItem() then ClearCursor() end

    -- Equipped items should be activated from their exact inventory slot.
    if location == "INVENTORY" then
        UseInventoryItem(first)
        return true
    end

    -- Equippable bag items should be equipped, not sent through the consumable
    -- item API. Auto-equip also handles items with multiple valid slots.
    local link = GetContainerItemLink(first, second)
    if self:IsEquippableItemLink(link) then
        if type(PickupContainerItem) == "function" and
           type(AutoEquipCursorItem) == "function" then
            PickupContainerItem(first, second)
            if not CursorHasItem or CursorHasItem() then
                AutoEquipCursorItem()
                return true
            end
        end

        if CursorHasItem and CursorHasItem() then ClearCursor() end
        UseContainerItem(first, second)
        return true
    end

    -- Nampower's target argument is optional, but some API wrappers forward an
    -- explicit nil as a second argument. The native function rejects that call,
    -- so invoke it directly with exactly one argument when it is available.
    if type(UseItemIdOrName) == "function" then
        local result = UseItemIdOrName(itemData.name)
        if result == 1 or result == true then return true end
    else
        local nampowerAPI = CleveRoids and CleveRoids.NampowerAPI
        if type(nampowerAPI) == "table" and
           type(nampowerAPI.UseItemIdOrName) == "function" then
            local result = nampowerAPI.UseItemIdOrName(itemData.name)
            if result == 1 or result == true then return true end
        end
    end

    if C_Item and type(C_Item.UseItemByName) == "function" then
        C_Item.UseItemByName(itemData.name)
        return true
    end

    -- Stock-client fallback. Delay only this path while Shift is held because
    -- UseContainerItem can otherwise split one potion from its stack.
    if IsShiftKeyDown() then
        self.pendingItem = itemData
        self:RefreshUpdateDriver()
        return true
    end

    UseContainerItem(first, second)
    return true
end

function zPie:TargetRaidMarker(markerIndex)
    if type(TargetUnit) ~= "function" then return false end

    if type(GetRaidTargetIndex) ~= "function" then return false end

    local function TryUnit(unit)
        -- Extended tokens can resolve differently across client extensions.
        -- Never target an unverified token or accept an unrelated target.
        if not UnitExists(unit) or GetRaidTargetIndex(unit) ~= markerIndex then
            return false
        end
        local hadTarget = UnitExists("target")
        TargetUnit(unit)
        if UnitExists("target") and GetRaidTargetIndex("target") == markerIndex then
            return true
        end
        if hadTarget and type(TargetLastTarget) == "function" then
            TargetLastTarget()
        elseif not hadTarget and type(ClearTarget) == "function" then
            ClearTarget()
        end
        return false
    end

    if TryUnit("mark" .. markerIndex) then return true end

    if TryUnit("mouseover") or TryUnit("focus") or TryUnit("targettarget") or
       TryUnit("pettarget") then
        return true
    end

    for i = 1, 4 do
        if TryUnit("party" .. i) or TryUnit("party" .. i .. "target") then
            return true
        end
    end

    for i = 1, 40 do
        if TryUnit("raid" .. i) or TryUnit("raid" .. i .. "target") or
           TryUnit("nameplate" .. i) then
            return true
        end
    end

    return false
end

function zPie:CanSetRaidMarker()
    local raidMembers = type(GetNumRaidMembers) == "function" and GetNumRaidMembers() or 0
    if raidMembers > 0 then
        local isLeader = type(IsRaidLeader) == "function" and IsRaidLeader()
        local isOfficer = type(IsRaidOfficer) == "function" and IsRaidOfficer()
        return (isLeader or isOfficer) and true or false
    end

    local partyMembers = type(GetNumPartyMembers) == "function" and GetNumPartyMembers() or 0
    if partyMembers > 0 then
        if type(UnitIsPartyLeader) == "function" then
            return UnitIsPartyLeader("player") and true or false
        elseif type(IsPartyLeader) == "function" then
            return IsPartyLeader() and true or false
        end
        return false
    end

    return true
end

function zPie:ShowRaidMarkerTargetError()
    if UIErrorsFrame then
        UIErrorsFrame:AddMessage("No unit has that raid marker.", 1.0, 0.1, 0.1, 1.0)
    end
end

function zPie:ApplyRaidMarker(itemData)
    local markerIndex = itemData and tonumber(itemData.markerIndex)
    if not markerIndex or markerIndex < 1 or markerIndex > 8 then return false end

    -- Without marking permission, every marker slice acts as target-by-marker,
    -- even when the player currently has some other unit targeted.
    if not UnitExists("target") or not self:CanSetRaidMarker() then
        if self:TargetRaidMarker(markerIndex) then return true end
        self:ShowRaidMarkerTargetError()
        return false
    end

    if type(SetRaidTarget) ~= "function" then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("Raid markers are unavailable.", 1.0, 0.1, 0.1, 1.0)
        end
        return false
    end

    local currentMarker = nil
    if type(GetRaidTargetIndex) == "function" then
        currentMarker = GetRaidTargetIndex("target")
    end

    local newMarker = markerIndex
    if currentMarker == markerIndex then newMarker = 0 end
    SetRaidTarget("target", newMarker)

    -- Marker updates can arrive asynchronously. Do not interpret the old
    -- marker as a failure and switch away from the unit we just marked.
    return true
end

function zPie:IsProtectedClassToggleActive(spellName)
    if not spellName or not self.spellCache then return false end

    local _, classToken = UnitClass("player")
    local lowerName = string.lower(spellName)
    local shouldProtect = false

    if classToken == "HUNTER" and string.find(lowerName, "^aspect of the ") then
        shouldProtect = lowerName ~= "aspect of the cheetah" and
            lowerName ~= "aspect of the pack"
    elseif classToken == "PALADIN" and string.find(lowerName, " aura$") then
        shouldProtect = true
    end

    if not shouldProtect then return false end

    local spellIndex = self.spellCache[spellName]
    local icon = spellIndex and GetSpellTexture(spellIndex, BOOKTYPE_SPELL or "spell")
    return IsPlayerBuffActive(icon)
end

function zPie:ExecuteAction(itemData)
    if not itemData or not itemData.name then return end

    if itemData.type == "RAID_MARKER" then
        self:ApplyRaidMarker(itemData)
    elseif itemData.type == "MACRO" or itemData.type == "SUPER_MACRO" then
        self:ExecuteMacro(itemData)
    else
        if self.spellCache[itemData.name] then
            if self:IsProtectedClassToggleActive(itemData.name) then return true end
            CastSpellByName(itemData.name)
            return
        end

        local location, first, second = self:FindItem(itemData.name)
        if not location then return end
        self:UseItem(itemData, location, first, second)
    end
end

function zPie:GetBindingKeyCode(binding)
    if not binding then return nil end

    local key = string.gsub(binding, "ALT%-", "")
    key = string.gsub(key, "CTRL%-", "")
    key = string.gsub(key, "SHIFT%-", "")
    local lowerKey = string.lower(key)

    if lowerKey == "`" or lowerKey == "~" or lowerKey == "tilde" then return 256 end

    if CleveRoids and CleveRoids.KEY_NAMES and CleveRoids.KEY_NAMES[lowerKey] then
        return CleveRoids.KEY_NAMES[lowerKey]
    end

    if string.len(key) == 1 then
        return string.byte(string.upper(key))
    end
end

function zPie:GetRingBinding(ringIndex)
    local binding = GetBindingKey("ZPIE_RING_" .. ringIndex)
    if binding then return binding end

    local ring = zPieDB and zPieDB[ringIndex]
    return ring and ring.binding or nil
end

function zPie:BindingMatchesKeyEvent(binding, keyCode, metaState)
    if not binding or self:GetBindingKeyCode(binding) ~= keyCode then return false end

    local expectedMeta = 0
    if string.find(binding, "SHIFT%-") then expectedMeta = expectedMeta + 1 end
    if string.find(binding, "CTRL%-") then expectedMeta = expectedMeta + 2 end
    if string.find(binding, "ALT%-") then expectedMeta = expectedMeta + 4 end
    return expectedMeta == (tonumber(metaState) or 0)
end

function zPie:OpenRing(ringIndex)
    ringIndex = tonumber(ringIndex)
    if not ringIndex or not zPieDB or not zPieDB[ringIndex] then return end
    if not self.rings[ringIndex] then self:InitButtons(ringIndex, ringIndex) end

    self.openTime = GetTime()
    self.activeSlots = {}

    local bindStr = self:GetRingBinding(ringIndex)
    if bindStr then
        self.reqAlt = string.find(bindStr, "ALT%-") and true or false
        self.reqCtrl = string.find(bindStr, "CTRL%-") and true or false
        self.reqShift = string.find(bindStr, "SHIFT%-") and true or false
        local _, _, buttonNumber = string.find(bindStr, "BUTTON(%d+)")
        self.reqButton = buttonNumber and tonumber(buttonNumber) or nil
        self.reqKeyCode = self:GetBindingKeyCode(bindStr)
    else
        self.reqAlt, self.reqCtrl, self.reqShift = false, false, false
        self.reqButton = nil
        self.reqKeyCode = nil
    end

    local items = zPieDB[ringIndex].items or {}
    for s = 1, 8 do
        if items[s] and items[s].name and items[s].name ~= "" then
            table.insert(self.activeSlots, s)
        end
    end

    local total = table.getn(self.activeSlots)
    if total == 0 then return end

    self:HideAll()
    self.currentRing = ringIndex
    self:RefreshUpdateDriver()

    local ringData = zPieDB[ringIndex]
    local scale = UIParent:GetEffectiveScale()
    if ringData.anchor == "MOUSE" then
        local mx, my = GetCursorPosition()
        self.centerX = mx / scale
        self.centerY = my / scale
    else
        self.centerX = GetScreenWidth() / 2
        self.centerY = GetScreenHeight() / 2
    end

    local angleStep = (2 * math.pi) / total
    local radius = ringData.radius or 75
    local arrowTex = zPieDB.arrowStyle or "Interface\\Minimap\\MinimapArrow"
    local arrowBehavior = zPieDB.arrowBehavior or "SMOOTH"
    local arrowOffset = self.arrowOffsets[arrowTex] or 0

    if arrowTex == "NONE" then
        self.compassFrame:Hide()
    else
        if arrowBehavior == "SMOOTH" then
            self.compassFrame:Show()
            self.compassFrame.arrow:SetTexture(arrowTex)
            self.compassRadius = radius - 35
            self.compassArrowOffset = arrowOffset
        else
            self.compassFrame:Hide()
        end
    end

    for i, originalSlot in ipairs(self.activeSlots) do
        local btn = self.rings[ringIndex][originalSlot]
        local itemData = items[originalSlot]
        
        local angle = (math.pi / 2) - ((i - 1) * angleStep)
        local bx = self.centerX + (radius * math.cos(angle)) - (self.BTN_SIZE / 2)
        local by = self.centerY + (radius * math.sin(angle)) - (self.BTN_SIZE / 2)
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", bx, by)
        
        if arrowTex ~= "NONE" and arrowBehavior == "SNAP" then
            local compassRadius = radius - 35
            local ax = self.centerX + (compassRadius * math.cos(angle)) - 16
            local ay = self.centerY + (compassRadius * math.sin(angle)) - 16
            btn.arrow:ClearAllPoints()
            btn.arrow:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", ax, ay)
            local rotation = angle - (math.pi / 2) + arrowOffset
            SetRotatedTexCoords(btn.arrow, rotation)
            btn.arrow:SetTexture(arrowTex)
            btn.arrow:Hide()
        else
            btn.arrow:Hide()
        end
        
        local displayIcon = self:GetIcon(itemData)
        self:SetIconTexture(btn.icon, itemData, 0)

        local isEquipped = self:IsItemEquipped(itemData)
        for _, outlineTexture in ipairs(btn.equippedOutline) do
            if isEquipped then
                outlineTexture:Show()
            else
                outlineTexture:Hide()
            end
        end
        
        if IsSkillActive(displayIcon) then
            btn.activeTex:Show()
            btn.border:SetVertexColor(1, 0.85, 0)
        else
            btn.activeTex:Hide()
            btn.border:SetVertexColor(1, 1, 1)
        end
        
        local count, start, duration, enable = self:GetActionData(itemData)
        btn.count:SetText(count)
        if start and duration and duration > 0 then
            CooldownFrame_SetTimer(btn.cd, start, duration, enable)
            btn.cd:Show()
        else
            btn.cd:Hide()
        end

        btn:Show()
    end

    self:Show()
end

function zPie:IsItemAvailable(itemData, isCurrentlyActive)
    if not itemData or not itemData.name or itemData.name == "" then 
        return false 
    end

    if isCurrentlyActive then
        return false
    end

    if itemData.type == "RAID_MARKER" then
        return UnitExists("target") and true or false
    end

    local displayIcon = self:GetIcon(itemData)
    if table.getn(self.activeSlots) > 1 and IsSkillActive(displayIcon) then
        return false
    end

    if itemData.type ~= "MACRO" and itemData.type ~= "SUPER_MACRO" and not (self.spellCache and self.spellCache[itemData.name]) then
        local location = self:FindItem(itemData.name)
        if not location then
            return false
        end
    end

    if type(CleveRoids) == "table" and type(CleveRoids.GetCooldown) == "function" then
        local lookupName = self:GetDisplayLookupName(itemData) or itemData.name
        local cdExpiry = CleveRoids.GetCooldown(lookupName, true)
        if cdExpiry and cdExpiry > GetTime() then
            return false
        end
    end

    local _, start, duration = self:GetActionData(itemData)
    start = tonumber(start) or 0
    duration = tonumber(duration) or 0

    if start > 0 and duration > 1.5 then
        local rem = (start + duration) - GetTime()
        if rem > 0 then
            return false
        end
    end

    return true
end

function zPie:CloseRing()
    if not self.currentRing then return end

    local ringIndex = self.currentRing
    local elapsed = GetTime() - self.openTime
    local targetOriginalSlot = nil

    if (not self.hoveredSlice) and (elapsed <= self.TAP_THRESHOLD) then
        local tapBehavior = (zPieDB and zPieDB[ringIndex] and zPieDB[ringIndex].tapBehavior) or "FIRST"

        if tapBehavior == "NEXT_AVAILABLE" then
            local items = zPieDB[ringIndex].items
            local numActive = table.getn(self.activeSlots)

            if numActive > 0 then
                local activePos = nil
                for i, slot in ipairs(self.activeSlots) do
                    local itemData = items and items[slot]
                    if itemData then
                        local displayIcon = self:GetIcon(itemData)
                        if IsSkillActive(displayIcon) then
                            activePos = i
                            break
                        end
                    end
                end

                local startPos = (activePos and numActive > 1) and ((activePos % numActive) + 1) or 1

                for step = 0, numActive - 1 do
                    local pos = ((startPos - 1 + step) % numActive) + 1
                    local slot = self.activeSlots[pos]
                    local itemData = items and items[slot]
                    if itemData and self:IsItemAvailable(itemData, activePos == pos) then
                        targetOriginalSlot = slot
                        break
                    end
                end

                -- Everything on CD / unavailable: fall back to the first slot
                if not targetOriginalSlot and self.activeSlots[1] then
                    targetOriginalSlot = self.activeSlots[1]
                end
            end
        else
            -- FIRST (default): always use the first active slot
            if self.activeSlots[1] then targetOriginalSlot = self.activeSlots[1] end
        end
    elseif self.hoveredSlice then
        targetOriginalSlot = self.activeSlots[self.hoveredSlice]
    end

    self:HideAll()

    if targetOriginalSlot then
        local items = zPieDB[ringIndex].items
        if items and items[targetOriginalSlot] then
            self:ExecuteAction(items[targetOriginalSlot])
        end
    end
end

zPie.updateDriver:SetScript("OnUpdate", function()
    if zPie.pendingItem and not IsShiftKeyDown() then
        local itemData = zPie.pendingItem
        zPie.pendingItem = nil
        zPie:ExecuteAction(itemData)
    end

    if not zPie.currentRing then
        zPie:RefreshUpdateDriver()
        return
    end

    if (zPie.reqAlt and not IsAltKeyDown()) or
       (zPie.reqCtrl and not IsControlKeyDown()) or
       (zPie.reqShift and not IsShiftKeyDown()) or
       (zPie.reqButton and type(IsMouseButtonDown) == "function" and
        not IsMouseButtonDown(zPie.reqButton)) then
        zPie:CloseRing()
        return
    end

    local total = table.getn(zPie.activeSlots)
    if total == 0 then return end
    
    local arrowTex = zPieDB.arrowStyle or "Interface\\Minimap\\MinimapArrow"
    local arrowBehavior = zPieDB.arrowBehavior or "SMOOTH"

    local scale = UIParent:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    local curX, curY = mx / scale, my / scale
    local dx, dy = curX - zPie.centerX, curY - zPie.centerY
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < zPie.DEADZONE then
        if zPie.hoveredSlice then
            local prevSlot = zPie.activeSlots[zPie.hoveredSlice]
            zPie.rings[zPie.currentRing][prevSlot].hl:Hide()
            if arrowBehavior == "SNAP" then
                zPie.rings[zPie.currentRing][prevSlot].arrow:Hide()
            end
            zPie.hoveredSlice = nil
        end
        zPie.selectionTooltip:Hide()
        if zPie.activeDegree then
            zPie.compassFrame.arrow:Hide()
            zPie.activeDegree = nil
        end
        return
    end

    local rawAngle = math.atan2(dy, dx)
    if arrowTex ~= "NONE" and arrowBehavior == "SMOOTH" then
        local curDeg = math.floor(math.deg(rawAngle) + 0.5)
        if curDeg <= 0 then curDeg = curDeg + 360 end
        if curDeg == 0 then curDeg = 360 end

        if zPie.activeDegree ~= curDeg then
            zPie.activeDegree = curDeg
            local tex = zPie.compassFrame.arrow
            local rads = math.rad(curDeg)
            local ax = zPie.centerX + (zPie.compassRadius * math.cos(rads)) - 16
            local ay = zPie.centerY + (zPie.compassRadius * math.sin(rads)) - 16
            tex:ClearAllPoints()
            tex:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", ax, ay)
            SetRotatedTexCoords(tex, rads - (math.pi / 2) + zPie.compassArrowOffset)
            tex:Show()
        end
    end

    local angle = (math.pi / 2) - rawAngle
    if angle < 0 then angle = angle + (2 * math.pi) end

    local angleStep = (2 * math.pi) / total
    local selectedIndex = math.floor((angle + (angleStep / 2)) / angleStep) + 1
    if selectedIndex > total then selectedIndex = 1 end

    if zPie.hoveredSlice ~= selectedIndex then
        if zPie.hoveredSlice then
            local prevSlot = zPie.activeSlots[zPie.hoveredSlice]
            zPie.rings[zPie.currentRing][prevSlot].hl:Hide()
            if arrowBehavior == "SNAP" then
                zPie.rings[zPie.currentRing][prevSlot].arrow:Hide()
            end
        end
        zPie.hoveredSlice = selectedIndex
        local newSlot = zPie.activeSlots[selectedIndex]
        zPie.rings[zPie.currentRing][newSlot].hl:Show()
        zPie:ShowSelectionTooltip(
            zPie.rings[zPie.currentRing][newSlot],
            zPieDB[zPie.currentRing].items[newSlot])
        
        if arrowTex ~= "NONE" and arrowBehavior == "SNAP" then
            zPie.rings[zPie.currentRing][newSlot].arrow:Show()
        end
    end
end)

zPie:RegisterEvent("PLAYER_LOGIN")
zPie:RegisterEvent("SPELLS_CHANGED")
zPie:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        if not zPie:InitializeProfiles() then return end
        zPie:MigrateLegacyBindings()
        zPie:SanitizeDB()
        zPie:InitButtons()
        zPie:CacheSpells()

        if CleveRoids and CleveRoids.NampowerAPI and
           CleveRoids.NampowerAPI.features and
           CleveRoids.NampowerAPI.features.hasKeyEvents then
            zPie:RegisterEvent("KEY_DOWN")
            zPie:RegisterEvent("KEY_UP")
        end
        
        SLASH_ZPIE1 = "/zpie"
        SLASH_ZPIE2 = "/zp"
        SLASH_ZPIE3 = "/pi"
        SlashCmdList["ZPIE"] = function()
            if zPieConfigFrame:IsShown() then
                zPieConfigFrame:Hide()
            else
                zPieConfigFrame:Show()
            end
        end
        
        local greetTimer = CreateFrame("Frame")
        greetTimer.elapsed = 0
        greetTimer:SetScript("OnUpdate", function()
            this.elapsed = this.elapsed + arg1
            if this.elapsed >= 4 then
                DEFAULT_CHAT_FRAME:AddMessage(zPie.TITLE .. " ~ Type /zpie, /zp, or /pi to configure.")
                this:Hide()
                this:SetScript("OnUpdate", nil)
            end
        end)
    elseif event == "KEY_DOWN" then
        local keyboardFocus = type(GetCurrentKeyBoardFocus) == "function" and GetCurrentKeyBoardFocus()
        local configOpen = zPieConfigFrame and zPieConfigFrame:IsShown()
        if not keyboardFocus and not configOpen and not zPie.currentRing then
            for i = 11, zPie:GetRingCount() do
                local binding = zPieDB[i] and zPieDB[i].binding
                if zPie:BindingMatchesKeyEvent(binding, arg1, arg2) then
                    zPie:OpenRing(i)
                    break
                end
            end
        end
    elseif event == "KEY_UP" then
        if zPie.currentRing and zPie.reqKeyCode and arg1 == zPie.reqKeyCode then
            zPie:CloseRing()
        end
    elseif event == "SPELLS_CHANGED" then
        zPie:CacheSpells()
    end
end)
