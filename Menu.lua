local Menu = {}

function Menu.new(Title, ToggleKey)
    local Input = game:GetService("UserInputService")
    local Window = {Items = {}, Scroll = 0, Connections = {}, Drawings = {}, Visible = true, Destroyed = false}
    local Colors = {
        Background = Color3.fromRGB(16, 19, 25), Sidebar = Color3.fromRGB(21, 25, 33),
        Row = Color3.fromRGB(26, 31, 40), Border = Color3.fromRGB(43, 51, 64),
        Text = Color3.fromRGB(233, 238, 246), Muted = Color3.fromRGB(144, 157, 176),
        Accent = Color3.fromRGB(102, 222, 191), Dark = Color3.fromRGB(13, 40, 34),
    }
    local Position, Width, Height
    local Focus, Capture, Drag, Slider, ScrollDrag
    local Status = "Loading modules..."
    local Hits, Layer = {}, 0
    local Pools = {Square = {}, Text = {}}
    local Used = {Square = 0, Text = 0}
    local Render

    local function Connect(Signal, Callback)
        local Connection = Signal:Connect(Callback)
        Window.Connections[#Window.Connections + 1] = Connection
        return Connection
    end

    local function Measure()
        local Viewport = workspace.CurrentCamera.ViewportSize
        Width, Height = math.max(1, math.min(560, Viewport.X - 16)), math.max(1, math.min(650, Viewport.Y - 16))
        Position = Position or Vector2.new(math.floor((Viewport.X - Width) / 2), math.floor((Viewport.Y - Height) / 2))
        Position = Vector2.new(math.max(0, math.min(Position.X, Viewport.X - Width)), math.max(0, math.min(Position.Y, Viewport.Y - Height)))
    end

    local function Paint(Kind, Properties)
        Used[Kind] = Used[Kind] + 1
        Layer = Layer + 1
        local Pool = Pools[Kind]
        local Object = Pool[Used[Kind]]
        if not Object then
            Object = Drawing.new(Kind)
            Pool[Used[Kind]] = Object
            Window.Drawings[#Window.Drawings + 1] = {Object = Object}
        end
        Object.Visible = true
        Object.Transparency = 1
        Object.ZIndex = 1000 + Layer
        for Key, Value in pairs(Properties) do Object[Key] = Value end
        return Object
    end

    local function Box(X, Y, W, H, Color)
        Paint("Square", {Position = Vector2.new(X, Y), Size = Vector2.new(math.max(0, W), math.max(0, H)), Color = Color, Filled = true, Thickness = 1})
    end

    local function Text(Value, X, Y, Color, Size, MaxWidth)
        local Object = Paint("Text", {Position = Vector2.new(X, Y), Text = tostring(Value), Color = Color or Colors.Text, Size = Size or 14, Font = 2, Center = false, Outline = false})
        if MaxWidth and Object.TextBounds.X > MaxWidth then
            local Short = tostring(Value)
            while #Short > 0 and Object.TextBounds.X > MaxWidth do
                Short = Short:sub(1, -2)
                Object.Text = Short .. "..."
            end
        end
    end

    local function Hit(X, Y, W, H, Kind, Item)
        Hits[#Hits + 1] = {X = X, Y = Y, W = W, H = H, Kind = Kind, Item = Item}
    end

    local function Inside(Point, Rect)
        return Point.X >= Rect.X and Point.X <= Rect.X + Rect.W and Point.Y >= Rect.Y and Point.Y <= Rect.Y + Rect.H
    end

    local function Enabled(Item)
        return Item.Enabled and (not Item.Args.Parent or Item.Args.Parent.Value)
    end

    local function Callback(Item, Value)
        if not Item.Args.Callback then return end
        local Success, Error = pcall(Item.Args.Callback, Value)
        if not Success then
            warn(Item.Title .. ": " .. tostring(Error))
            Status = "Could not run " .. Item.Title
        end
    end

    local function FinishInput(Commit)
        if not Focus then return end
        local Item = Focus
        Focus = nil
        if Commit then Item.Value = Item.Edit; Callback(Item, Item.Value) end
    end

    Render = function()
        if Window.Destroyed then return end
        Hits, Layer = {}, 0
        Used.Square, Used.Text = 0, 0
        if Window.Visible and workspace.CurrentCamera then
            Measure()
            local X, Y = Position.X, Position.Y
            Box(X + 3, Y + 4, Width, Height, Color3.fromRGB(7, 9, 12))
            Box(X, Y, Width, Height, Colors.Border)
            Box(X + 1, Y + 1, Width - 2, Height - 2, Colors.Background)
            Box(X + 1, Y + 1, Width - 2, 3, Colors.Accent)
            Text(Title, X + 18, Y + 16, Colors.Text, 21, Width - 72)
            Text("JJS  /  " .. ToggleKey.Name .. " to show or hide", X + 19, Y + 44, Colors.Muted, 12, Width - 50)
            Hit(X, Y, Width - 44, 66, "Drag")
            Text("-", X + Width - 29, Y + 15, Colors.Muted, 21)
            Hit(X + Width - 43, Y + 6, 36, 42, "Hide")
            local Left, Right = X + 16, X + Width - 16
            Box(Left, Y + 68, Right - Left, 1, Colors.Border)
            local Top, Bottom = Y + 76, Y + Height - 42
            if Bottom > Top then
                local Total = 0
                for _, Item in ipairs(Window.Items) do Total = Total + Item.Height end
                local Space = math.max(1, Bottom - Top)
                Window.MaxScroll = math.max(0, Total - Space)
                Window.Scroll = math.max(0, math.min(Window.Scroll, Window.MaxScroll))
                Hit(X, Top, Width, Space, "Scroll", Window)
                local RowY = Top - Window.Scroll
                for _, Item in ipairs(Window.Items) do
                    local H = Item.Height
                    if RowY >= Top and RowY + H <= Bottom then
                        local Kind = Item.Kind
                        local Available = Enabled(Item)
                        local Color = Available and Colors.Text or Colors.Muted
                        if Kind == "Section" then
                            Box(Left, RowY + 4, Right - Left - 10, 1, Colors.Border)
                            Text(Item.Title, Left + 2, RowY + 13, Colors.Accent, 13, Right - Left - 8)
                        else
                            Box(Left, RowY + 2, Right - Left - 7, H - 5, Colors.Row)
                            local Indent = Item.Args.Parent and 22 or 12
                            if Item.Args.Parent then Box(Left + 11, RowY + 13, 2, 10, Colors.Border) end
                            local Reserve = (Kind == "Keybind" or Kind == "Toggle") and 90 or 35
                            Text(Item.Title, Left + Indent, RowY + 10, Color, 13, Right - Left - Reserve - Indent)
                            if Kind == "Toggle" then
                                Box(Right - 49, RowY + 11, 29, 15, Item.Value and Available and Colors.Accent or Colors.Border)
                                Box(Right - (Item.Value and 33 or 46), RowY + 14, 10, 9, Item.Value and Colors.Dark or Colors.Muted)
                            elseif Kind == "Button" then
                                Text(">", Right - 30, RowY + 10, Colors.Accent, 14)
                            elseif Kind == "Keybind" then
                                Text(Capture == Item and "..." or Item.Value, Right - 83, RowY + 10, Colors.Accent, 13, 62)
                            elseif Kind == "Slider" then
                                Text(Item.Args.Step and Item.Args.Step < 1 and string.format("%.2f", Item.Value) or Item.Value, Right - 66, RowY + 9, Colors.Accent, 13, 49)
                                local Range = Item.Args.Value
                                local TrackX, TrackW = Left + 12, Right - Left - 32
                                local Fraction = (Item.Value - Range.Min) / (Range.Max - Range.Min)
                                Box(TrackX, RowY + 37, TrackW, 3, Colors.Border)
                                Box(TrackX, RowY + 37, TrackW * Fraction, 3, Colors.Accent)
                                Box(TrackX + TrackW * Fraction - 3, RowY + 33, 6, 11, Colors.Text)
                                Item.TrackX, Item.TrackW = TrackX, TrackW
                            elseif Kind == "Input" then
                                local Value = Focus == Item and Item.Edit .. "|" or Item.Value
                                Text(Value ~= "" and Value or Item.Args.Placeholder or "Type here...", Left + 12, RowY + 33, Focus == Item and Colors.Accent or Colors.Muted, 13, Right - Left - 36)
                            end
                            if Available then Hit(Left, RowY + 2, Right - Left - 7, H - 5, Kind, Item) end
                        end
                    end
                    RowY = RowY + H
                end
                if Window.MaxScroll > 0 then
                    local Thumb = math.max(20, Space * Space / Total)
                    Box(Right - 3, Top, 2, Space, Colors.Border)
                    local ThumbTop = Top + (Space - Thumb) * Window.Scroll / Window.MaxScroll
                    Box(Right - 4, ThumbTop, 4, Thumb, Colors.Accent)
                    Hit(Right - 9, Top, 12, Space, "ScrollBar", {Top = Top, Space = Space, Thumb = Thumb, ThumbTop = ThumbTop})
                end
            end
            Box(Left, Y + Height - 38, Right - Left, 1, Colors.Border)
            Text(Status, Left, Y + Height - 26, Colors.Muted, 11, Right - Left)
        end
        for Kind, Pool in pairs(Pools) do
            for Index = Used[Kind] + 1, #Pool do Pool[Index].Visible = false end
        end
    end

    function Window:SetVisible(Value)
        self.Visible = Value
        FinishInput(true)
        Capture, Drag, Slider, ScrollDrag = nil, nil, nil, nil
        Render()
    end

    function Window:SetStatus(Value)
        Status = Value
        Render()
    end

    function Window:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        for _, Connection in ipairs(self.Connections) do Connection:Disconnect() end
        for _, Slot in ipairs(self.Drawings) do Slot.Object:Remove() end
        self.Connections, self.Drawings = {}, {}
    end

    function Window:Refresh() Render() end

    function Window:Add(Kind, Options)
        local Item = {Kind = Kind, Args = Options, Title = Options.Title, Enabled = true,
            Height = Kind == "Section" and 40 or ((Kind == "Slider" or Kind == "Input") and 59 or 38)}
        Item.Value = Kind == "Slider" and Options.Value.Default or Options.Value
        function Item:SetTitle(Value) self.Title = Value; Render() end
        function Item:SetDesc(Value) self.Description = Value end
        function Item:SetEnabled(Value) self.Enabled = Value; Render() end
        function Item:Set(Value) self.Value = Value; Render() end
        function Item:SetValue(Value) self:Set(Value) end
        self.Items[#self.Items + 1] = Item
        if Options.Binding then
            Connect(Options.Binding.Changed, function() Item.Value = Options.Binding.Value; Render() end)
        end
        if Options.Parent then Connect(Options.Parent.Changed, Render) end
        return Item
    end

    local function SetSlider(Item, X)
        local Range = Item.Args.Value
        local Fraction = math.max(0, math.min(1, (X - Item.TrackX) / Item.TrackW))
        local Step = Item.Args.Step or 1
        local Value = math.max(Range.Min, math.min(Range.Max, Range.Min + math.floor(Fraction * (Range.Max - Range.Min) / Step + 0.5) * Step))
        if Value ~= Item.Value then Item.Value = Value; Callback(Item, Value); Render() end
    end

    local Shifted = {One = "!", Two = "@", Three = "#", Four = "$", Five = "%", Six = "^", Seven = "&", Eight = "*", Nine = "(", Zero = ")", Minus = "_", Equals = "+"}
    local Characters = {Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Minus = "-", Equals = "=", Space = " ", Period = "."}
    Connect(Input.InputBegan, function(Event, Processed)
        if Window.Destroyed then return end
        local Key = Event.KeyCode
        if Event.UserInputType == Enum.UserInputType.Keyboard then
            if Input:GetFocusedTextBox() then return end
            if Processed and not Focus and not Capture and Key ~= ToggleKey then return end
            if Capture then
                if Key ~= Enum.KeyCode.Escape and Key ~= ToggleKey and Key ~= Enum.KeyCode.Unknown then Capture.Value = Key.Name end
                Capture = nil
                Render()
                return
            end
            if Focus then
                local Name = Key.Name
                if Key == Enum.KeyCode.Return then FinishInput(true)
                elseif Key == Enum.KeyCode.Escape then FinishInput(false)
                elseif Key == Enum.KeyCode.Backspace then Focus.Edit = Focus.Edit:sub(1, -2)
                elseif (Input:IsKeyDown(Enum.KeyCode.LeftControl) or Input:IsKeyDown(Enum.KeyCode.RightControl)) then
                    if Name == "V" and getclipboard then
                        local Success, Value = pcall(getclipboard)
                        if Success and type(Value) == "string" then Focus.Edit = (Focus.Edit .. Value:gsub("[^%w_ .%-]", "")):sub(1, 64) end
                    elseif Name == "A" then Focus.Edit = "" end
                else
                    local Shift = Input:IsKeyDown(Enum.KeyCode.LeftShift) or Input:IsKeyDown(Enum.KeyCode.RightShift)
                    local Character = #Name == 1 and (Shift and Name or Name:lower()) or (Shift and Shifted[Name] or Characters[Name])
                    if Character then Focus.Edit = (Focus.Edit .. Character):sub(1, 64) end
                end
                Render()
                return
            end
            if Key == ToggleKey then Window:SetVisible(not Window.Visible); return end
            for _, Item in ipairs(Window.Items) do
                if Item.Kind == "Keybind" and Item.Value == Key.Name and Enabled(Item) then Callback(Item); Render() end
            end
        elseif Event.UserInputType == Enum.UserInputType.MouseButton1 and Window.Visible then
            local Point = Input:GetMouseLocation()
            local Target
            for Index = #Hits, 1, -1 do
                if Inside(Point, Hits[Index]) then Target = Hits[Index]; break end
            end
            if Focus and (not Target or Target.Item ~= Focus) then FinishInput(true) end
            Capture = nil
            if Target then
                local Kind, Item = Target.Kind, Target.Item
                if Kind == "Hide" then Window:SetVisible(false)
                elseif Kind == "Drag" then Drag = Point - Position
                elseif Kind == "Toggle" then Item.Value = not Item.Value; Callback(Item, Item.Value)
                elseif Kind == "Button" then task.spawn(function() Callback(Item); Render() end)
                elseif Kind == "Keybind" then Capture = Item
                elseif Kind == "Input" then Focus = Item; Item.Edit = Item.Value or ""
                elseif Kind == "Slider" then Slider = Item; SetSlider(Item, Point.X)
                elseif Kind == "ScrollBar" then
                    ScrollDrag = Item
                    Item.Offset = Point.Y >= Item.ThumbTop and Point.Y <= Item.ThumbTop + Item.Thumb and (Point.Y - Item.ThumbTop) or Item.Thumb / 2
                    Window.Scroll = math.max(0, math.min(Window.MaxScroll, (Point.Y - Item.Top - Item.Offset) / math.max(1, Item.Space - Item.Thumb) * Window.MaxScroll))
                end
            end
            Render()
        end
    end)

    Connect(Input.InputChanged, function(Event, Processed)
        if not Window.Visible or Window.Destroyed then return end
        if Event.UserInputType == Enum.UserInputType.MouseMovement then
            local Point = Input:GetMouseLocation()
            if Drag then Position = Point - Drag; Render()
            elseif Slider then SetSlider(Slider, Point.X)
            elseif ScrollDrag then
                Window.Scroll = math.max(0, math.min(Window.MaxScroll, (Point.Y - ScrollDrag.Top - ScrollDrag.Offset) / math.max(1, ScrollDrag.Space - ScrollDrag.Thumb) * Window.MaxScroll))
                Render()
            end
        elseif Event.UserInputType == Enum.UserInputType.MouseWheel then
            local Point = Input:GetMouseLocation()
            for _, Target in ipairs(Hits) do
                if Target.Kind == "Scroll" and Inside(Point, Target) then
                    FinishInput(true)
                    Capture, Slider = nil, nil
                    Target.Item.Scroll = Target.Item.Scroll - Event.Position.Z * 38
                    Render()
                    break
                end
            end
        end
    end)
    Connect(Input.InputEnded, function(Event)
        if Event.UserInputType == Enum.UserInputType.MouseButton1 then Drag, Slider, ScrollDrag = nil, nil, nil end
    end)
    Connect(Input.WindowFocusReleased, function()
        Drag, Slider, Capture, ScrollDrag = nil, nil, nil, nil
        FinishInput(true)
        Render()
    end)
    local CameraConnection
    local function BindCamera()
        if CameraConnection then CameraConnection:Disconnect() end
        if workspace.CurrentCamera then
            CameraConnection = Connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), Render)
        end
        Render()
    end
    Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), BindCamera)
    BindCamera()
    return Window
end

return Menu
