local HealthBar = {}

function HealthBar.Init(State, Helpers)
    local toggleObject = State.Toggles.HealthBar
    local setBarGroupVisible = Helpers.setBarGroupVisible
    local m_floor = Helpers.m_floor
    local m_clamp = Helpers.m_clamp
    local v2_new = Helpers.v2_new
    local COLOR_GOLD = Helpers.COLOR_GOLD
    local COLOR_BRIGHT_GREEN = Helpers.COLOR_BRIGHT_GREEN
    local COLOR_RED = Helpers.COLOR_RED

    local function Hide(c)
        setBarGroupVisible(c.HealthBar, false)
    end

    local function Render(c, hum, scaleFactor, boxX, boxY, boxHeight, hideNameAndHealth)
        if not toggleObject.Value then Hide(c); return end
        -- 1. Health Bar
        local hWidth = m_floor(m_clamp(4 * scaleFactor, 2, 8))
        local hGap = m_floor(m_clamp(4 * scaleFactor, 2, 8))
        local hX = boxX - hWidth - hGap
        local hY = boxY
        local hH = boxHeight
    
        if hideNameAndHealth or hum.Health / hum.MaxHealth <= 0.02 then
            setBarGroupVisible(c.HealthBar, false)
        else
            local liveHpPerc = m_clamp(hum.Health / hum.MaxHealth, 0, 1)
            setBarGroupVisible(c.HealthBar, true)
    
            c.HealthBar.Back.Position = v2_new(hX, hY)
            c.HealthBar.Back.Size = v2_new(hWidth, hH)
            c.HealthBar.Outline.Position = v2_new(hX, hY)
            c.HealthBar.Outline.Size = v2_new(hWidth, hH)
    
            local fillH = m_floor(hH * liveHpPerc)
            c.HealthBar.Fill.Position = v2_new(hX, hY + (hH - fillH))
            c.HealthBar.Fill.Size = v2_new(hWidth, fillH)
    
            if liveHpPerc >= 0.99 then
                c.HealthBar.Fill.Color = COLOR_GOLD
                for i = 1, 9 do c.HealthBar.Lines[i].Visible = false end
            else
                c.HealthBar.Fill.Color = COLOR_BRIGHT_GREEN:Lerp(COLOR_RED, 1 - liveHpPerc)
                for i = 1, 9 do
                    local lineY = m_floor(hY + (hH * 0.1 * i))
                    c.HealthBar.Lines[i].From = v2_new(hX, lineY)
                    c.HealthBar.Lines[i].To = v2_new(hX + hWidth, lineY)
                    c.HealthBar.Lines[i].Visible = true
                end
            end
        end
    end

    return { Render = Render, Hide = Hide }
end

return HealthBar
