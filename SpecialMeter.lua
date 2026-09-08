local SpecialMeter = {}

function SpecialMeter.Init(State, Helpers)
    local toggleObject = State.Toggles.SpecialMeter
    local setBarGroupVisible = Helpers.setBarGroupVisible
    local m_floor = Helpers.m_floor
    local m_clamp = Helpers.m_clamp
    local v2_new = Helpers.v2_new
    local COLOR_YELLOW = Helpers.COLOR_YELLOW
    local c3_new = Helpers.c3_new
    local c3_fromHex = Helpers.c3_fromHex
    local MOVESET_COLORS = Helpers.MOVESET_COLORS

    local function Hide(c)
        setBarGroupVisible(c.ExtraBar, false)
    end

    local function Render(c, scaleFactor, boxX, boxY, boxWidth, boxHeight, isRyu, isHaruta, overheatObj, miraclesObj)
        if not toggleObject.Value then Hide(c); return end
        local eWidth = m_floor(m_clamp(4 * scaleFactor, 2, 8))
        local eGap = m_floor(m_clamp(4 * scaleFactor, 2, 8))
        local eX = boxX + boxWidth + eGap
        local eY = boxY
        local eH = boxHeight
        -- 3. Extra Bar (Overheat / Miracles)
        local ohGap = m_floor(m_clamp(3 * scaleFactor, 2, 6))
        local ohX = eX + eWidth + ohGap
    
        if isRyu and overheatObj then
            local ohVal = overheatObj.Value
            local ohRatio = m_clamp(ohVal / 50, 0, 1)
            for i = 1, #c.ExtraBar.Lines do
                c.ExtraBar.Lines[i].Visible = (i <= 9 and ohRatio > 0.02)
            end
            if ohRatio <= 0.02 then
                setBarGroupVisible(c.ExtraBar, false)
            else
                setBarGroupVisible(c.ExtraBar, true)
                c.ExtraBar.Back.Position = v2_new(ohX, eY)
                c.ExtraBar.Back.Size = v2_new(eWidth, eH)
                c.ExtraBar.Outline.Position = v2_new(ohX, eY)
                c.ExtraBar.Outline.Size = v2_new(eWidth, eH)
                local ohFillH = m_floor(eH * ohRatio)
                c.ExtraBar.Fill.Position = v2_new(ohX, eY + (eH - ohFillH))
                c.ExtraBar.Fill.Size = v2_new(eWidth, ohFillH)
                if ohVal >= 50 then
                    c.ExtraBar.Fill.Color = COLOR_YELLOW
                    for i = 1, 9 do c.ExtraBar.Lines[i].Visible = false end
                else
                    c.ExtraBar.Fill.Color = c3_new(0, 0.66, 1):Lerp(c3_new(1, 0, 0.5), ohRatio)
                    for i = 1, 9 do
                        local lineY = m_floor(eY + (eH * 0.1 * i))
                        c.ExtraBar.Lines[i].From = v2_new(ohX, lineY)
                        c.ExtraBar.Lines[i].To = v2_new(ohX + eWidth, lineY)
                        c.ExtraBar.Lines[i].Visible = true
                    end
                end
            end
        elseif isHaruta and miraclesObj then
            local mirVal = miraclesObj.Value
            local mirRatio = m_clamp(mirVal / 6, 0, 1)
            for i = 1, #c.ExtraBar.Lines do
                c.ExtraBar.Lines[i].Visible = (i <= 6 and mirRatio > 0.02)
            end
            if mirRatio <= 0.02 then
                setBarGroupVisible(c.ExtraBar, false)
            else
                setBarGroupVisible(c.ExtraBar, true)
                local harutaColor = c3_fromHex("#" .. (MOVESET_COLORS["Haruta"] or "A77DCB"))
                c.ExtraBar.Back.Position = v2_new(ohX, eY)
                c.ExtraBar.Back.Size = v2_new(eWidth, eH)
                c.ExtraBar.Outline.Position = v2_new(ohX, eY)
                c.ExtraBar.Outline.Size = v2_new(eWidth, eH)
                local mirFillH = m_floor(eH * mirRatio)
                c.ExtraBar.Fill.Position = v2_new(ohX, eY + (eH - mirFillH))
                c.ExtraBar.Fill.Size = v2_new(eWidth, mirFillH)
                c.ExtraBar.Fill.Color = harutaColor
                for i = 1, 6 do
                    local lineY = m_floor(eY + (eH * (i / 6)))
                    c.ExtraBar.Lines[i].From = v2_new(ohX, lineY)
                    c.ExtraBar.Lines[i].To = v2_new(ohX + eWidth, lineY)
                    c.ExtraBar.Lines[i].Visible = true
                end
            end
        else
            setBarGroupVisible(c.ExtraBar, false)
        end
    end

    return { Render = Render, Hide = Hide }
end

return SpecialMeter
