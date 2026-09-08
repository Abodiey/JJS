local Train = {}

local Map = workspace:WaitForChild("Map")

local function GetPrompt()
    local Destructible = Map:FindFirstChild("Destructible")
    local Main = Destructible and Destructible:FindFirstChild("Model")
    Main = Main and Main:FindFirstChild("StationControl")

    local ButtonTrain = Main and Main:FindFirstChild("ButtonTrain")
    local Button1 = ButtonTrain and ButtonTrain:FindFirstChild("Button")
    local PromptParent = Button1 and Button1:FindFirstChild("Button")

    return PromptParent and PromptParent:FindFirstChild("Button")
end

function Train.Init(ButtonComponent, State)
    local function UpdateButtonText()
        if not ButtonComponent then return end
        
        if GetPrompt() then
            ButtonComponent:SetTitle("Spawn Train (Ready)")
        else
            ButtonComponent:SetTitle("Spawn Train (On Cooldown)")
        end
    end

    UpdateButtonText()

    local MapConnection = Map.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "Button" then
            UpdateButtonText()
        end
    end)
    table.insert(State.Connections, MapConnection)

    local MapRemoveConnection = Map.DescendantRemoving:Connect(function(descendant)
        if descendant.Name == "Button" then
            task.defer(UpdateButtonText)
        end
    end)
    table.insert(State.Connections, MapRemoveConnection)
end

function Train.Clicked()
    local Destructible = Map:FindFirstChild("Destructible")
    local Main = Destructible and Destructible:FindFirstChild("Model")
    Main = Main and Main:FindFirstChild("StationControl")

    local Prompt = GetPrompt()

    local Event = Main and Main:FindFirstChild("Handle")
    Event = Event and Event:FindFirstChild("Train")

    if Prompt and Event then
        Event:FireServer()
    end
end

return Train
