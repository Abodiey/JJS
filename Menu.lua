local Menu = {}

function Menu.new(Title, ToggleKey)
    local Input = game:GetService("UserInputService")
    local Actions = game:GetService("ContextActionService")
    local CoreGui = game:GetService("CoreGui")
    local RunService = game:GetService("RunService")
    local ScrollAction = "CatstarMenuScroll"
    local Window = {Items = {}, Scroll = 0, Connections = {}, Drawings = {}, Visible = true, Reveal = 1, Destroyed = false}
    local Colors = {
        Background = Color3.fromRGB(244, 245, 249),
        Shadow = Color3.fromRGB(184, 188, 198),
        CardBorder = Color3.fromRGB(226, 228, 235),
        Row = Color3.fromRGB(255, 255, 255),
        Hover = Color3.fromRGB(240, 245, 255),
        Pressed = Color3.fromRGB(225, 237, 255),
        DisabledRow = Color3.fromRGB(224, 226, 232),
        DisabledText = Color3.fromRGB(144, 147, 156),
        DisabledControl = Color3.fromRGB(170, 170, 178),
        Border = Color3.fromRGB(224, 226, 232),
        Text = Color3.fromRGB(28, 30, 36), Muted = Color3.fromRGB(112, 117, 128),
        Accent = Color3.fromRGB(0, 122, 255), Green = Color3.fromRGB(52, 199, 89),
        SwitchOff = Color3.fromRGB(209, 209, 214),
    }
    local Position, Width, Height
    local Focus, Capture, Drag, Slider, ScrollDrag, Dropdown, Hovered
    local Status = "Loading modules..."
    local VersionLabel, UpdateStatus = "", ""
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

    local function ItemHeight(Item)
        return Item.Height + (Item.ExpandedHeight or 0) * (Item.Expanded or 0)
    end

    local function SetDropdown(Item)
        if Dropdown == Item then Item = nil end
        local Previous = Dropdown
        Dropdown = Item
        if Previous and Previous ~= Item then Animate(Previous, "Expanded", 0, 0.18) end
        if Item then Animate(Item, "Expanded", 1, 0.2) end
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

    local function Text(Value, X, Y, Color, Size, MaxWidth, Center)
        local Object = Paint("Text", {Position = Vector2.new(X, Y), Text = tostring(Value), Color = Color or Colors.Text, Size = Size or 14, Font = 2, Center = Center or false, Outline = false})
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
        if Commit then
            local Value = Item.Edit
            if Item.Kind == "Slider" then
                Value = tonumber(Value)
                if not Value or Value ~= Value or math.abs(Value) == math.huge then return end
                local Range, Step = Item.Args.Value, Item.Args.Step or 1
                Value = math.clamp(Value, Range.Min, Range.Max)
                Value = math.clamp(Range.Min + math.floor((Value - Range.Min) / Step + 0.5) * Step, Range.Min, Range.Max)
            end
            Item.Value = Value
            Callback(Item, Value)
        end
    end

    Render = function()
        if Window.Destroyed then return end
        Hits, Layer = {}, 0
        Used.Square, Used.Text, Used.Circle = 0, 0, 0
        RenderAlpha = Window.Reveal
        if (Window.Visible or Window.Reveal > 0.001) and workspace.CurrentCamera then
            Measure()
            local X, Y = Position.X, Position.Y + (1 - Window.Reveal) * 12
            Rounded(X + 2, Y + 5, Width, Height, 24, Colors.Shadow)
            Rounded(X, Y, Width, Height, 24, Colors.Border)
            Rounded(X + 1, Y + 1, Width - 2, Height - 2, 23, Colors.Background)
            Backing.Position = UDim2.fromOffset(X, Y)
            Backing.Size = UDim2.fromOffset(Width, Height)
            local Left, Right = X + 18, X + Width - 18
            local Top, Bottom = Y + 94, Y + Height - 58
            if Bottom > Top then
                local Total = 0
                for _, Item in ipairs(Window.Items) do Total = Total + ItemHeight(Item) end
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
                            GroupHeight = GroupHeight + ItemHeight(Window.Items[Next])
                        end
                        local GroupTop = math.max(Top, GroupY + Entry.Height)
                        local GroupBottom = math.min(Bottom, GroupY + Entry.Height + GroupHeight)
                        if GroupBottom > GroupTop then
                            Rounded(Left, GroupTop, Right - Left - 9, GroupBottom - GroupTop, 16, Colors.CardBorder)
                            Rounded(Left + 1, GroupTop + 1, Right - Left - 11, math.max(0, GroupBottom - GroupTop - 2), 15, Colors.Row)
                        end
                    end
                    GroupY = GroupY + ItemHeight(Entry)
                end
                local RowY = Top - Window.Scroll
                for Index, Item in ipairs(Window.Items) do
                    local H = Item.Height
                    local FullH = ItemHeight(Item)
                    if RowY >= Top and RowY + H <= Bottom then
                        local Kind = Item.Kind
                        local Available = Enabled(Item)
                        local LabelColor = Available and Colors.Text or Colors.DisabledText
                        local ValueColor = Available and Colors.Accent or Colors.DisabledText
                        if Kind == "Section" then
                            Text(string.upper(Item.Title), Left + 14, RowY + 21, Colors.Muted, 11, Right - Left - 28)
                        else
                            local RowColor = Available and Blend(Blend(Colors.Row, Colors.Hover, Item.Hover or 0), Colors.Pressed, Item.Press) or Colors.DisabledRow
                            if RowColor ~= Colors.Row then Rounded(Left + 1, RowY + 1, Right - Left - 9, H - 2, 11, RowColor) end
                            local Indent = Item.Args.Parent and 32 or 16
                            if Item.Args.Parent then
                                Circle(Left + 21, RowY + H / 2, 2, Available and Colors.Muted or Colors.DisabledControl)
                            end
                            local Reserve = Kind == "Dropdown" and 235 or ((Kind == "Keybind" or Kind == "Slider") and 112 or 90)
                            Text(Item.Title, Left + Indent, RowY + ((Kind == "Slider" or Kind == "Input") and 12 or (H - 18) / 2), Kind == "Button" and ValueColor or LabelColor, Item.Args.Parent and 13 or 15, Right - Left - Reserve - Indent)
                            if Kind == "Toggle" then
                                local TrackColor = Available and Blend(Colors.SwitchOff, Colors.Green, Item.Switch) or Colors.DisabledControl
                                Rounded(Right - 66, RowY + (H - 28) / 2, 46, 28, 14, TrackColor)
                                Circle(Right - 52 + 18 * Item.Switch, RowY + H / 2 + 1, 11, Available and Colors.DisabledControl or Colors.DisabledRow)
                                Circle(Right - 52 + 18 * Item.Switch, RowY + H / 2, 11, Available and Colors.Row or Colors.DisabledRow)
                            elseif Kind == "Dropdown" then
                                Text(Item.Value ~= "" and Item.Value or "None", Right - 219, RowY + (H - 18) / 2, Available and Colors.Muted or Colors.DisabledText, 13, 177)
                                Text(Dropdown == Item and "v" or ">", Right - 31, RowY + (H - 18) / 2, ValueColor, 14)
                            elseif Kind == "Button" then
                                Text(">", Right - 31, RowY + (H - 18) / 2, ValueColor, 15)
                            elseif Kind == "Keybind" then
                                Rounded(Right - 96, RowY + (H - 30) / 2, 76, 30, 9, Available and Colors.Hover or Colors.DisabledRow)
                                Text(Capture == Item and "..." or Item.Value, Right - 58, RowY + (H - 18) / 2, ValueColor, 13, 60, true)
                            elseif Kind == "Slider" then
                                Rounded(Right - 96, RowY + 7, 76, 28, 9, Available and Colors.Hover or Colors.DisabledRow)
                                Text(Focus == Item and Item.Edit .. "|" or (Item.Args.Step and Item.Args.Step < 1 and string.format("%.2f", Item.Value) or Item.Value), Right - 58, RowY + 12, ValueColor, 13, 60, true)
                                Item.ValueX, Item.ValueY = Right - 96, RowY + 7
                                if Focus == Item then
                                    TextBox.Position = UDim2.fromOffset(Right - X - 96, RowY - Y + 7)
                                    TextBox.Size = UDim2.fromOffset(76, 28)
                                end
                                local Range = Item.Args.Value
                                local TrackX, TrackW = Left + Indent, Right - Left - Indent - 24
                                local Fraction = (Item.Value - Range.Min) / (Range.Max - Range.Min)
                                Rounded(TrackX, RowY + 49, TrackW, 4, 2, Available and Colors.SwitchOff or Colors.DisabledControl)
                                if Fraction > 0 then Rounded(TrackX, RowY + 49, TrackW * Fraction, 4, 2, Available and Colors.Accent or Colors.DisabledControl) end
                                Circle(TrackX + TrackW * Fraction, RowY + 51, 11, Available and Colors.Accent or Colors.DisabledControl)
                                Circle(TrackX + TrackW * Fraction, RowY + 51, 9, Available and Colors.Row or Colors.DisabledRow)
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
                            if (Next and Next.Kind ~= "Section") or (Kind == "Dropdown" and Item.Expanded > 0) then Box(Left + 16, RowY + H - 1, Right - Left - 39, 1, Colors.Border) end
                            if Available then
                                local HitTop = math.max(Top, RowY + 2)
                                local HitBottom = math.min(Bottom, RowY + H - 3)
                                if HitBottom > HitTop then Hit(Left, HitTop, Right - Left - 7, HitBottom - HitTop, Kind, Item) end
                            end
                        end
                    end
                    if Item.Kind == "Dropdown" and Item.Expanded > 0.001 then
                        local Limit = RowY + H + Item.ExpandedHeight * Item.Expanded
                        local Available = Enabled(Item)
                        for OptionIndex, Value in ipairs(Item.Args.Options) do
                            local OptionY = RowY + H + (OptionIndex - 1) * 36
                            if OptionY >= Top and OptionY + 36 <= Bottom and OptionY + 36 <= Limit + 0.01 then
                                if Value == Item.Value then
                                    Rounded(Left + 8, OptionY + 2, Right - Left - 23, 32, 8, Colors.Hover)
                                    Circle(Right - 31, OptionY + 18, 5, Available and Colors.Accent or Colors.DisabledControl)
                                end
                                Text(Value ~= "" and Value or "None", Left + 30, OptionY + 9, Available and Colors.Text or Colors.DisabledText, 13, Right - Left - 77)
                                if OptionIndex < #Item.Args.Options then Box(Left + 30, OptionY + 35, Right - Left - 62, 1, Colors.Border) end
                                if Available and Dropdown == Item then Hit(Left + 8, OptionY, Right - Left - 23, 36, "Option", {Item = Item, Value = Value}) end
                            end
                        end
                    end
                    RowY = RowY + FullH
                end
                if Window.MaxScroll > 0 then
                    local Thumb = math.max(24, Space * Space / Total)
                    Box(Right - 3, Top, 2, Space, Colors.Border)
                    local ThumbTop = Top + (Space - Thumb) * Window.Scroll / Window.MaxScroll
                    Rounded(Right - 4, ThumbTop, 3, Thumb, 1.5, Colors.DisabledControl)
                    Hit(Right - 9, Top, 12, Space, "ScrollBar", {Top = Top, Space = Space, Thumb = Thumb, ThumbTop = ThumbTop})
                end
                -- Drawing has no clipping, so cover the parts of rows outside the scroll area.
                Box(Left, Y + 1, Right - Left, Top - Y - 1, Colors.Background)
                Box(Left, Bottom, Right - Left, Y + Height - 1 - Bottom, Colors.Background)
                Box(Left, Y + 84, Right - Left, 1, Colors.Border)
                Box(Left, Y + Height - 54, Right - Left, 1, Colors.Border)
                local BadgeWidth = math.min(154, math.max(84, Width * 0.3))
                local BadgeX = X + Width - 62 - BadgeWidth
                Text(Title, X + 24, Y + 18, Colors.Text, 24, BadgeX - X - 38)
                Text("JJS / " .. ToggleKey.Name .. " to hide", X + 25, Y + 52, Colors.Muted, 12, Width - 80)
                if VersionLabel ~= "" then
                    Rounded(BadgeX, Y + 20, BadgeWidth, 26, 9, Colors.Row)
                    Text(VersionLabel, BadgeX + BadgeWidth / 2, Y + 26, Colors.Muted, 11, BadgeWidth - 14, true)
                end
                Circle(X + Width - 30, Y + 33, 15, Colors.Row)
                Box(X + Width - 35, Y + 32, 10, 2, Colors.Muted)
                Hit(X, Y, Width - 50, 84, "Drag")
                Hit(X + Width - 48, Y + 12, 36, 42, "Hide")
                local StatusColor = Status == "Ready" and Colors.Green or (Status:find("Failed", 1, true) and Color3.fromRGB(255, 69, 58) or Colors.Accent)
                Circle(Left + 5, Y + Height - 37, 3, StatusColor)
                Text(Status, Left + 17, Y + Height - 44, Colors.Muted, 12, Right - Left - 20)
                Text(UpdateStatus, Left, Y + Height - 24, Colors.Muted, 11, Right - Left)

            end
        end
        for Kind, Pool in pairs(Pools) do
            for Index = Used[Kind] + 1, #Pool do Pool[Index].Visible = false end
        end
    end

    function Window:SetVisible(Value)
        if Hovered then Hovered.Hover = 0 end
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

    function Window:SetVersion(Label, Updated)
        VersionLabel, UpdateStatus = Label, Updated
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

    function Window:Add(Kind, Options, After)
        local Item = {Kind = Kind, Args = Options, Title = Options.Title, Enabled = true, Press = 0,
            Height = Kind == "Section" and 52 or ((Kind == "Slider" or Kind == "Input") and 74 or 54)}
        Item.Value = Kind == "Slider" and Options.Value.Default or Options.Value
        Item.Switch = Kind == "Toggle" and (Item.Value and 1 or 0) or 0
        Item.Expanded = 0
        Item.ExpandedHeight = Kind == "Dropdown" and #Options.Options * 36 or 0
        function Item:SetTitle(Value) self.Title = Value; Render() end
        function Item:SetDesc(Value) self.Description = Value end
        function Item:SetEnabled(Value) self.Enabled = Value; Render() end
        function Item:Set(Value) self.Value = Value; if self.Kind == "Toggle" then Animate(self, "Switch", Value and 1 or 0, 0.2) else Render() end end
        function Item:SetValue(Value) self:Set(Value) end
        local Index = After and table.find(self.Items, After)
        if Index then table.insert(self.Items, Index + 1, Item)
        else self.Items[#self.Items + 1] = Item end
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
                elseif Kind == "Slider" then
                    Press(Item)
                    if Point.X >= Item.ValueX and Point.X <= Item.ValueX + 76 and Point.Y >= Item.ValueY and Point.Y <= Item.ValueY + 28 then
                        Focus = Item
                        Item.Edit = tostring(Item.Value)
                        TextBox.Text = Item.Edit
                        TextBox.Visible = true
                        Render()
                        TextBox:CaptureFocus()
                    else
                        if Focus then FinishInput(true) end
                        Slider = Item
                        SetSlider(Item, Point.X)
                    end
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
                if Hovered ~= NextHover then
                    local Previous = Hovered
                    Hovered = NextHover
                    if Previous then Animate(Previous, "Hover", 0, 0.14) end
                    if NextHover then Animate(NextHover, "Hover", 1, 0.14) end
                end
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
            local Pending = Window.Scroll
            for _, Animation in ipairs(Animations) do
                if Animation.Object == Window and Animation.Key == "Scroll" then Pending = Animation.Target end
            end
            local TargetScroll = math.max(0, math.min(Window.MaxScroll, Pending - Event.Position.Z * 47))
            Animate(Window, "Scroll", TargetScroll, 0.2)
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.ContextActionPriority.High.Value + 1, Enum.UserInputType.MouseWheel)

    Connect(Input.InputEnded, function(Event)
        if Event.UserInputType == Enum.UserInputType.MouseButton1 then Drag, Slider, ScrollDrag = nil, nil, nil end
    end)
    Connect(Input.WindowFocusReleased, function()
        if Hovered then Hovered.Hover = 0 end
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

