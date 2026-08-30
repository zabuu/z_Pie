local flatBackdrop = {
    bgFile = "Interface\\BUTTONS\\WHITE8X8",
    edgeFile = "Interface\\BUTTONS\\WHITE8X8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
}

local f = CreateFrame("Frame", "zPieConfigFrame", UIParent)
f:SetWidth(440)
f:SetHeight(540)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
f:SetBackdrop(flatBackdrop)
f:SetBackdropColor(0.07, 0.07, 0.07, 0.95)
f:SetBackdropBorderColor(0, 0, 0, 1)
f:EnableMouse(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
f:SetFrameStrata("DIALOG")
f:Hide()

local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
title:SetPoint("TOP", f, "TOP", 0, -12)
title:SetText(zPie.TITLE)

local footer = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
footer:SetText(zPie.TITLE .. " v1.1.0 - Made by Zab - Aug 29, 2026")

local function CreateFlatButton(name, parent, width, height, text)
    local btn = CreateFrame("Button", name, parent)
    btn:SetWidth(width)
    btn:SetHeight(height)
    btn:SetBackdrop(flatBackdrop)
    btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
    btn:SetBackdropBorderColor(0, 0, 0, 1)
    
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
    fs:SetText(text)
    btn.text = fs
    
    btn:SetScript("OnEnter", function() this:SetBackdropColor(0.25, 0.25, 0.25, 1) end)
    btn:SetScript("OnLeave", function() this:SetBackdropColor(0.15, 0.15, 0.15, 1) end)
    btn:SetScript("OnMouseDown", function() this:SetBackdropColor(0.1, 0.1, 0.1, 1) end)
    btn:SetScript("OnMouseUp", function() this:SetBackdropColor(0.25, 0.25, 0.25, 1) end)
    return btn
end

local closeBtn = CreateFlatButton("zPieCloseBtn", f, 24, 24, "X")
closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
closeBtn.text:SetTextColor(1, 0.3, 0.3)
closeBtn:SetScript("OnClick", function() f:Hide() end)

local selectedRing = 1
local listeningForBind = false

-- ==========================================
-- GLOBAL SETTINGS SECTION
-- ==========================================
local lblGlobal = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
lblGlobal:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -40)
lblGlobal:SetText("GLOBAL SETTINGS")

local lblArrow = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblArrow:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -60)
lblArrow:SetText("Arrow Style:")
lblArrow:SetTextColor(0.8, 0.8, 0.8)

local ddArrow = CreateFrame("Frame", "zPieArrowDropdown", f, "UIDropDownMenuTemplate")
ddArrow:SetPoint("TOPLEFT", f, "TOPLEFT", 80, -54)

local ddL = getglobal(ddArrow:GetName().."Left")
local ddM = getglobal(ddArrow:GetName().."Middle")
local ddR = getglobal(ddArrow:GetName().."Right")
if ddL then ddL:Hide() end
if ddM then ddM:Hide() end
if ddR then ddR:Hide() end

local ddBg = CreateFrame("Frame", nil, ddArrow)
ddBg:SetPoint("TOPLEFT", ddArrow, "TOPLEFT", 16, -2)
ddBg:SetPoint("BOTTOMRIGHT", ddArrow, "BOTTOMRIGHT", -16, 6)
ddBg:SetBackdrop(flatBackdrop)
ddBg:SetBackdropColor(0.15, 0.15, 0.15, 1)
ddBg:SetBackdropBorderColor(0, 0, 0, 1)
ddBg:SetFrameLevel(ddArrow:GetFrameLevel() - 1)

local arrowOptions = {
    { text = "Silver", value = "Interface\\Minimap\\MinimapArrow" },
    { text = "Gold", value = "Interface\\Minimap\\ROTATING-MINIMAPGUIDEARROW" },
    { text = "Wide", value = "Interface\\MoneyFrame\\Arrow-Right-Up" },
    { text = "Big", value = "Interface\\ChatFrame\\ChatFrameExpandArrow" },
    { text = "Hidden", value = "NONE" }
}

local function OnArrowSelect()
    UIDropDownMenu_SetSelectedID(ddArrow, this:GetID())
    if not zPieDB then zPieDB = {} end
    zPieDB.arrowStyle = this.value
    UIDropDownMenu_SetText(this:GetText(), ddArrow)
end

UIDropDownMenu_Initialize(ddArrow, function()
    local currentStyle = (zPieDB and zPieDB.arrowStyle) or "Interface\\Minimap\\MinimapArrow"
    for _, opt in ipairs(arrowOptions) do
        local info = {}
        info.text = opt.text
        info.value = opt.value
        info.func = OnArrowSelect
        info.checked = (currentStyle == opt.value)
        UIDropDownMenu_AddButton(info)
    end
end)
UIDropDownMenu_SetWidth(80, ddArrow)

local lblBehavior = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblBehavior:SetPoint("TOPLEFT", f, "TOPLEFT", 220, -60)
lblBehavior:SetText("Anim:")
lblBehavior:SetTextColor(0.8, 0.8, 0.8)

local ddBehavior = CreateFrame("Frame", "zPieBehaviorDropdown", f, "UIDropDownMenuTemplate")
ddBehavior:SetPoint("TOPLEFT", f, "TOPLEFT", 255, -54)

local bL = getglobal(ddBehavior:GetName().."Left")
local bM = getglobal(ddBehavior:GetName().."Middle")
local bR = getglobal(ddBehavior:GetName().."Right")
if bL then bL:Hide() end
if bM then bM:Hide() end
if bR then bR:Hide() end

local bBg = CreateFrame("Frame", nil, ddBehavior)
bBg:SetPoint("TOPLEFT", ddBehavior, "TOPLEFT", 16, -2)
bBg:SetPoint("BOTTOMRIGHT", ddBehavior, "BOTTOMRIGHT", -16, 6)
bBg:SetBackdrop(flatBackdrop)
bBg:SetBackdropColor(0.15, 0.15, 0.15, 1)
bBg:SetBackdropBorderColor(0, 0, 0, 1)
bBg:SetFrameLevel(ddBehavior:GetFrameLevel() - 1)

local behaviorOptions = {
    { text = "Snap", value = "SNAP" },
    { text = "Smooth", value = "SMOOTH" }
}

local function OnBehaviorSelect()
    UIDropDownMenu_SetSelectedID(ddBehavior, this:GetID())
    if not zPieDB then zPieDB = {} end
    zPieDB.arrowBehavior = this.value
    UIDropDownMenu_SetText(this:GetText(), ddBehavior)
end

UIDropDownMenu_Initialize(ddBehavior, function()
    local currentBehavior = (zPieDB and zPieDB.arrowBehavior) or "SMOOTH"
    for _, opt in ipairs(behaviorOptions) do
        local info = {}
        info.text = opt.text
        info.value = opt.value
        info.func = OnBehaviorSelect
        info.checked = (currentBehavior == opt.value)
        UIDropDownMenu_AddButton(info)
    end
end)
UIDropDownMenu_SetWidth(65, ddBehavior)

local namesBtn = CreateFlatButton("zPieNamesBtn", f, 68, 22, "")
namesBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -54)
namesBtn:SetScript("OnClick", function()
    zPieDB.showSelectionNames = not zPieDB.showSelectionNames
    zPieConfigFrame:Refresh()
end)

-- ==========================================
-- DIVIDER
-- ==========================================
local divLine = f:CreateTexture(nil, "ARTWORK")
divLine:SetTexture(1, 1, 1, 0.1)
divLine:SetWidth(400)
divLine:SetHeight(1)
divLine:SetPoint("TOP", f, "TOP", 0, -85)

-- ==========================================
-- RING SPECIFIC SETTINGS SECTION
-- ==========================================
local lblLocal = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
lblLocal:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -95)
lblLocal:SetText("RING SETTINGS")

local ringTabs = {}
for i = 1, 10 do
    local btn = CreateFlatButton("zPieRingTab"..i, f, 70, 22, "Ring "..i)
    if i <= 5 then
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 18 + ((i-1) * 78), -115)
    else
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 18 + ((i-6) * 78), -141)
    end
    
    btn.tabIndex = i
    btn:SetScript("OnClick", function()
        selectedRing = this.tabIndex
        listeningForBind = false
        zPieKeyInterceptor:Hide()
        zPieConfigFrame:Refresh()
    end)
    ringTabs[i] = btn
end

local function CreateEditBox(name, parent, width, labelText)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(labelText)
    label:SetTextColor(0.8, 0.8, 0.8)
    
    local eb = CreateFrame("EditBox", name, parent)
    eb:SetWidth(width)
    eb:SetHeight(22)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetTextInsets(6, 6, 0, 0)
    eb:SetBackdrop(flatBackdrop)
    eb:SetBackdropColor(0.1, 0.1, 0.1, 1)
    eb:SetBackdropBorderColor(0, 0, 0, 1)
    
    eb.isFocused = false
    eb:SetScript("OnEditFocusGained", function() 
        this.isFocused = true
        this:SetBackdropBorderColor(0.2, 0.6, 1.0, 1)
    end)
    eb:SetScript("OnEditFocusLost", function() 
        this.isFocused = false
        this:SetBackdropBorderColor(0, 0, 0, 1)
    end)
    eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    eb:SetScript("OnTabPressed", function() this:ClearFocus() end)
    return eb, label
end

local ebName, lblName = CreateEditBox("zPieRingNameEB", f, 120, "Ring Name:")
lblName:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -175)
ebName:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -189)

ebName:SetScript("OnTextChanged", function()
    if zPieDB and zPieDB[selectedRing] and this.isFocused then
        local txt = this:GetText()
        zPieDB[selectedRing].name = txt
        
        -- Live-update the corresponding tab text, truncating to 10 chars so it fits nicely
        local rName = txt == "" and ("Ring "..selectedRing) or txt
        local shortName = string.len(rName) > 10 and string.sub(rName, 1, 9).."." or rName
        ringTabs[selectedRing].text:SetText(shortName)
    end
end)

local anchorBtn = CreateFlatButton("zPieAnchorBtn", f, 110, 22, "")
anchorBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 150, -189)
anchorBtn:SetScript("OnClick", function()
    if not zPieDB[selectedRing] then return end
    if zPieDB[selectedRing].anchor == "MOUSE" then
        zPieDB[selectedRing].anchor = "CENTER"
    else
        zPieDB[selectedRing].anchor = "MOUSE"
    end
    zPieConfigFrame:Refresh()
end)

local bindBtn = CreateFlatButton("zPieKeybindBtn", f, 130, 22, "")
bindBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 270, -189)

local keyInterceptor = CreateFrame("Frame", "zPieKeyInterceptor", UIParent)
keyInterceptor:SetFrameStrata("FULLSCREEN_DIALOG")
keyInterceptor:SetAllPoints(UIParent)
keyInterceptor:EnableKeyboard(true)
keyInterceptor:EnableMouse(true)
keyInterceptor:Hide()

local function ApplyBinding(key)
    if not key or key == "UNKNOWN" then return end
    if key == "LSHIFT" or key == "RSHIFT" or key == "SHIFT" or 
       key == "LCTRL" or key == "RCTRL" or key == "CTRL" or 
       key == "LALT" or key == "RALT" or key == "ALT" then return end

    if key == "ESCAPE" then
        local key1, key2 = GetBindingKey("ZPIE_RING_" .. selectedRing)
        if key1 then SetBinding(key1, nil) end
        if key2 then SetBinding(key2, nil) end
        SaveBindings(GetCurrentBindingSet())
    else
        local alt = IsAltKeyDown() and "ALT-" or ""
        local ctrl = IsControlKeyDown() and "CTRL-" or ""
        local shift = IsShiftKeyDown() and "SHIFT-" or ""
        local fullBinding = alt .. ctrl .. shift .. key
        local key1, key2 = GetBindingKey("ZPIE_RING_" .. selectedRing)
        if key1 then SetBinding(key1, nil) end
        if key2 then SetBinding(key2, nil) end
        
        SetBinding(fullBinding, "ZPIE_RING_" .. selectedRing)
        SaveBindings(GetCurrentBindingSet())
    end
    
    listeningForBind = false
    keyInterceptor:Hide()
    zPieConfigFrame:Refresh()
end

keyInterceptor:SetScript("OnKeyDown", function() ApplyBinding(arg1) end)
keyInterceptor:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" or arg1 == "RightButton" then
        listeningForBind = false
        keyInterceptor:Hide()
        zPieConfigFrame:Refresh()
    elseif arg1 == "MiddleButton" then ApplyBinding("BUTTON3")
    elseif arg1 == "Button4" then ApplyBinding("BUTTON4")
    elseif arg1 == "Button5" then ApplyBinding("BUTTON5")
    end
end)

bindBtn:SetScript("OnClick", function()
    if listeningForBind then
        listeningForBind = false
        keyInterceptor:Hide()
    else
        listeningForBind = true
        keyInterceptor:Show()
    end
    zPieConfigFrame:Refresh()
end)

local radiusSlider = CreateFrame("Slider", "zPieRadiusSlider", f, "OptionsSliderTemplate")
radiusSlider:SetWidth(150)
radiusSlider:SetPoint("TOP", f, "TOP", 0, -230)
radiusSlider:SetMinMaxValues(40, 150)
radiusSlider:SetValueStep(1)
getglobal(radiusSlider:GetName() .. "Low"):SetText("40")
getglobal(radiusSlider:GetName() .. "High"):SetText("150")
local radiusText = getglobal(radiusSlider:GetName() .. "Text")

radiusSlider:SetScript("OnValueChanged", function()
    local val = math.floor(this:GetValue() + 0.5)
    radiusText:SetText("Radius: " .. val)
    if zPieDB and zPieDB[selectedRing] then
        zPieDB[selectedRing].radius = val
    end
end)

-- ==========================================
-- PREVIEW UI
-- ==========================================
local function CaptureCursorToSlot(targetSlot)
    local bufferSlot = zPie:GetBufferSlot()
    PlaceAction(bufferSlot)
    
    if HasAction(bufferSlot) then
        local actionName, actionIcon, actionType, macroIndex
        local macroName = GetActionText(bufferSlot)
        local actionKind, actionID
        if type(GetActionInfo) == "function" then
            actionKind, actionID = GetActionInfo(bufferSlot)
        end
        local superMacroName
        if type(SM_ACTION) == "table" then
            superMacroName = SM_ACTION[bufferSlot]
        end
        
        if superMacroName and type(GetSuperMacroInfo) == "function" then
            actionName = superMacroName
            actionIcon = GetSuperMacroInfo(superMacroName, "texture") or GetActionTexture(bufferSlot)
            actionType = "SUPER_MACRO"
        elseif macroName or (actionKind and string.lower(actionKind) == "macro") then
            macroIndex = actionID or (macroName and GetMacroIndexByName(macroName))
            if macroIndex and macroIndex > 0 then
                local indexedName, icon = GetMacroInfo(macroIndex)
                actionName = indexedName or macroName
                actionIcon = icon or GetActionTexture(bufferSlot)
            else
                actionName = macroName
                actionIcon = GetActionTexture(bufferSlot)
                macroIndex = nil
            end
            actionType = "MACRO"
        else
            zPieScanner:SetOwner(UIParent, "ANCHOR_NONE")
            zPieScanner:ClearLines()
            zPieScanner:SetAction(bufferSlot)
            actionName = zPieScannerTextLeft1:GetText()
            actionIcon = GetActionTexture(bufferSlot)
            
            if (not actionIcon or actionIcon == "") and actionName and zPie.spellCache[actionName] then
                actionIcon = GetSpellTexture(zPie.spellCache[actionName], "BOOKTYPE_SPELL")
            end
            
            actionType = "SPELL_OR_ITEM"
        end
        
        if not actionIcon or actionIcon == "" then
            actionIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
        end
        
        if not zPieDB[selectedRing].items then zPieDB[selectedRing].items = {} end
        zPieDB[selectedRing].items[targetSlot] = {
            name = actionName,
            icon = actionIcon,
            type = actionType,
            macroIndex = macroIndex
        }
        
        PickupAction(bufferSlot)
        ClearCursor()
        if superMacroName and SM_CURSOR == superMacroName then SM_CURSOR = nil end
        return true
    end
    return false
end

local instruction = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
instruction:SetPoint("TOP", f, "TOP", 0, -270)
instruction:SetText("Drag Spells, Macros, or Items into the center slot below:")
instruction:SetTextColor(0.8, 0.8, 0.8)

local centerBtn = CreateFrame("Button", "zPieConfigCenterBtn", f)
centerBtn:SetWidth(42)
centerBtn:SetHeight(42)
centerBtn:SetPoint("TOP", f, "TOP", 0, -380)
centerBtn:SetBackdrop(flatBackdrop)
centerBtn:SetBackdropColor(0.1, 0.1, 0.1, 1)
centerBtn:SetBackdropBorderColor(0, 0, 0, 1)

local cIcon = centerBtn:CreateTexture(nil, "BACKGROUND")
cIcon:SetPoint("TOPLEFT", centerBtn, "TOPLEFT", 1, -1)
cIcon:SetPoint("BOTTOMRIGHT", centerBtn, "BOTTOMRIGHT", -1, 1)
cIcon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
cIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
cIcon:SetVertexColor(0.5, 0.5, 0.5)

local cText = centerBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
cText:SetPoint("BOTTOM", centerBtn, "TOP", 0, 6)
cText:SetText("Drop Here")
cText:SetTextColor(0.6, 0.6, 0.6)

local function HandleCenterDrop()
    local items = zPieDB[selectedRing].items or {}
    local targetSlot = nil
    for i = 1, 8 do
        if not items[i] or not items[i].name then
            targetSlot = i
            break
        end
    end
    if not targetSlot then
        ClearCursor()
        UIErrorsFrame:AddMessage("Ring is full! Click an icon to remove it, or drop onto it to replace.", 1.0, 0.1, 0.1, 1.0)
        return
    end
    if CaptureCursorToSlot(targetSlot) then zPieConfigFrame:Refresh() end
end

centerBtn:RegisterForDrag("LeftButton")
centerBtn:SetScript("OnClick", HandleCenterDrop)
centerBtn:SetScript("OnReceiveDrag", HandleCenterDrop)

local draggingSlot = nil
local dragFrame = CreateFrame("Frame", nil, f)
dragFrame:SetFrameStrata("TOOLTIP")
dragFrame:SetWidth(38)
dragFrame:SetHeight(38)
dragFrame:SetBackdrop(flatBackdrop)
dragFrame:SetBackdropColor(0, 0, 0, 1)
dragFrame:SetBackdropBorderColor(0, 0, 0, 1)
dragFrame:Hide()

local dragTex = dragFrame:CreateTexture(nil, "OVERLAY")
dragTex:SetPoint("TOPLEFT", dragFrame, "TOPLEFT", 1, -1)
dragTex:SetPoint("BOTTOMRIGHT", dragFrame, "BOTTOMRIGHT", -1, 1)
dragTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
dragTex:SetAlpha(0.8)

dragFrame:SetScript("OnUpdate", function()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    this:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end)

local previewBtns = {}
for s = 1, 8 do
    local pBtn = CreateFrame("Button", "zPiePreview"..s, f)
    pBtn:SetWidth(36)
    pBtn:SetHeight(36)
    pBtn:SetBackdrop(flatBackdrop)
    pBtn:SetBackdropColor(0.1, 0.1, 0.1, 1)
    pBtn:SetBackdropBorderColor(0, 0, 0, 1)
    pBtn:RegisterForDrag("LeftButton")
    
    local pIcon = pBtn:CreateTexture(nil, "BACKGROUND")
    pIcon:SetPoint("TOPLEFT", pBtn, "TOPLEFT", 1, -1)
    pIcon:SetPoint("BOTTOMRIGHT", pBtn, "BOTTOMRIGHT", -1, 1)
    pIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    pBtn.icon = pIcon

    pBtn.slotIndex = s
    
    pBtn:SetScript("OnDragStart", function()
        local item = zPieDB[selectedRing].items[this.slotIndex]
        if item then
            draggingSlot = this.slotIndex
            local displayIcon = zPie:GetIcon(item)
            dragTex:SetTexture(displayIcon)
            dragFrame:Show()
            this:SetAlpha(0.2)
        end
    end)
    
    pBtn:SetScript("OnReceiveDrag", function()
        if CaptureCursorToSlot(this.slotIndex) then zPieConfigFrame:Refresh() end
    end)

    pBtn:SetScript("OnDragStop", function()
        if draggingSlot then
            for i = 1, 8 do
                if previewBtns[i]:IsVisible() and MouseIsOver(previewBtns[i]) and i ~= draggingSlot then
                    local temp = zPieDB[selectedRing].items[i]
                    zPieDB[selectedRing].items[i] = zPieDB[selectedRing].items[draggingSlot]
                    zPieDB[selectedRing].items[draggingSlot] = temp
                    break
                end
            end
            draggingSlot = nil
            dragFrame:Hide()
            zPieConfigFrame:Refresh()
        end
    end)
    
    pBtn:SetScript("OnClick", function()
        if not CaptureCursorToSlot(this.slotIndex) then
            zPieDB[selectedRing].items[this.slotIndex] = nil
            zPieConfigFrame:Refresh()
        end
    end)
    
    pBtn:SetScript("OnEnter", function()
        this:SetBackdropBorderColor(1, 0.8, 0, 1)
        this.isHovered = true
        this.tooltipState = nil
    end)
    
    pBtn:SetScript("OnLeave", function() 
        this:SetBackdropBorderColor(0, 0, 0, 1)
        this.isHovered = false
        this.tooltipState = nil
        GameTooltip:Hide() 
    end)
    
    pBtn:SetScript("OnUpdate", function()
        if not this.isHovered then return end
        
        local itemData = zPieDB[selectedRing].items[this.slotIndex]
        if not itemData or not itemData.name then return end
        
        local desiredState = IsAltKeyDown() and "ALT" or "NORMAL"
        
        if this.tooltipState ~= desiredState then
            this.tooltipState = desiredState
            
            if desiredState == "ALT" then
                GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
                
                local spellId = zPie.spellCache and zPie.spellCache[itemData.name]
                if spellId then
                    GameTooltip:SetSpell(spellId, "BOOKTYPE_SPELL")
                else
                    local foundLink
                    for bag = 0, 4 do
                        for slot = 1, GetContainerNumSlots(bag) do
                            local link = GetContainerItemLink(bag, slot)
                            if zPie:ItemLinkMatches(link, itemData.name) then
                                foundLink = link
                                break
                            end
                        end
                        if foundLink then break end
                    end
                    if not foundLink then
                        for invSlot = 0, 19 do
                            local link = GetInventoryItemLink("player", invSlot)
                            if zPie:ItemLinkMatches(link, itemData.name) then
                                foundLink = link
                                break
                            end
                        end
                    end
                    
                    local linkString
                    if foundLink then
                        _, _, linkString = string.find(foundLink, "(item:%d+:%d+:%d+:%d+)")
                    end
                    
                    if linkString then
                        GameTooltip:SetHyperlink(linkString)
                    else
                        GameTooltip:SetText(itemData.name, 1, 1, 1)
                        if itemData.type == "MACRO" or itemData.type == "SUPER_MACRO" then
                            GameTooltip:AddLine(
                                itemData.type == "SUPER_MACRO" and "SuperMacro" or "Macro",
                                0.5, 0.5, 0.5)
                        end
                    end
                end
                GameTooltip:Show()
            else
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetText(itemData.name, 1, 1, 1)
                GameTooltip:AddLine("Click to remove", 1, 0.2, 0.2)
                GameTooltip:AddLine("Drag to rearrange", 0.2, 1, 0.2)
                GameTooltip:AddLine("Hold ALT for details", 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end
        end
    end)
    
    pBtn:Hide()
    previewBtns[s] = pBtn
end

function zPieConfigFrame:Refresh()
    if not zPieDB then return end
    
    if zPie and zPie.CacheSpells then zPie:CacheSpells() end
    if zPie and zPie.RefreshDBIcons then zPie:RefreshDBIcons() end
    
    local data = zPieDB[selectedRing]
    if not ebName.isFocused then ebName:SetText(data.name or ("Ring "..selectedRing)) end
    anchorBtn.text:SetText("Anchor: " .. (data.anchor or "MOUSE"))
    
    local currentRadius = data.radius or 75
    radiusSlider:SetValue(currentRadius)
    radiusText:SetText("Radius: " .. currentRadius)

    if listeningForBind then
        bindBtn.text:SetText("|cffff0000Press Key...|r")
    else
        local bind = GetBindingKey("ZPIE_RING_" .. selectedRing)
        bindBtn.text:SetText(bind and ("Key: " .. bind) or "Key: [None]")
    end
    
    if zPieDB.arrowStyle then
        for i, opt in ipairs(arrowOptions) do
            if opt.value == zPieDB.arrowStyle then
                UIDropDownMenu_SetSelectedID(ddArrow, i)
                UIDropDownMenu_SetText(opt.text, ddArrow)
                break
            end
        end
    else
        UIDropDownMenu_SetSelectedID(ddArrow, 1)
        UIDropDownMenu_SetText("Silver", ddArrow)
    end

    if zPieDB.arrowBehavior then
        for i, opt in ipairs(behaviorOptions) do
            if opt.value == zPieDB.arrowBehavior then
                UIDropDownMenu_SetSelectedID(ddBehavior, i)
                UIDropDownMenu_SetText(opt.text, ddBehavior)
                break
            end
        end
    else
        UIDropDownMenu_SetSelectedID(ddBehavior, 2)
        UIDropDownMenu_SetText("Smooth", ddBehavior)
    end

    namesBtn.text:SetText(zPieDB.showSelectionNames and "Names: On" or "Names: Off")
    
    -- Apply tab labels with truncation to match user inputs
    for i = 1, 10 do
        local rName = (zPieDB[i] and zPieDB[i].name) or ("Ring "..i)
        if rName == "" then rName = "Ring "..i end
        local shortName = string.len(rName) > 10 and string.sub(rName, 1, 9).."." or rName
        ringTabs[i].text:SetText(shortName)

        if i == selectedRing then 
            ringTabs[i]:SetBackdropBorderColor(0.2, 0.6, 1.0, 1)
            ringTabs[i].text:SetTextColor(1, 1, 1)
        else 
            ringTabs[i]:SetBackdropBorderColor(0, 0, 0, 1)
            ringTabs[i].text:SetTextColor(0.6, 0.6, 0.6)
        end
    end
    
    for i = 1, 8 do 
        previewBtns[i]:Hide() 
        previewBtns[i].icon:SetTexture(nil)
        previewBtns[i]:SetFrameLevel(f:GetFrameLevel() + 5)
    end
    
    local items = data.items or {}
    local activeSlots = {}
    
    for s = 1, 8 do
        if items[s] and items[s].name then table.insert(activeSlots, s) end
    end
    
    local total = table.getn(activeSlots)
    if total > 0 then
        local configRadius = 88
        local angleStep = (2 * math.pi) / total
        
        for i, origSlot in ipairs(activeSlots) do
            local btn = previewBtns[origSlot]
            local angle = (math.pi / 2) - ((i - 1) * angleStep)
            local bx = configRadius * math.cos(angle)
            local by = configRadius * math.sin(angle)
            
            btn:ClearAllPoints()
            btn:SetPoint("CENTER", centerBtn, "CENTER", bx, by)
            
            local displayIcon = zPie:GetIcon(items[origSlot])
            btn.icon:SetTexture(displayIcon)
            btn:SetAlpha(1.0)
            btn:Show()
        end
    end
end

f:SetScript("OnShow", function()
    listeningForBind = false
    keyInterceptor:Hide()
    zPieConfigFrame:Refresh()
end)

f:SetScript("OnHide", function()
    listeningForBind = false
    keyInterceptor:Hide()
end)
