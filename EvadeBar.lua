local EvadeBar = {}

function EvadeBar.Init(State, Helpers)
    local toggleObject = State.Toggles.EvadeBar
    local setBarGroupVisible = Helpers.setBarGroupVisible
    local m_floor = Helpers.m_floor
    local m_clamp = Helpers.m_clamp
    local v2_new = Helpers.v2_new
    local COLOR_PURPLE = Helpers.COLOR_PURPLE
    local COLOR_CYAN = Helpers.COLOR_CYAN
    local COLOR_DARK_BLUE = Helpers.COLOR_DARK_BLUE

    local function Hide(c)
        setBarGroupVisible(c.EvadeBar, false)
    end

    local function Render(c, char, scaleFactor, boxX, boxY, boxWidth, boxHeight)
        if not toggleObject.Value then Hide(c); return end
        -- 2. Evade Bar
        local eWidth = m_floor(m_clamp(4 * scaleFactor, 2, 8))
        local eGap = m_floor(m_clamp(4 * scaleFactor, 2, 8))
        local eX = boxX + boxWidth + eGap
        local eY = boxY
        local eH = boxHeight
    
        local rawEvade = char:GetAttribute("Evade")
        local evadeValue = type(rawEvade) == "number" and rawEvade or 0
        local evadePerc = m_clamp(evadeValue / 50, 0, 1)
    
        if evadePerc <= 0.02 then
            setBarGroupVisible(c.EvadeBar, false)
        else
            setBarGroupVisible(c.EvadeBar, true)
    
            c.EvadeBar.Back.Position = v2_new(eX, eY)
            c.EvadeBar.Back.Size = v2_new(eWidth, eH)
            c.EvadeBar.Outline.Position = v2_new(eX, eY)
            c.EvadeBar.Outline.Size = v2_new(eWidth, eH)
    
            local eFillH = m_floor(eH * evadePerc)
            c.EvadeBar.Fill.Position = v2_new(eX, eY + (eH - eFillH))
            c.EvadeBar.Fill.Size = v2_new(eWidth, eFillH)
    
            if evadePerc >= 0.99 then
                c.EvadeBar.Fill.Color = COLOR_PURPLE
                for i = 1, 9 do c.EvadeBar.Lines[i].Visible = false end
            else
                c.EvadeBar.Fill.Color = COLOR_CYAN:Lerp(COLOR_DARK_BLUE, 1 - evadePerc)
                for i = 1, 9 do
                    local lineY = m_floor(eY + (eH * 0.1 * i))
                    c.EvadeBar.Lines[i].From = v2_new(eX, lineY)
                    c.EvadeBar.Lines[i].To = v2_new(eX + eWidth, lineY)
                    c.EvadeBar.Lines[i].Visible = true
                end
            end
        end
    end

    return { Render = Render, Hide = Hide }
end

return EvadeBar
