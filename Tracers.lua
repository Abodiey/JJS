local Tracers = {}

function Tracers.Init(State, Helpers)
    local toggleObject = State.Toggles.Tracers
    local getGradientColor = Helpers.getGradientColor
    local v2_new = Helpers.v2_new
    local m_floor = Helpers.m_floor

    local function Hide(c)
        c.Line.Visible = false
    end

    local function Render(c, sX, sY, root2D, feet2D, dist, shouldUpdateHeavy)
        if not toggleObject.Value then Hide(c); return end
        if shouldUpdateHeavy then c.LineColor = getGradientColor(dist / 600) end
        -- Tracer
        c.Line.Visible = true
        c.Line.Color = c.LineColor
        c.Line.From = v2_new(sX, sY)
        c.Line.To = v2_new(m_floor(root2D.X), m_floor(feet2D.Y))
    end

    return { Render = Render, Hide = Hide }
end

return Tracers
