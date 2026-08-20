AutoPie = CreateFrame("Frame", "AutoPieCoreFrame", UIParent)
AutoPie.rings = {}
AutoPie.currentRing = nil
AutoPie.hoveredSlice = nil
AutoPie.activeDegree = nil
AutoPie.centerX = 0
AutoPie.centerY = 0
AutoPie.BTN_SIZE = 40
AutoPie.DEADZONE = 18

AutoPie.TAP_THRESHOLD = 0.20
AutoPie.openTime = 0
AutoPie.activeSlots = {} 
AutoPie.spellCache = {}

AutoPie.arrowOffsets = {
    ["Interface\\Minimap\\MinimapArrow"] = 0,                             
    ["Interface\\Minimap\\ROTATING-MINIMAPGUIDEARROW"] = 0,               
    ["Interface\\MoneyFrame\\Arrow-Right-Up"] = math.pi / 2,              
    ["Interface\\ChatFrame\\ChatFrameExpandArrow"] = math.pi / 2,         
}

AutoPieScanner = CreateFrame("GameTooltip", "AutoPieScanner", UIParent, "GameTooltipTemplate")
AutoPieScanner:SetOwner(UIParent, "ANCHOR_NONE")

function AutoPie:SanitizeDB()
    if not AutoPieDB then AutoPieDB = {} end
    if not AutoPieDB.arrowStyle then AutoPieDB.arrowStyle = "Interface\\Minimap\\MinimapArrow" end
    if not AutoPieDB.arrowBehavior then AutoPieDB.arrowBehavior = "SMOOTH" end
    for i = 1, 10 do
        if not AutoPieDB[i] then
            AutoPieDB[i] = { name = "Ring " .. i, anchor = "MOUSE", items = {}, radius = 75 }
        end
        if not AutoPieDB[i].items then AutoPieDB[i].items = {} end
        if not AutoPieDB[i].radius then AutoPieDB[i].radius = 75 end
    end
end

function AutoPie:CacheSpells()
    local tempCache = {}
    local i = 1
    local count = 0
    while true do
        local spellName = GetSpellName(i, "BOOKTYPE_SPELL")
        if not spellName then break end
        tempCache[spellName] = i
        i = i + 1
        count = count + 1
    end
    
    if count > 0 then
        self.spellCache = tempCache
    end
end

function AutoPie:RefreshDBIcons()
    if not AutoPieDB then return end
    for r = 1, 10 do
        if AutoPieDB[r] and AutoPieDB[r].items then
            for s = 1, 8 do
                local item = AutoPieDB[r].items[s]
                if item and item.name then
                    if item.type == "SPELL_OR_ITEM" and self.spellCache[item.name] then
                        local tex = GetSpellTexture(self.spellCache[item.name], "BOOKTYPE_SPELL")
                        if tex and tex ~= "" then
                            item.icon = tex
                        end
                    elseif item.type == "MACRO" then
                        local idx = GetMacroIndexByName(item.name)
                        if idx > 0 then
                            local _, tex = GetMacroInfo(idx)
                            if tex and tex ~= "" then
                                item.icon = tex
                            end
                        end
                    end
                end
            end
        end
    end
end

function AutoPie:GetBufferSlot()
    for i = 120, 73, -1 do
        if not HasAction(i) then return i end
    end
    return 120
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
    
    for i = 1, 32 do
        local buffIcon = UnitBuff("player", i)
        if not buffIcon then break end
        if buffIcon == iconTexture then return true end
    end
    
    return false
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

function AutoPie:InitButtons()
    self.compassFrame = CreateFrame("Frame", "AutoPieCompassFrame", UIParent)
    self.compassFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.compassFrame.arrows = {}
    for i = 1, 360 do
        local tex = self.compassFrame:CreateTexture(nil, "BACKGROUND")
        tex:SetWidth(32)
        tex:SetHeight(32)
        tex:Hide()
        self.compassFrame.arrows[i] = tex
    end

    for r = 1, 10 do
        self.rings[r] = {}
        for s = 1, 8 do
            local name = "AutoPieRing" .. r .. "Slot" .. s
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

function AutoPie:HideAll()
    for r = 1, 10 do
        for s = 1, 8 do
            self.rings[r][s]:Hide()
            self.rings[r][s].hl:Hide()
            self.rings[r][s].activeTex:Hide()
            self.rings[r][s].arrow:Hide()
        end
    end
    self.currentRing = nil
    self.hoveredSlice = nil
    
    if self.compassFrame then
        if self.activeDegree and self.compassFrame.arrows[self.activeDegree] then
            self.compassFrame.arrows[self.activeDegree]:Hide()
        end
        self.compassFrame:Hide()
    end
    self.activeDegree = nil
    self:Hide()
end

function AutoPie:GetIcon(itemData)
    if not itemData or not itemData.name then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    
    if self.spellCache and self.spellCache[itemData.name] then
        local tex = GetSpellTexture(self.spellCache[itemData.name], "BOOKTYPE_SPELL")
        if tex and tex ~= "" then return tex end
    end
    
    if itemData.type == "MACRO" then
        local idx = GetMacroIndexByName(itemData.name)
        if idx > 0 then
            local _, tex = GetMacroInfo(idx)
            if tex and tex ~= "" then return tex end
        end
    end
    
    if itemData.icon and itemData.icon ~= "" then
        return itemData.icon
    end
    
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function AutoPie:GetActionData(itemData)
    local count, start, duration, enable = "", 0, 0, 0
    if not itemData or not itemData.name then return count, start, duration, enable end
    
    if itemData.type == "MACRO" then return count, start, duration, enable end
    
    if self.spellCache[itemData.name] then
        start, duration, enable = GetSpellCooldown(self.spellCache[itemData.name], "BOOKTYPE_SPELL")
        return count, start, duration, enable
    end
    
    local itemCount = 0
    local isItem = false
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(link, itemData.name) then
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

function AutoPie:ExecuteAction(itemData)
    if not itemData or not itemData.name then return end
    
    if itemData.type == "MACRO" then
        local idx = GetMacroIndexByName(itemData.name)
        if idx > 0 then CastMacro(idx) end
    else
        if self.spellCache[itemData.name] then
            CastSpellByName(itemData.name)
            return
        end
        
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) do
                local link = GetContainerItemLink(bag, slot)
                if link and string.find(link, itemData.name) then
                    UseContainerItem(bag, slot)
                    return
                end
            end
        end
        
        for invSlot = 0, 19 do
            local link = GetInventoryItemLink("player", invSlot)
            if link and string.find(link, itemData.name) then
                UseInventoryItem(invSlot)
                return
            end
        end
    end
end

function AutoPie:OpenRing(ringIndex)
    ringIndex = tonumber(ringIndex)
    if not ringIndex or not AutoPieDB or not AutoPieDB[ringIndex] then return end

    self.openTime = GetTime()
    self.activeSlots = {}

    local bindStr = GetBindingKey("AUTOPIE_RING_" .. ringIndex)
    if bindStr then
        self.reqAlt = string.find(bindStr, "ALT%-") and true or false
        self.reqCtrl = string.find(bindStr, "CTRL%-") and true or false
        self.reqShift = string.find(bindStr, "SHIFT%-") and true or false
    else
        self.reqAlt, self.reqCtrl, self.reqShift = false, false, false
    end

    local items = AutoPieDB[ringIndex].items or {}
    for s = 1, 8 do
        if items[s] and items[s].name and items[s].name ~= "" then
            table.insert(self.activeSlots, s)
        end
    end

    local total = table.getn(self.activeSlots)
    if total == 0 then return end

    self:HideAll()
    self.currentRing = ringIndex

    local ringData = AutoPieDB[ringIndex]
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
    local arrowTex = AutoPieDB.arrowStyle or "Interface\\Minimap\\MinimapArrow"
    local arrowBehavior = AutoPieDB.arrowBehavior or "SMOOTH"
    local arrowOffset = self.arrowOffsets[arrowTex] or 0

    if arrowTex == "NONE" then
        self.compassFrame:Hide()
    else
        if arrowBehavior == "SMOOTH" then
            self.compassFrame:Show()
            local compassRadius = radius - 35
            for deg = 1, 360 do
                local tex = self.compassFrame.arrows[deg]
                tex:SetTexture(arrowTex)
                local rads = math.rad(deg)
                local ax = self.centerX + (compassRadius * math.cos(rads)) - 16
                local ay = self.centerY + (compassRadius * math.sin(rads)) - 16
                tex:ClearAllPoints()
                tex:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", ax, ay)
                
                local rotation = rads - (math.pi / 2) + arrowOffset
                SetRotatedTexCoords(tex, rotation)
                tex:Hide()
            end
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
        btn.icon:SetTexture(displayIcon)
        
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

function AutoPie:CloseRing()
    if not self.currentRing then return end

    local ringIndex = self.currentRing
    local elapsed = GetTime() - self.openTime
    local targetOriginalSlot = nil

    if (not self.hoveredSlice) and (elapsed <= self.TAP_THRESHOLD) then
        if self.activeSlots[1] then targetOriginalSlot = self.activeSlots[1] end
    elseif self.hoveredSlice then
        targetOriginalSlot = self.activeSlots[self.hoveredSlice]
    end

    self:HideAll()

    if targetOriginalSlot then
        local items = AutoPieDB[ringIndex].items
        if items and items[targetOriginalSlot] then
            self:ExecuteAction(items[targetOriginalSlot])
        end
    end
end

AutoPie:SetScript("OnUpdate", function()
    if not AutoPie.currentRing then return end

    if (AutoPie.reqAlt and not IsAltKeyDown()) or 
       (AutoPie.reqCtrl and not IsControlKeyDown()) or 
       (AutoPie.reqShift and not IsShiftKeyDown()) then
        AutoPie:CloseRing()
        return
    end

    local total = table.getn(AutoPie.activeSlots)
    if total == 0 then return end
    
    local arrowTex = AutoPieDB.arrowStyle or "Interface\\Minimap\\MinimapArrow"
    local arrowBehavior = AutoPieDB.arrowBehavior or "SMOOTH"

    local scale = UIParent:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    local curX, curY = mx / scale, my / scale
    local dx, dy = curX - AutoPie.centerX, curY - AutoPie.centerY
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < AutoPie.DEADZONE then
        if AutoPie.hoveredSlice then
            local prevSlot = AutoPie.activeSlots[AutoPie.hoveredSlice]
            AutoPie.rings[AutoPie.currentRing][prevSlot].hl:Hide()
            if arrowBehavior == "SNAP" then
                AutoPie.rings[AutoPie.currentRing][prevSlot].arrow:Hide()
            end
            AutoPie.hoveredSlice = nil
        end
        if AutoPie.activeDegree and AutoPie.compassFrame.arrows[AutoPie.activeDegree] then
            AutoPie.compassFrame.arrows[AutoPie.activeDegree]:Hide()
            AutoPie.activeDegree = nil
        end
        return
    end

    if arrowTex ~= "NONE" and arrowBehavior == "SMOOTH" then
        local rawAngle = math.atan2(dy, dx)
        local curDeg = math.floor(math.deg(rawAngle) + 0.5)
        if curDeg <= 0 then curDeg = curDeg + 360 end
        if curDeg == 0 then curDeg = 360 end

        if AutoPie.activeDegree ~= curDeg then
            if AutoPie.activeDegree and AutoPie.compassFrame.arrows[AutoPie.activeDegree] then
                AutoPie.compassFrame.arrows[AutoPie.activeDegree]:Hide()
            end
            AutoPie.activeDegree = curDeg
            if AutoPie.compassFrame.arrows[curDeg] then
                AutoPie.compassFrame.arrows[curDeg]:Show()
            end
        end
    end

    local rawAngle = math.atan2(dy, dx)
    local angle = (math.pi / 2) - rawAngle
    if angle < 0 then angle = angle + (2 * math.pi) end

    local angleStep = (2 * math.pi) / total
    local selectedIndex = math.floor((angle + (angleStep / 2)) / angleStep) + 1
    if selectedIndex > total then selectedIndex = 1 end

    if AutoPie.hoveredSlice ~= selectedIndex then
        if AutoPie.hoveredSlice then
            local prevSlot = AutoPie.activeSlots[AutoPie.hoveredSlice]
            AutoPie.rings[AutoPie.currentRing][prevSlot].hl:Hide()
            if arrowBehavior == "SNAP" then
                AutoPie.rings[AutoPie.currentRing][prevSlot].arrow:Hide()
            end
        end
        AutoPie.hoveredSlice = selectedIndex
        local newSlot = AutoPie.activeSlots[selectedIndex]
        AutoPie.rings[AutoPie.currentRing][newSlot].hl:Show()
        
        if arrowTex ~= "NONE" and arrowBehavior == "SNAP" then
            AutoPie.rings[AutoPie.currentRing][newSlot].arrow:Show()
        end
    end
end)

AutoPie:RegisterEvent("VARIABLES_LOADED")
AutoPie:RegisterEvent("SPELLS_CHANGED")
AutoPie:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        AutoPie:SanitizeDB()
        AutoPie:InitButtons()
        AutoPie:CacheSpells()
        
        SLASH_AUTOPIE1 = "/autopie"
        SLASH_AUTOPIE2 = "/pie"
        SLASH_AUTOPIE3 = "/pi"
        SlashCmdList["AUTOPIE"] = function()
            if AutoPieConfigFrame:IsShown() then
                AutoPieConfigFrame:Hide()
            else
                AutoPieConfigFrame:Show()
            end
        end
        
        local greetTimer = CreateFrame("Frame")
        greetTimer.elapsed = 0
        greetTimer:SetScript("OnUpdate", function()
            this.elapsed = this.elapsed + arg1
            if this.elapsed >= 4 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000A|cffff7f00u|cffffff00t|cff00ff00o|cff00bfffP|cff7b68eei|cff9400d3e|r ~ Type /autopie, /pie, or /pi to configure.")
                this:Hide()
                this:SetScript("OnUpdate", nil)
            end
        end)
    elseif event == "SPELLS_CHANGED" then
        AutoPie:CacheSpells()
    end
end)