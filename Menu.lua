local Menu = {}

function Menu.new(Title, ToggleKey)
    local Input = game:GetService("UserInputService")
    local Actions = game:GetService("ContextActionService")
    local CoreGui = game:GetService("CoreGui")
    local RunService = game:GetService("RunService")
    local ScrollAction = "CatstarMenuScroll"
    local Window = {Items = {}, Scroll = 0, Connections = {}, Drawings = {}, Visible = true, Reveal = 1, PopupReveal = 0, Destroyed = false}
    local Colors = {
        Background = Color3.fromRGB(242, 242, 247),
        Row = Color3.fromRGB(255, 255, 255),
        Hover = Color3.fromRGB(246, 249, 255),
        Pressed = Color3.fromRGB(225, 237, 255),
        DisabledRow = Color3.fromRGB(218, 218, 224),
        DisabledText = Color3.fromRGB(117, 117, 125),
        DisabledControl = Color3.fromRGB(170, 170, 178),
        Border = Color3.fromRGB(210, 210, 215),
        Text = Color3.fromRGB(28, 28, 30), Muted = Color3.fromRGB(108, 108, 116),
        Accent = Color3.fromRGB(0, 122, 255), Green = Color3.fromRGB(52, 199, 89),
        SwitchOff = Color3.fromRGB(209, 209, 214),
    }
    local Position, Width, Height
    local Focus, Capture, Drag, Slider, ScrollDrag, Dropdown, PopupItem, Hovered
    local OptionScroll, Popup = 0, nil
    local Status = "Loading modules..."
    local Hits, Layer = {}, 0
    local Pools = {Square = {}, Text = {}, Circle = {}}
    local Used = {Square = 0, Text = 0, Circle = 0}
    local Render
    local RenderAlpha = 1
    local SyncingScroll = false
    local Animations = {}
    local AnimationConnection

    local function Blend(A, B, T)
        return Color3.new(A.R + (B.R - A.R) * T, A.G + (B.G - A.G) * T, A.B + (B.B - A.B) * T)
    end

    local function Animate(Object, Key, Target, Duration, OnDone)
        for Index = #Animations, 1, -1 do
            local Animation = Animations[Index]
            if Animation.Object == Object and Animation.Key == Key then table.remove(Animations, Index) end
        end
        local Start = Object[Key] or 0
        if math.abs(Target - Start) < 0.001 then
            Object[Key] = Target
            if OnDone then OnDone() end
            Render()
            return
        end
        Animations[#Animations + 1] = {Object = Object, Key = Key, Start = Start, Target = Target,
            Duration = Duration, Elapsed = 0, OnDone = OnDone}
        if AnimationConnection then return end
        AnimationConnection = RunService.RenderStepped:Connect(function(Dt)
            for Index = #Animations, 1, -1 do
                local Animation = Animations[Index]
                Animation.Elapsed = math.min(Animation.Duration, Animation.Elapsed + Dt)
                local T = Animation.Elapsed / Animation.Duration
                local Ease = 1 - (1 - T) ^ 3
                Animation.Object[Animation.Key] = Animation.Start + (Animation.Target - Animation.Start) * Ease
                if T >= 1 then
                    table.remove(Animations, Index)
                    if Animation.OnDone then Animation.OnDone() end
                end
            end
            Render()
            if #Animations == 0 then AnimationConnection:Disconnect(); AnimationConnection = nil end
        end)
    end

    local function SetDropdown(Item)
        Dropdown = Item
        if Item then
            PopupItem = Item
            Window.PopupReveal = 0
            Animate(Window, "PopupReveal", 1, 0.18)
        elseif PopupItem then
            local Closing = PopupItem
            Animate(Window, "PopupReveal", 0, 0.14, function()
                if not Dropdown and PopupItem == Closing then PopupItem = nil end
            end)
        end
    end

    local function Press(Item)
        Item.Press = 1
        Animate(Item, "Press", 0, 0.24)
    end

    local Gui = Instance.new("ScreenGui")
    Gui.Name = "CatstarInput"
    Gui.IgnoreGuiInset = true
    Gui.ResetOnSpawn = false
    Gui.DisplayOrder = 0
    Gui.Parent = CoreGui

    local Backing = Instance.new("Frame")
    Backing.Name = "InputSurface"
    Backing.BackgroundTransparency = 1
    Backing.BorderSizePixel = 0
    Backing.Active = true
    Backing.Parent = Gui

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Name = "ScrollInput"
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 0
    ScrollFrame.Active = true
    ScrollFrame.ScrollingEnabled = true
    ScrollFrame.Parent = Backing

    local TextBox = Instance.new("TextBox")
    TextBox.Name = "TextInput"
    TextBox.BackgroundTransparency = 1
    TextBox.TextTransparency = 1
    TextBox.TextStrokeTransparency = 1
    TextBox.ClearTextOnFocus = false
    TextBox.MultiLine = false
    TextBox.Visible = false
    TextBox.Parent = Backing

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
        Object.Transparency = RenderAlpha
        Object.ZIndex = 1000 + Layer
        for Key, Value in pairs(Properties) do Object[Key] = Value end
        Object.Transparency = RenderAlpha * (Properties.Transparency or 1)
        return Object
    end

    local function Box(X, Y, W, H, Color)
        Paint("Square", {Position = Vector2.new(X, Y), Size = Vector2.new(math.max(0, W), math.max(0, H)), Color = Color, Filled = true, Thickness = 1})
    end

    local function Circle(X, Y, Radius, Color)
        Paint("Circle", {Position = Vector2.new(X, Y), Radius = Radius, Color = Color, Filled = true, NumSides = 24, Thickness = 1})
    end

    local function Rounded(X, Y, W, H, Radius, Color)
        Radius = math.max(0, math.min(Radius, W / 2, H / 2))
        Box(X + Radius, Y, W - Radius * 2, H, Color)
        Box(X, Y + Radius, W, H - Radius * 2, Color)
        for _, CX in ipairs({X + Radius, X + W - Radius}) do
            Circle(CX, Y + Radius, Radius, Color)
            Circle(CX, Y + H - Radius, Radius, Color)
        end
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
        TextBox.Visible = false
        if TextBox:IsFocused() then TextBox:ReleaseFocus() end
        if Commit then Item.Value = Item.Edit; Callback(Item, Item.Value) end
    end

    Render = function()
        if Window.Destroyed then return end
        Hits, Layer = {}, 0
        Used.Square, Used.Text, Used.Circle = 0, 0, 0
        Popup = nil
        RenderAlpha = Window.Reveal
        if (Window.Visible or Window.Reveal > 0.001) and workspace.CurrentCamera then
            Measure()
            local X, Y = Position.X, Position.Y + (1 - Window.Reveal) * 12
            Rounded(X + 3, Y + 6, Width, Height, 20, Color3.fromRGB(190, 190, 198))
            Rounded(X, Y, Width, Height, 20, Colors.Border)
            Rounded(X + 1, Y + 1, Width - 2, Height - 2, 19, Colors.Background)
            Backing.Position = UDim2.fromOffset(X, Y)
            Backing.Size = UDim2.fromOffset(Width, Height)
            local Left, Right = X + 16, X + Width - 16
            local Top, Bottom = Y + 76, Y + Height - 42
            if Bottom > Top then
                local Total = 0
                for _, Item in ipairs(Window.Items) do Total = Total + Item.Height end
                local Space = math.max(1, Bottom - Top)
                Window.MaxScroll = math.max(0, Total - Space)
                Window.Scroll = math.max(0, math.min(Window.Scroll, Window.MaxScroll))
                ScrollFrame.Position = UDim2.fromOffset(0, Top - Y)
                ScrollFrame.Size = UDim2.fromOffset(Width, Space)
                ScrollFrame.CanvasSize = UDim2.fromOffset(0, Total)
                if ScrollFrame.CanvasPosition.Y ~= Window.Scroll then
                    SyncingScroll = true
                    ScrollFrame.CanvasPosition = Vector2.new(0, Window.Scroll)
                    SyncingScroll = false
                end
                Hit(X, Top, Width, Space, "Scroll", Window)
                local GroupY = Top - Window.Scroll
                for Index, Entry in ipairs(Window.Items) do
                    if Entry.Kind == "Section" then
                        local GroupHeight = 0
                        for Next = Index + 1, #Window.Items do
                            if Window.Items[Next].Kind == "Section" then break end
                            GroupHeight = GroupHeight + Window.Items[Next].Height
                        end
                        local GroupTop = math.max(Top, GroupY + Entry.Height)
                        local GroupBottom = math.min(Bottom, GroupY + Entry.Height + GroupHeight)
                        if GroupBottom > GroupTop then
                            Rounded(Left, GroupTop, Right - Left - 7, GroupBottom - GroupTop, 13, Colors.Row)
                        end
                    end
                    GroupY = GroupY + Entry.Height
                end
                local RowY = Top - Window.Scroll
                local DropdownY
                for Index, Item in ipairs(Window.Items) do
                    local H = Item.Height
                    if RowY >= Top and RowY + H <= Bottom then
                        local Kind = Item.Kind
                        local Available = Enabled(Item)
                        local LabelColor = Available and Colors.Text or Colors.DisabledText
                        local ValueColor = Available and Colors.Accent or Colors.DisabledText
                        if Kind == "Section" then
                            Text(string.upper(Item.Title), Left + 9, RowY + 19, Colors.Muted, 12, Right - Left - 12)
                        else
                            local RowColor = Available and (Item.Press > 0 and Blend(Colors.Row, Colors.Pressed, Item.Press) or (Hovered == Item and Colors.Hover or Colors.Row)) or Colors.DisabledRow
                            if RowColor ~= Colors.Row then Rounded(Left + 1, RowY + 1, Right - Left - 9, H - 2, 11, RowColor) end
                            local Indent = Item.Args.Parent and 28 or 14
                            if Item.Args.Parent then
                                Box(Left + 15, RowY + 15, 2, H - 30, Available and Colors.Border or Colors.DisabledControl)
                            end
                            local Reserve = Kind == "Dropdown" and 235 or ((Kind == "Keybind" or Kind == "Toggle") and 90 or 75)
                            Text(Item.Title, Left + Indent, RowY + (Kind == "Slider" and 10 or 14), LabelColor, 14, Right - Left - Reserve - Indent)
                            if Kind == "Toggle" then
                                local TrackColor = Available and Blend(Colors.SwitchOff, Colors.Green, Item.Switch) or Colors.DisabledControl
                                Rounded(Right - 63, RowY + 11, 44, 25, 12.5, TrackColor)
                                Circle(Right - 50 + 19 * Item.Switch, RowY + 23.5, 10, Available and Colors.Row or Colors.DisabledRow)
                            elseif Kind == "Dropdown" then
                                Text(Item.Value ~= "" and Item.Value or "None", Right - 219, RowY + 14, ValueColor, 13, 181)
                                Text(Dropdown == Item and "^" or "v", Right - 31, RowY + 14, Available and Colors.Muted or Colors.DisabledText, 13)
                                if PopupItem == Item then DropdownY = RowY + H end
                            elseif Kind == "Button" then
                                Text(">", Right - 30, RowY + 14, ValueColor, 14)
                            elseif Kind == "Keybind" then
                                Text(Capture == Item and "..." or Item.Value, Right - 83, RowY + 14, ValueColor, 13, 62)
                            elseif Kind == "Slider" then
                                Text(Item.Args.Step and Item.Args.Step < 1 and string.format("%.2f", Item.Value) or Item.Value, Right - 66, RowY + 10, ValueColor, 13, 49)
                                local Range = Item.Args.Value
                                local TrackX, TrackW = Left + 14, Right - Left - 35
                                local Fraction = (Item.Value - Range.Min) / (Range.Max - Range.Min)
                                Box(TrackX, RowY + 43, TrackW, 4, Available and Colors.SwitchOff or Colors.DisabledControl)
                                Box(TrackX, RowY + 43, TrackW * Fraction, 4, Available and Colors.Accent or Colors.DisabledControl)
                                Circle(TrackX + TrackW * Fraction, RowY + 45, 9, Available and Colors.Accent or Colors.DisabledControl)
                                Circle(TrackX + TrackW * Fraction, RowY + 45, 6, Colors.Row)
                                Item.TrackX, Item.TrackW = TrackX, TrackW
                            elseif Kind == "Input" then
                                local Value = Focus == Item and Item.Edit .. "|" or Item.Value
                                Text(Value ~= "" and Value or Item.Args.Placeholder or "Type here...", Left + 14, RowY + 38, Focus == Item and Colors.Accent or LabelColor, 13, Right - Left - 36)
                                if Focus == Item then
                                    TextBox.Position = UDim2.fromOffset(Left - X + 8, RowY - Y + 3)
                                    TextBox.Size = UDim2.fromOffset(Right - Left - 18, H - 7)
                                end
                            end
                            local Next = Window.Items[Index + 1]
                            if Next and Next.Kind ~= "Section" then Box(Left + 16, RowY + H - 1, Right - Left - 39, 1, Colors.Border) end
                            if Available then
                                local HitTop = math.max(Top, RowY + 2)
                                local HitBottom = math.min(Bottom, RowY + H - 3)
                                if HitBottom > HitTop then Hit(Left, HitTop, Right - Left - 7, HitBottom - HitTop, Kind, Item) end
                            end
                        end
                    end
                    RowY = RowY + H
                end
                if Window.MaxScroll > 0 then
                    local Thumb = math.max(24, Space * Space / Total)
                    Box(Right - 3, Top, 2, Space, Colors.Border)
                    local ThumbTop = Top + (Space - Thumb) * Window.Scroll / Window.MaxScroll
                    Box(Right - 4, ThumbTop, 4, Thumb, Colors.Muted)
                    Hit(Right - 9, Top, 12, Space, "ScrollBar", {Top = Top, Space = Space, Thumb = Thumb, ThumbTop = ThumbTop})
                end
                -- Drawing has no clipping, so cover the parts of rows outside the scroll area.
                Box(Left, Y + 1, Right - Left, Top - Y - 1, Colors.Background)
                Box(Left, Bottom, Right - Left, Y + Height - 1 - Bottom, Colors.Background)
                Box(Left, Y + 68, Right - Left, 1, Colors.Border)
                Box(Left, Y + Height - 38, Right - Left, 1, Colors.Border)
                Text(Title, X + 18, Y + 15, Colors.Text, 23, Width - 72)
                Text("JJS  /  Press " .. ToggleKey.Name .. " to hide", X + 19, Y + 45, Colors.Muted, 12, Width - 50)
                Circle(X + Width - 25, Y + 29, 14, Colors.Row)
                Text("-", X + Width - 29, Y + 15, Colors.Muted, 21)
                Hit(X, Y, Width - 44, 66, "Drag")
                Hit(X + Width - 43, Y + 6, 36, 42, "Hide")
                Text(Status, Left, Y + Height - 26, Colors.Muted, 11, Right - Left)
                if PopupItem and DropdownY and Window.PopupReveal > 0.001 then
                    local Options = PopupItem.Args.Options
                    local Count = math.min(#Options, 6, math.max(1, math.floor((Space - 12) / 36)))
                    OptionScroll = math.max(0, math.min(OptionScroll, #Options - Count))
                    local H = Count * 36 + 12
                    local PY = math.max(Top, math.min(DropdownY, Bottom - H)) + (1 - Window.PopupReveal) * 8
                    Popup = Dropdown and {X = Left + 4, Y = PY, W = Right - Left - 15, H = H, Count = Count} or nil
                    if Dropdown then Hit(X, Y, Width, Height, "CloseDropdown") end
                    RenderAlpha = Window.Reveal * Window.PopupReveal
                    Rounded(Left + 6, PY + 4, Right - Left - 15, H, 12, Color3.fromRGB(190, 190, 198))
                    Rounded(Left + 4, PY, Right - Left - 15, H, 12, Colors.Border)
                    Rounded(Left + 5, PY + 1, Right - Left - 17, H - 2, 11, Colors.Row)
                    for Index = 1, Count do
                        local Value = Options[OptionScroll + Index]
                        local OY = PY + 6 + (Index - 1) * 36
                        if Value == PopupItem.Value then Rounded(Left + 9, OY, Right - Left - 28, 34, 8, Colors.Accent) end
                        Text(Value ~= "" and Value or "None", Left + 18, OY + 9, Value == PopupItem.Value and Colors.Row or Colors.Text, 13, Right - Left - 48)
                        if Dropdown then Hit(Left + 9, OY, Right - Left - 28, 36, "Option", {Item = PopupItem, Value = Value}) end
                    end
                    if #Options > Count then
                        local TrackH = H - 16
                        local ThumbH = math.max(8, TrackH * Count / #Options)
                        Box(Right - 10, PY + 8 + (TrackH - ThumbH) * OptionScroll / (#Options - Count), 3, ThumbH, Colors.Muted)
                    end
                    RenderAlpha = Window.Reveal
                elseif not Dropdown then
                    Popup = nil
                end
            end
        end
        for Kind, Pool in pairs(Pools) do
            for Index = Used[Kind] + 1, #Pool do Pool[Index].Visible = false end
        end
    end

    function Window:SetVisible(Value)
        self.Visible = Value
        Gui.Enabled = Value
        FinishInput(true)
        Capture, Drag, Slider, ScrollDrag, Hovered = nil, nil, nil, nil, nil
        SetDropdown(nil)
        Animate(self, "Reveal", Value and 1 or 0, 0.22)
    end

    function Window:SetStatus(Value)
        Status = Value
        Render()
    end

    function Window:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        Actions:UnbindAction(ScrollAction)
        if AnimationConnection then AnimationConnection:Disconnect(); AnimationConnection = nil end
        for _, Connection in ipairs(self.Connections) do Connection:Disconnect() end
        for _, Slot in ipairs(self.Drawings) do Slot.Object:Remove() end
        Gui:Destroy()
        self.Connections, self.Drawings = {}, {}
    end

    function Window:Refresh() Render() end

    function Window:Add(Kind, Options)
        local Item = {Kind = Kind, Args = Options, Title = Options.Title, Enabled = true, Press = 0,
            Height = Kind == "Section" and 56 or ((Kind == "Slider" or Kind == "Input") and 70 or 50)}
        Item.Value = Kind == "Slider" and Options.Value.Default or Options.Value
        Item.Switch = Kind == "Toggle" and (Item.Value and 1 or 0) or 0
        function Item:SetTitle(Value) self.Title = Value; Render() end
        function Item:SetDesc(Value) self.Description = Value end
        function Item:SetEnabled(Value) self.Enabled = Value; Render() end
        function Item:Set(Value) self.Value = Value; if self.Kind == "Toggle" then Animate(self, "Switch", Value and 1 or 0, 0.2) else Render() end end
        function Item:SetValue(Value) self:Set(Value) end
        self.Items[#self.Items + 1] = Item
        if Options.Binding then
            Connect(Options.Binding.Changed, function()
                Item.Value = Options.Binding.Value
                if Kind == "Toggle" then Animate(Item, "Switch", Item.Value and 1 or 0, 0.2) else Render() end
            end)
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

    Connect(TextBox:GetPropertyChangedSignal("Text"), function()
        if Focus then Focus.Edit = TextBox.Text; Render() end
    end)
    Connect(TextBox.FocusLost, function()
        if Focus then FinishInput(true); Render() end
    end)
    Connect(ScrollFrame:GetPropertyChangedSignal("CanvasPosition"), function()
        if SyncingScroll or Window.Destroyed or not Window.Visible then return end
        FinishInput(true)
        Dropdown = nil
        Window.Scroll = ScrollFrame.CanvasPosition.Y
        Render()
    end)

    Connect(Input.InputBegan, function(Event, Processed)
        if Window.Destroyed then return end
        local Key = Event.KeyCode
        if Event.UserInputType == Enum.UserInputType.Keyboard then
            if Input:GetFocusedTextBox() then
                if Focus and Key == Enum.KeyCode.Escape then FinishInput(false); Render() end
                return
            end
            if Processed and not Focus and not Capture and Key ~= ToggleKey then return end
            if Dropdown and Key == Enum.KeyCode.Escape then SetDropdown(nil); Render(); return end
            if Capture then
                if Key ~= Enum.KeyCode.Escape and Key ~= ToggleKey and Key ~= Enum.KeyCode.Unknown then
                    Capture.Value = Key.Name
                    if Capture.Args.OnChanged then Capture.Args.OnChanged(Key.Name) end
                end
                Capture = nil
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
            if not Target then SetDropdown(nil) end
            if Target then
                local Kind, Item = Target.Kind, Target.Item
                if Kind == "Dropdown" then
                    Press(Item)
                    SetDropdown(Item)
                    OptionScroll = 0
                    for Index, Value in ipairs(Item.Args.Options) do if Value == Item.Value then OptionScroll = math.max(0, Index - 3); break end end
                elseif Kind == "CloseDropdown" then SetDropdown(nil)
                elseif Kind == "Option" then
                    Item.Item.Value = Item.Value
                    Callback(Item.Item, Item.Value)
                    Press(Item.Item)
                    SetDropdown(nil)
                elseif Kind == "Hide" then Window:SetVisible(false)
                elseif Kind == "Drag" then Drag = Point - Position
                elseif Kind == "Toggle" then Item.Value = not Item.Value; Press(Item); Callback(Item, Item.Value); Animate(Item, "Switch", Item.Value and 1 or 0, 0.2)
                elseif Kind == "Button" then Press(Item); task.spawn(function() Callback(Item); Render() end)
                elseif Kind == "Keybind" then Press(Item); Capture = Item
                elseif Kind == "Input" then
                    Press(Item)
                    Focus = Item
                    Item.Edit = Item.Value or ""
                    TextBox.Text = Item.Edit
                    TextBox.Visible = true
                    TextBox:CaptureFocus()
                elseif Kind == "Slider" then Press(Item); Slider = Item; SetSlider(Item, Point.X)
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
            else
                local NextHover
                for Index = #Hits, 1, -1 do
                    if Inside(Point, Hits[Index]) and Hits[Index].Item and Hits[Index].Item.Kind then NextHover = Hits[Index].Item; break end
                end
                if Hovered ~= NextHover then Hovered = NextHover; Render() end
            end

        end
    end)
    Actions:BindActionAtPriority(ScrollAction, function(_, InputState, Event)
        if Window.Destroyed or not Window.Visible or not Position or not workspace.CurrentCamera then return Enum.ContextActionResult.Pass end
        local Point = Input:GetMouseLocation()
        if not Inside(Point, {X = Position.X, Y = Position.Y, W = Width, H = Height}) then return Enum.ContextActionResult.Pass end
        if InputState == Enum.UserInputState.Change then
            FinishInput(true)
            Capture, Slider = nil, nil
            if Dropdown and Popup and Inside(Point, Popup) then
                OptionScroll = math.max(0, math.min(#Dropdown.Args.Options - Popup.Count, OptionScroll - Event.Position.Z))
                Render()
            else
                SetDropdown(nil)
                local TargetScroll = math.max(0, math.min(Window.MaxScroll, Window.Scroll - Event.Position.Z * 47))
                Animate(Window, "Scroll", TargetScroll, 0.2)
            end
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.ContextActionPriority.High.Value + 1, Enum.UserInputType.MouseWheel)

    Connect(Input.InputEnded, function(Event)
        if Event.UserInputType == Enum.UserInputType.MouseButton1 then Drag, Slider, ScrollDrag = nil, nil, nil end
    end)
    Connect(Input.WindowFocusReleased, function()
        Drag, Slider, Capture, ScrollDrag, Hovered = nil, nil, nil, nil, nil
        SetDropdown(nil)
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

