local Moveset = {}

function Moveset.Init(State, Helpers)
    local toggleObject = State.Toggles.Moveset
    local m_floor = Helpers.m_floor
    local m_clamp = Helpers.m_clamp
    local SPECIAL_COOLDOWNS = Helpers.SPECIAL_COOLDOWNS
    local m_max = Helpers.m_max
    local o_clock = Helpers.o_clock
    local table_insert = Helpers.table_insert
    local v2_new = Helpers.v2_new
    local COLOR_LIGHT_BLUE = Helpers.COLOR_LIGHT_BLUE
    local COLOR_BLACK = Helpers.COLOR_BLACK
    local COLOR_SEAL_RED = Helpers.COLOR_SEAL_RED
    local COLOR_SEAL_GREEN = Helpers.COLOR_SEAL_GREEN

    local function Hide(c)
        for i = 0, 5 do
            local item = c.MovesetItems[i]
            item.Back.Visible = false
            item.Fill.Visible = false
            item.Outline.Visible = false
            item.Label.Visible = false
            item.SealCircle.Visible = false
        end
    end

    local function Render(c, movesetName, movesetFolder, isReggie, nextReceiptObj, scaleFactor, root2D, uY)
        if not toggleObject.Value then Hide(c); return end
        -- 5. Moveset Slots
        local slotHeight = m_floor(m_clamp(22 * scaleFactor, 14, 32))
        local slotGap = m_floor(m_clamp(3 * scaleFactor, 2, 6))
        local moveFontSize = m_floor(m_clamp(10 * scaleFactor, 8, 15))
        local slotY = uY - slotHeight - m_floor(m_clamp(4 * scaleFactor, 2, 8))
        local hasActiveMoveset = false
    
        if c.MovesetItems then
            -- Reset visibility
            for i = 0, 5 do
                c.MovesetItems[i].Data.Visible = false
                c.MovesetItems[i].MoveRef = nil
            end
    
            -- Slot 0: Special
            local specialItem = c.MovesetItems[0]
            specialItem.Data.Visible = true
            specialItem.Data.Key = "0"
            -- Determine name based on current moveset
            local specData = SPECIAL_COOLDOWNS[movesetName]
            if specData then
                specialItem.Data.Name = specData.Name
                local remaining = m_max(0, c.SpecialCooldownEnd - o_clock())
                local cdRatio = m_clamp(remaining / specData.Duration, 0, 1)
                specialItem.Data.CooldownRatio = cdRatio
            else
                specialItem.Data.Name = "Special"
                specialItem.Data.CooldownRatio = 0
            end
            specialItem.MoveRef = nil
            hasActiveMoveset = true
    
            -- Slots 1-4: regular moves
            if movesetFolder then
                for _, move in ipairs(movesetFolder:GetChildren()) do
                    local slotKey = move:GetAttribute("Key")
                    if type(slotKey) == "number" and slotKey >= 1 and slotKey <= 4 then
                        local item = c.MovesetItems[slotKey]
                        if item then
                            hasActiveMoveset = true
                            item.Data.Visible = true
                            item.Data.Key = tostring(slotKey)
                            local tag = move:GetAttribute("Tag")
                            if tag and move.Name ~= "-" then
                                item.Data.Name = tostring(tag)
                                if not item._tagConn then
                                    item._tagConn = move:GetAttributeChangedSignal("Tag"):Connect(function()
                                        local newTag = move:GetAttribute("Tag")
                                        if newTag and move.Name ~= "-" then
                                            item.Data.Name = tostring(newTag)
                                        else
                                            item.Data.Name = move.Name
                                        end
                                    end)
                                    table_insert(c.Connections, item._tagConn)
                                end
                            else
                                item.Data.Name = move.Name
                            end
                            item.MoveRef = move
    
                            local lastUsedStamp = move:GetAttribute("LastUse")
                            local totalCdDuration = tonumber(move.Value)
                            if type(lastUsedStamp) == "number" and type(totalCdDuration) == "number" and totalCdDuration > 0 then
                                local serverNow = workspace:GetServerTimeNow()
                                local remainingCd = (lastUsedStamp + totalCdDuration) - serverNow
                                item.Data.CooldownRatio = m_clamp(remainingCd / totalCdDuration, 0, 1)
                            else
                                item.Data.CooldownRatio = 0
                            end
                        end
                    end
                end
            end
    
            -- Slot 5: extra for Reggie
            local reggieItem = c.MovesetItems[5]
            if isReggie and nextReceiptObj then
                reggieItem.Data.Visible = true
                reggieItem.Data.Key = "5"
                local function updateReceipt()
                    reggieItem.Data.Name = tostring(nextReceiptObj.Value)
                end
                updateReceipt()
                if not c._receiptConn then
                    c._receiptConn = nextReceiptObj:GetPropertyChangedSignal("Value"):Connect(updateReceipt)
                    table_insert(c.Connections, c._receiptConn)
                end
                reggieItem.Data.CooldownRatio = 0
                reggieItem.MoveRef = nil
                hasActiveMoveset = true
            else
                reggieItem.Data.Visible = false
            end
    
            -- Compute widths for slots 0-4
            local itemWidths = {}
            local totalMovesetWidth = 0
            local activeCount = 0
            for i = 0, 4 do
                local item = c.MovesetItems[i]
                if item.Data.Visible then
                    activeCount = activeCount + 1
                    item.Label.Text = item.Data.Name
                    item.Label.Size = moveFontSize
                    local textW = item.Label.TextBounds.X
                    local slotW = m_floor(m_max(slotHeight, textW + m_clamp(8 * scaleFactor, 4, 12)))
                    slotW = m_floor(m_max(slotW, slotHeight))
                    itemWidths[i] = slotW
                    totalMovesetWidth = totalMovesetWidth + slotW
                else
                    itemWidths[i] = 0
                end
            end
            if activeCount > 0 then
                totalMovesetWidth = totalMovesetWidth + ((activeCount - 1) * slotGap)
            end
    
            -- Render slots 0-4 centered
            local movesetStartX = m_floor(root2D.X - (totalMovesetWidth / 2))
            local currentSlotX = movesetStartX
            for i = 0, 4 do
                local item = c.MovesetItems[i]
                if item.Data.Visible then
                    local slotW = itemWidths[i]
                    item.Back.Visible = true
                    item.Back.Position = v2_new(currentSlotX, slotY)
                    item.Back.Size = v2_new(slotW, slotHeight)
    
                    item.Outline.Visible = true
                    item.Outline.Position = v2_new(currentSlotX, slotY)
                    item.Outline.Size = v2_new(slotW, slotHeight)
    
                    local cdRatio = item.Data.CooldownRatio
                    if cdRatio > 0 then
                        local cdFillH = m_floor(slotHeight * cdRatio)
                        item.Fill.Visible = true
                        item.Fill.Color = COLOR_LIGHT_BLUE
                        item.Fill.Transparency = 0.5
                        item.Fill.Size = v2_new(slotW, cdFillH)
                        item.Fill.Position = v2_new(currentSlotX, slotY + (slotHeight - cdFillH))
                    else
                        item.Fill.Visible = false
                    end
    
                    item.Label.Visible = true
                    item.Label.Outline = true
                    item.Label.OutlineColor = COLOR_BLACK
                    item.Label.Text = item.Data.Name
                    item.Label.Size = moveFontSize
                    item.Label.Position = v2_new(currentSlotX + m_floor(slotW / 2), slotY + m_floor((slotHeight - item.Label.TextBounds.Y) / 2))
    
                    local seal = item.MoveRef and item.MoveRef:GetAttribute("Seal")
                    if seal then
                        local radius = m_floor(m_clamp(4 * scaleFactor, 3, 8))
                        local padding = m_floor(m_clamp(2 * scaleFactor, 1, 4))
                        item.SealCircle.Visible = true
                        item.SealCircle.Radius = radius
                        if seal == 1 then
                            item.SealCircle.Color = COLOR_SEAL_RED
                        else -- seal > 1
                            item.SealCircle.Color = COLOR_SEAL_GREEN
                        end
                        item.SealCircle.Position = v2_new(currentSlotX + slotW - radius - padding, slotY + padding + radius * 0.5)
                    else
                        item.SealCircle.Visible = false
                    end
    
                    currentSlotX = currentSlotX + slotW + slotGap
                else
                    item.Back.Visible = false
                    item.Fill.Visible = false
                    item.Outline.Visible = false
                    item.Label.Visible = false
                    item.SealCircle.Visible = false
                end
            end
    
            -- Render Reggie slot 5 to the right
            if reggieItem and reggieItem.Data.Visible then
                local lastSlotEnd = currentSlotX - slotGap
                reggieItem.Label.Text = reggieItem.Data.Name
                reggieItem.Label.Size = moveFontSize
                local textW = reggieItem.Label.TextBounds.X
                local reggieWidth = m_floor(m_max(slotHeight, textW + m_clamp(8 * scaleFactor, 4, 12)))
                reggieWidth = m_floor(m_clamp(reggieWidth, slotHeight, 80))
                local reggieX = lastSlotEnd + slotGap
                reggieItem.Back.Visible = true
                reggieItem.Back.Position = v2_new(reggieX, slotY)
                reggieItem.Back.Size = v2_new(reggieWidth, slotHeight)
                reggieItem.Outline.Visible = true
                reggieItem.Outline.Position = v2_new(reggieX, slotY)
                reggieItem.Outline.Size = v2_new(reggieWidth, slotHeight)
                reggieItem.Fill.Visible = false
                reggieItem.Label.Visible = true
                reggieItem.Label.Outline = true
                reggieItem.Label.OutlineColor = COLOR_BLACK
                reggieItem.Label.Text = reggieItem.Data.Name
                reggieItem.Label.Size = moveFontSize
                reggieItem.Label.Position = v2_new(reggieX + m_floor(reggieWidth / 2), slotY + m_floor((slotHeight - reggieItem.Label.TextBounds.Y) / 2))
                reggieItem.SealCircle.Visible = false
            else
                reggieItem.Back.Visible = false
                reggieItem.Fill.Visible = false
                reggieItem.Outline.Visible = false
                reggieItem.Label.Visible = false
                reggieItem.SealCircle.Visible = false
            end
        end
        return hasActiveMoveset, slotY
    end

    return { Render = Render, Hide = Hide }
end

return Moveset
