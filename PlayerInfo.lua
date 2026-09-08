local PlayerInfo = {}

function PlayerInfo.Init(State, Helpers)
    local toggleObject = State.Toggles.PlayerInfo
    local table_insert = Helpers.table_insert
    local c3_fromHex = Helpers.c3_fromHex
    local m_floor = Helpers.m_floor
    local COLOR_BLACK = Helpers.COLOR_BLACK
    local v2_new = Helpers.v2_new
    local MOVESET_COLORS = Helpers.MOVESET_COLORS
    local formatVal = Helpers.formatVal
    local s_format = Helpers.s_format
    local ActiveMarks = Helpers.ActiveMarks
    local getGradientColor = Helpers.getGradientColor
    local DARK_MOVESETS = Helpers.DARK_MOVESETS
    local m_clamp = Helpers.m_clamp
    local COLOR_WHITE = Helpers.COLOR_WHITE

    local function parseRichTextLine(lineStr, defaultColor)
        local segments = {}
        local colorStack = { defaultColor }
        local pos = 1
        local len = #lineStr
    
        while pos <= len do
            local tagStart, tagEnd, tagName, tagAttr = lineStr:find("<(%/?%a+)%s*([^>]*)>", pos)
            if not tagStart then
                local text = lineStr:sub(pos)
                if #text > 0 then
                    table_insert(segments, {
                        Text = text,
                        Color = colorStack[#colorStack] or defaultColor
                    })
                end
                break
            end
    
            if tagStart > pos then
                local text = lineStr:sub(pos, tagStart - 1)
                if #text > 0 then
                    table_insert(segments, {
                        Text = text,
                        Color = colorStack[#colorStack] or defaultColor
                    })
                end
            end
    
            local isClosing = tagName:sub(1, 1) == "/"
            local cleanTagName = isClosing and tagName:sub(2):lower() or tagName:lower()
    
            if cleanTagName == "font" then
                if isClosing then
                    if #colorStack > 1 then
                        table.remove(colorStack)
                    end
                else
                    local hex = tagAttr:match("color%s*=%s*['\"]#?([%x%X]+)['\"]") or tagAttr:match("color%s*=%s*#?([%x%X]+)")
                    if hex then
                        local success, col = pcall(c3_fromHex, "#" .. hex)
                        if success and col then
                            table_insert(colorStack, col)
                        else
                            table_insert(colorStack, colorStack[#colorStack])
                        end
                    else
                        table_insert(colorStack, colorStack[#colorStack])
                    end
                end
            end
    
            pos = tagEnd + 1
        end
    
        return segments
    end
    
    local function renderRichText(pool, rawText, centerX, topY, fontSize, defaultColor)
        local lines = {}
        for line in rawText:gmatch("[^\r\n]+") do
            table_insert(lines, line)
        end
    
        if #lines == 0 then
            for _, obj in ipairs(pool) do
                obj.Visible = false
            end
            return
        end
    
        local poolIdx = 0
        local currentY = m_floor(topY)
        local lineHeight = fontSize + 2
    
        for _, lineStr in ipairs(lines) do
            local segments = parseRichTextLine(lineStr, defaultColor)
            local totalLineWidth = 0
            local segWidths = {}
    
            for i, seg in ipairs(segments) do
                poolIdx = poolIdx + 1
                local textObj = pool[poolIdx]
                if not textObj then
                    textObj = Drawing.new("Text")
                    textObj.Center = false
                    pool[poolIdx] = textObj
                end
    
                textObj.Size = fontSize
                textObj.Outline = true
                textObj.OutlineColor = COLOR_BLACK
                textObj.Text = seg.Text
                local w = textObj.TextBounds.X
                segWidths[i] = w
                totalLineWidth = totalLineWidth + w
            end
    
            local currentX = m_floor(centerX - (totalLineWidth / 2))
            local lineStartIdx = poolIdx - #segments + 1
    
            for i, seg in ipairs(segments) do
                local textObj = pool[lineStartIdx + i - 1]
                textObj.Position = v2_new(m_floor(currentX), currentY)
                textObj.Color = seg.Color
                textObj.Visible = true
                currentX = currentX + segWidths[i]
            end
    
            currentY = currentY + lineHeight
        end
    
        for i = poolIdx + 1, #pool do
            pool[i].Visible = false
        end
    end

    local function Hide(c)
        for _, textObj in ipairs(c.TextPool) do textObj.Visible = false end
    end

    local function Render(c, p, char, info, dist, movesetName, fullyCustom, isHaruta, miraclesObj, hideNameAndHealth, globalRainbowHex, shouldUpdateHeavy, scaleFactor, root2D, hasActiveMoveset, slotY, uY)
        if not toggleObject.Value then Hide(c); return end
        if shouldUpdateHeavy then
            local inUlt = char:GetAttribute("InUlt")
            local usesCustomLook = movesetName == "Custom" or fullyCustom
            local hexColor = usesCustomLook and globalRainbowHex or (MOVESET_COLORS[movesetName] or "FFFFFF")
            -- Cash
            local rawCash = p:GetAttribute("Cash")
            local cashValue = type(rawCash) == "number" and rawCash or 0
            if cashValue > 0 then
                local cashStr = hideNameAndHealth and tostring(cashValue) or formatVal(cashValue)
                c.CashDisplay = s_format("<font color='#00FF00'>$%s</font> | ", cashStr)
            else
                c.CashDisplay = ""
            end
    
            -- Perm badges
            local permBadges = ""
            if p:GetAttribute("PS_Owner") == true then
                permBadges = permBadges .. "<font color='#FFDF00'>[Owner]</font> "
            elseif p:GetAttribute("PS_Perms") == true then
                permBadges = permBadges .. "<font color='#FFAA00'>[Admin]</font> "
            end
            if p:GetAttribute("Workshop") == true then
                permBadges = permBadges .. "<font color='#AE00FF'>[Workshop]</font> "
            end
    
            -- Jackpot
            local rawJackpot = char:GetAttribute("JackpotInRow")
            local jackpotCount = type(rawJackpot) == "number" and rawJackpot or 0
            local jackpotTag = (jackpotCount > 0) and s_format("<font color='#00FF00'>[%sx JP]</font> ", jackpotCount) or ""
    
            local leftTag = inUlt and "<font color='#FF007F'>[ULT]</font> " or ""
            local afkTag = c.IsAFK and "<font color='#A0A0A0'>[AFK]</font> " or ""
            
            -- Mark
            local markTag = ""
            local markData = ActiveMarks[char]
            if markData and markData.mark and markData.mark.Parent and char.Parent then
                markTag = "<font color='#9D8D6D'><b>[MARK]</b></font> "
            else
                ActiveMarks[char] = nil
            end
    
            -- ITFG
            local itfgTag = ""
            local itfgVal = char:GetAttribute("ITFG")
            if type(itfgVal) == "number" and itfgVal >= 1 and itfgVal <= 2 then
                itfgTag = s_format("<font color='#DF00FF'><b>[IT %d/2]</b></font> ", itfgVal)
            end
    
            -- EXEC
            local execTag = ""
            local execVal = char:GetAttribute("EXEC")
            if type(execVal) == "number" and execVal > 0 then
                execTag = s_format("<font color='#FFFF00'><b>[EXEC %d/3]</b></font> ", execVal)
            end
    
            -- Burst
            local burstTag = ""
            if char:GetAttribute("Burst") ~= nil then
                burstTag = "<font color='#FFFFFF'><b>[BURST]</b></font> "
            end
    
            -- Emote
            local emoteTag = ""
            if info and info:FindFirstChild("Emote") then
                emoteTag = "<font color='#FF69B4'><b>[EMOTE]</b></font> "
            end
    
            -- VC
            local vcTag = ""
            local audioDevice = p:FindFirstChild("AudioDeviceInput")
            if audioDevice then
                local muted = audioDevice.Muted
                if muted == true then
                    vcTag = "<font color='#FF0000'><b>[VC]</b></font> "
                else
                    vcTag = "<font color='#00FF00'><b>[VC]</b></font> "
                end
            end
    
            local trailingBrackets = ""
            if markTag ~= "" then trailingBrackets = trailingBrackets .. markTag end
            if itfgTag ~= "" then trailingBrackets = trailingBrackets .. itfgTag end
            if execTag ~= "" then trailingBrackets = trailingBrackets .. execTag end
            if burstTag ~= "" then trailingBrackets = trailingBrackets .. burstTag end
            if emoteTag ~= "" then trailingBrackets = trailingBrackets .. emoteTag end
    
            -- Name line
            if hideNameAndHealth then
                c.NameDisplay = vcTag .. trailingBrackets
            elseif c.IsDead then
                c.NameDisplay = s_format("%s%s%s%s%s%s<font color='#FF0000'>[DEAD] %s</font> %s", afkTag, leftTag, jackpotTag, vcTag, c.GroupRoleTag, emoteTag, p.Name, trailingBrackets)
            else
                local nameColorHex = "FFFFFF"
                if c.IsFriend then
                    nameColorHex = "00FF00"
                elseif c.IsMutual then
                    nameColorHex = "00FFFF"
                end
    
                local nameStr = (dist < 50) and p.Name or "<b>" .. p.Name .. "</b>"
                c.NameDisplay = s_format("%s%s%s%s%s%s<font color='#%s'>%s</font> %s", afkTag, leftTag, jackpotTag, vcTag, permBadges, c.GroupRoleTag, nameColorHex, nameStr, trailingBrackets)
            end
            
            -- Distance color
            local distCol = getGradientColor(dist / 800)
            c.HexDistColor = s_format("%02x%02x%02x", m_floor(distCol.R * 255), m_floor(distCol.G * 255), m_floor(distCol.B * 255))
            
            -- Moveset label
            if movesetName and movesetName ~= "" then
                if DARK_MOVESETS[movesetName] and not usesCustomLook then
                    c.CachedMoveset = s_format("<stroke color='#FFFFFF' thickness='1'><font color='#%s'>%s</font></stroke> | ", hexColor, tostring(movesetName))
                else
                    c.CachedMoveset = s_format("<font color='#%s'>%s</font> | ", hexColor, tostring(movesetName))
                end
            else
                c.CachedMoveset = ""
            end
    
            -- Extra info
            local extra = ""
            if isHaruta and miraclesObj then
                local harutaHex = MOVESET_COLORS["Haruta"] or "A77DCB"
                extra = extra .. s_format(" • <font color='#%s'>%s</font>", harutaHex, tostring(miraclesObj.Value))
            end
            if c.AgeDisplay and c.AgeDisplay ~= "" then
                extra = extra .. " • " .. c.AgeDisplay
            end
            if c.FriendDisplay and c.FriendDisplay ~= "" then
                extra = extra .. " • " .. c.FriendDisplay
            end
            if c.GamepassDisplay and c.GamepassDisplay ~= "" then
                extra = extra .. " • " .. c.GamepassDisplay
            end
            c.ExtraInfo = extra
        end
        -- 7. Main Overhead Text
        local killString = hideNameAndHealth and tostring(c.CachedKills) or formatVal(c.CachedKills)
        if c.IsHidingKills then
            killString = s_format("%s <font color='#FF3333'><b>[HIDDEN]</b></font>", killString)
        end
    
        local rawText = s_format("%s\n%s%s<font color='#%s'>%s</font> • <font color='#%s'>%sm</font>%s", 
            c.NameDisplay, 
            c.CachedMoveset,
            c.CashDisplay,
            c.HexKillColor, 
            killString, 
            c.HexDistColor, 
            tostring(m_floor(c.LastDist)),
            c.ExtraInfo
        )
    
        local mainFontSize = m_floor(m_clamp(13 * scaleFactor, 9, 18))
        local textY = hasActiveMoveset and (slotY - mainFontSize - m_floor(m_clamp(10 * scaleFactor, 6, 14))) or (uY - mainFontSize - m_floor(m_clamp(10 * scaleFactor, 6, 14)))
        renderRichText(c.TextPool, rawText, m_floor(root2D.X), textY, mainFontSize, COLOR_WHITE)
    end

    return { Render = Render, Hide = Hide }
end

return PlayerInfo
