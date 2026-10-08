local Interface = {}
local URL = "https://raw.githubusercontent.com/Abodiey/iris-drawing-ui/refs/heads/main/dist/Iris.lua"

local function loadLibrary()
    for Attempt = 1, 3 do
        local Success, Response = pcall(request, {Url = URL .. "?t=" .. os.time(), Method = "GET"})
        if Success and type(Response) == "table" and Response.StatusCode == 200 and type(Response.Body) == "string" then
            local Chunk, Error = loadstring(Response.Body, "=Iris")
            if not Chunk then error(Error, 0) end
            local UI = Chunk()
            assert(type(UI) == "table" and type(UI.CreateWindow) == "function", "Invalid Iris library")
            return UI
        end
        if Attempt < 3 then task.wait(Attempt) end
    end
    error("Could not download Iris Drawing UI", 0)
end

function Interface.new()
    local UI = loadLibrary()
    local NativeWindow = UI:CreateWindow({Name = "CATSTAR", ToggleKey = "K", Size = Vector2.new(560, 640)})
    local Info = NativeWindow:AddSection("JJS")
    local VersionLabel = Info:AddLabel({Name = "Development"})
    local UpdatedLabel = Info:AddLabel({Name = "Run loader.lua for the published version"})
    local UpdateLabel = Info:AddLabel({Name = ""})
    local StatusLabel = Info:AddLabel({Name = "Loading modules..."})
    local Window = {Destroyed = false, Sections = {}, Controls = {}, Connections = {}}

    function Window:SetVisible(Value) NativeWindow:SetVisible(Value) end
    function Window:SetStatus(Value) if not self.Destroyed then StatusLabel:SetText(Value) end end
    function Window:SetVersion(Name, Detail)
        if self.Destroyed then return end
        VersionLabel:SetText(Name)
        local Updated, Status = Detail:match("^(.-) / (.*)$")
        UpdatedLabel:SetText(Updated or Detail)
        UpdateLabel:SetText(Status or "")
    end
    function Window:Notify(Title, Content)
        if not self.Destroyed then UI:Notify({Title = Title, Content = Content, Duration = 5}) end
    end
    function Window:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        for _, Connection in ipairs(self.Connections) do Connection:Disconnect() end
        UI:Destroy()
    end
    function Window:AddSection(Name)
        local Section = NativeWindow:AddSection(Name)
        self.Sections[Name] = Section
        return Section
    end

    -- Adapt JJS settings to Iris's public controls; rendering stays in the remote library.
    function Window:AddControl(Section, Kind, Args, HasStatus)
        local Component = {Args = Args, Enabled = true}
        local Control, Editor
        local function sync()
            if self.Destroyed or not Args.Binding then return end
            Control:SetValue(Args.Binding.Value, true)
            if Editor then Editor:SetValue(tostring(Args.Binding.Value), true) end
        end
        local function allowed()
            if self.Destroyed then return false end
            if not Component.Enabled then
                self:Notify(Args.Title, "Module is loading or unavailable")
                sync()
                return false
            end
            if Args.Parent and not Args.Parent.Value then
                self:Notify(Args.Title, "Enable its main toggle first")
                sync()
                return false
            end
            return true
        end
        local Options = {Name = Args.Title}
        if Kind == "Button" then
            Options.Callback = function()
                if allowed() and Args.Callback then
                    task.spawn(function()
                        local Success, Error = pcall(Args.Callback)
                        if not Success then warn(Args.Title .. ": " .. tostring(Error)); self:SetStatus("Could not run " .. Args.Title) end
                    end)
                end
            end
        elseif Kind == "Keybind" then
            Options.Default = Args.Value
            Options.OnChanged = function(Value)
                if allowed() and Args.OnChanged then Args.OnChanged(Value) end
            end
            Options.Callback = function(Pressed)
                if Pressed and allowed() and Args.Callback then Args.Callback() end
            end
        else
            Options.Default = Kind == "Slider" and Args.Value.Default or Args.Value
            Options.Callback = function(Value)
                if allowed() and Args.Callback then Args.Callback(Value) end
            end
        end
        if Kind == "Slider" then
            Options.Min, Options.Max, Options.Step = Args.Value.Min, Args.Value.Max, Args.Step
        elseif Kind == "Dropdown" then Options.Options = Args.Options
        elseif Kind == "Input" then
            Kind = "Textbox"
            Options.Placeholder = Args.Placeholder
        end
        Control = Section["Add" .. Kind](Section, Options)
        Component.Control = Control
        if Kind == "Slider" then
            Editor = Section:AddTextbox({Name = Args.Title .. " value", Default = tostring(Control:GetValue()), Callback = function(Text)
                local Value = tonumber(Text)
                if Value and Value == Value and math.abs(Value) < math.huge then Control:SetValue(Value) end
                Editor:SetValue(tostring(Control:GetValue()), true)
            end})
        end
        local Status = HasStatus and Section:AddLabel({Name = Args.Title .. " status"}) or nil
        function Component:SetEnabled(Value) self.Enabled = Value end
        function Component:SetTitle(Value) if Status then Status:SetText(Value) end end
        function Component:SetValue(Value)
            Control:SetValue(Value, true)
            if Editor then Editor:SetValue(tostring(Control:GetValue()), true) end
        end
        if Args.Binding then
            table.insert(self.Connections, Args.Binding.Changed:Connect(sync))
        end
        self.Controls[#self.Controls + 1] = Component
        return Component
    end
    function Window:Refresh()
        if self.Destroyed then return end
        for _, Component in ipairs(self.Controls) do
            if Component.Args.Binding then Component:SetValue(Component.Args.Binding.Value) end
        end
    end
    return Window
end

return Interface
