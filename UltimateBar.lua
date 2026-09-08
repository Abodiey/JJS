local UltimateBar = {}

function UltimateBar.Init(State, Helpers)
    local toggleObject = State.Toggles.UltimateBar
    local setBarGroupVisible = Helpers.setBarGroupVisible
    local v2_new = Helpers.v2_new
    local m_clamp = Helpers.m_clamp
    local m_floor = Helpers.m_floor
    local COLOR_BLACK = Helpers.COLOR_BLACK
    local MOVESET_COLORS = Helpers.MOVESET_COLORS
    local c3_fromHex = Helpers.c3_fromHex
    local c3_new = Helpers.c3_new
    local COLOR_WHITE = Helpers.COLOR_WHITE

    local function Hide(c)
        setBarGroupVisible(c.UltBar, false)
    end

    local function Render(c, uX, uY, uW, uHeight, ultValue, movesetName, fullyCustom, globalRainbowColor, globalRainbowHex, shouldUpdateHeavy, isThrottledFrame)
        if not toggleObject.Value then Hide(c); return end
        setBarGroupVisible(c.UltBar, true)
        c.UltBar.Back.Position = v2_new(uX, uY)
        c.UltBar.Back.Size = v2_new(uW, uHeight)
        c.UltBar.Outline.Position = v2_new(uX, uY)
        c.UltBar.Outline.Size = v2_new(uW, uHeight)
    
        local ultRatio = m_clamp(ultValue / 100, 0, 1)
    
        c.UltBar.Fill.Position = v2_new(uX, uY)
        c.UltBar.Fill.Size = v2_new(m_floor(uW * ultRatio), uHeight)
    
        if isThrottledFrame then
            if ultValue >= 100 then
                c.UltBar.Outline.Thickness = 1.5
                c.UltBar.Outline.Color = globalRainbowColor
                for i = 1, 9 do c.UltBar.Lines[i].Visible = false end
            else
                c.UltBar.Outline.Thickness = 1
                c.UltBar.Outline.Color = COLOR_BLACK
                for i = 1, 9 do
                    local lineX = m_floor(uX + (uW * 0.1 * i))
                    c.UltBar.Lines[i].From = v2_new(lineX, uY)
                    c.UltBar.Lines[i].To = v2_new(lineX, uY + uHeight)
                    c.UltBar.Lines[i].Visible = true
                end
            end
        end
        if shouldUpdateHeavy then
            local hexColor = MOVESET_COLORS[movesetName] or "FFFFFF"
            local usesCustomLook = false
            if movesetName == "Custom" or fullyCustom then
                usesCustomLook = true
                hexColor = globalRainbowHex
                c.UltBar.Fill.Color = globalRainbowColor
            else
                c.UltBar.Fill.Color = c3_fromHex("#" .. hexColor)
            end
            if hexColor == "000000" and not usesCustomLook then
                c.UltBar.Back.Color = c3_new(0.18, 0.18, 0.18)
                if ultValue < 100 then c.UltBar.Outline.Color = COLOR_WHITE end
            else
                c.UltBar.Back.Color = c3_new(0.05, 0.05, 0.05)
            end
        end
    end

    return { Render = Render, Hide = Hide }
end

return UltimateBar
