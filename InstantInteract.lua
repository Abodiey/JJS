local InstantInteract = {}

-- Localize Services & Core API
local cloneref = cloneref
local game = game
local ProximityPromptService = cloneref(game:GetService("ProximityPromptService"))

-- Localize Global Engine Functions
local pairs = pairs
local table = table
local table_insert = table.insert
local table_clear = table.clear

-- Separate weak tables to eliminate per-prompt table allocations
local originalDurations = setmetatable({}, {__mode = "k"})
local originalDistances = setmetatable({}, {__mode = "k"})

-- Connection trackers
local promptShownConn = nil
local promptHiddenConn = nil

-- Completely cleans up connections and restores existing overridden prompts
local function cleanupInstantInteract()
    if promptShownConn then promptShownConn:Disconnect() promptShownConn = nil end
    if promptHiddenConn then promptHiddenConn:Disconnect() promptHiddenConn = nil end

    -- Restore durations
    for prompt, originalDuration in pairs(originalDurations) do
        if prompt and prompt.Parent then
            prompt.HoldDuration = originalDuration
        end
    end
    
    -- Restore distances
    for prompt, originalDistance in pairs(originalDistances) do
        if prompt and prompt.Parent then
            prompt.MaxActivationDistance = originalDistance
        end
    end

    table_clear(originalDurations)
    table_clear(originalDistances)
end

function InstantInteract.Init(State)
    local toggleObject = State.Toggles.InstantInteract

    local function handleToggleChange()
        local isEnabled = toggleObject.Value

        if isEnabled then
            if not promptShownConn then
                promptShownConn = ProximityPromptService.PromptShown:Connect(function(prompt)
                    if not prompt then return end
                    
                    local cachedDistance = originalDistances[prompt]
                    local cachedDuration = originalDurations[prompt]

                    -- If we haven't logged this prompt yet, or if the engine reset its distance 
                    -- below the multiplier threshold while hidden, re-verify its baseline
                    if not cachedDistance or prompt.MaxActivationDistance == cachedDistance then
                        cachedDistance = prompt.MaxActivationDistance
                        cachedDuration = prompt.HoldDuration
                        
                        originalDistances[prompt] = cachedDistance
                        originalDurations[prompt] = cachedDuration
                    end

                    -- Apply modifications safely using baseline upvalues
                    if cachedDuration and cachedDuration > 0 then
                        prompt.HoldDuration = 0
                    end
                    
                    if cachedDistance then
                        local targetDistance = cachedDistance * 2
                        -- Apply a strict hard cap of 20 studs maximum
                        if targetDistance > 20 then
                            prompt.MaxActivationDistance = 20
                        else
                            prompt.MaxActivationDistance = targetDistance
                        end
                    end
                end)
            end

            if not promptHiddenConn then
                promptHiddenConn = ProximityPromptService.PromptHidden:Connect(function(prompt)
                    if not prompt or not prompt.Parent then return end -- Skip if prompt was destroyed/removed
                    
                    local cachedDuration = originalDurations[prompt]
                    if cachedDuration then
                        prompt.HoldDuration = cachedDuration
                    end

                    local cachedDistance = originalDistances[prompt]
                    if cachedDistance then
                        prompt.MaxActivationDistance = cachedDistance
                    end
                end)
            end
        else
            cleanupInstantInteract()
        end
    end

    local toggleConn = toggleObject:GetPropertyChangedSignal("Value"):Connect(handleToggleChange)
    table_insert(State.Connections, toggleConn)

    handleToggleChange()
end

return InstantInteract
