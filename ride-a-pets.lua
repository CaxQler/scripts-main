if not game:IsLoaded() then
    game.Loaded:Wait()
end
-- Services & Library
local Library = loadstring(game:HttpGetAsync("https://pastefy.app/YoX4PJmf/raw"))()
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local gameplatform = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name

local Window = Library:CreateWindow({
    Title = "Vlog",
    Subtitle = gameplatform,
    SubtitleColor = Color3.fromRGB(190, 140, 255),
    Logo = "rbxassetid://123904148959662",
    LogoSize = 32,
    SphereText = false,
    SphereWords = "ZX",
    SphereImage = "rbxassetid://123904148959662",
    SphereIconSize = 38
})

local GerenalTab = Window:CreateTab("Gerenal",true)
local GerenalPage = GerenalTab:CreatePage("gobal")

-- ====================== Config & State ======================
local DEBUG = true
local MATCH_RANGE = 15        
local COLLECTED_TIMEOUT = 10  
local IDLE_LOG_EVERY = 5      

local SelectedEggs = {}
local SelectedMethod = "Tween"
local TweenSpeed = 20
local AutoFarm = false
local CollectedEggs = {}

local SelectedGears = {}
local SelectedFood = {}
local FOOD_CATEGORY = "Food"

local TREE_MAX = 15
local TREE_RANGE = 400
local TREE_INTERVAL = 0.5
local TreeRunId = 0
local TreeList = {}
local ActiveHL = {}

local EGG_COLORS = {
    Common    = Color3.fromRGB(173, 173, 173),
    Rare      = Color3.fromRGB(0, 170, 255),
    Epic      = Color3.fromRGB(170, 85, 255),
    Legendary = Color3.fromRGB(255, 170, 0),
    Mythic    = Color3.fromRGB(255, 170, 255),
    Ethereal  = Color3.fromRGB(170, 170, 255),
    Divine    = Color3.fromRGB(255, 255, 0),
}
-- แก้ไข: ลบช่องว่างท้ายคำออกเพื่อให้การเปรียบเทียบชื่อไข่ถูกต้อง
local RARITY_ORDER = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Ethereal", "Divine"}
local EGG_HL_MAX = 10
local EGG_INTERVAL = 0.4

local ShowSet = {}
local ShowAll = true
local ESP = {}
local RunId = 0

local Step -- forward declare
local Busy = false
local lastIdleLog = 0

-- Notification & Player ESP Config
local NOTIFY_TIME = 6
local NOTIFY_MAX = 5
local POLL = 0.5
local BOTTOM_OFFSET = 110
local NotifySet = {}
local NotifyOn = false
local Order = 0
local Known = setmetatable({}, { __mode = "k" })
local SeenModels = setmetatable({}, { __mode = "k" })
local Gui, Holder

local PLAYER_HL_MAX = 8
local PLAYER_INTERVAL = 0.3
local COLOR_SELECTED = Color3.fromRGB(255, 60, 60)
local COLOR_OTHER    = Color3.fromRGB(80, 200, 255)
local AllOn = false
local SelectedPlayers = {}
local OptSet = {}
local OptAll = true


-- ====================== ALL FUNCTIONS ======================

local function dbg(...)
    if DEBUG then
        print("[AutoFarm]", ...)
    end
end

local function ToList(v)
    local out = {}
    if type(v) == "string" then
        out[1] = v
    elseif type(v) == "table" then
        if #v > 0 then
            for _, x in ipairs(v) do
                if type(x) == "string" then
                    table.insert(out, x)
                end
            end
        else
            for k, x in pairs(v) do
                if type(k) == "string" and x == true then
                    table.insert(out, k)
                elseif type(x) == "string" then
                    table.insert(out, x)
                end
            end
        end
    end
    return out
end

local function GetRoot()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function StripDash(name)
    return (name:gsub("%-+$", ""))
end

local function GetMyPlot()
    local Plots = workspace:FindFirstChild("Plots")
    if not Plots then return nil end

    for _, Plot in ipairs(Plots:GetChildren()) do
        local Data = Plot:FindFirstChild("Data")
        if Data then
            local Owner = Data:FindFirstChild("Owner")
            if Owner and Owner:IsA("ObjectValue") and Owner.Value == LocalPlayer then
                return Plot
            end
        end
    end
    return nil
end

local function GetPlotReturnPosition(plot)
    if not plot then return nil end

    local base = plot:FindFirstChild("Baseplate")
        or plot:FindFirstChild("Base")
        or plot:FindFirstChildWhichIsA("BasePart", true)

    if base then
        return base.Position + Vector3.new(0, 5, 0)
    end

    if plot:IsA("Model") then
        return plot:GetPivot().Position + Vector3.new(0, 5, 0)
    end
    return nil
end

local function BoxDistance(part, worldPos)
    local rel = part.CFrame:PointToObjectSpace(worldPos)
    local h = part.Size * 0.5
    local ex = math.max(math.abs(rel.X) - h.X, 0)
    local ey = math.max(math.abs(rel.Y) - h.Y, 0)
    local ez = math.max(math.abs(rel.Z) - h.Z, 0)
    return math.sqrt(ex * ex + ey * ey + ez * ez)
end

local function ClassifyEgg(worldPos)
    local spawns = workspace:FindFirstChild("EggSpawns")
    if not spawns then return nil end

    local bestPart, bestDist, bestVol
    for _, sp in ipairs(spawns:GetChildren()) do
        if sp:IsA("BasePart") then
            local d = BoxDistance(sp, worldPos)
            if d <= MATCH_RANGE then
                local vol = sp.Size.X * sp.Size.Y * sp.Size.Z
                if not bestDist or d < bestDist or (d == bestDist and vol < bestVol) then
                    bestPart, bestDist, bestVol = sp, d, vol
                end
            end
        end
    end

    if not bestPart then return nil end
    local active = not bestPart.Name:match("%-$")
    return StripDash(bestPart.Name), active
end

local function GetPrompt(model)
    return model:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function GetEggPos(model)
    local prompt = GetPrompt(model)
    if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
        return prompt.Parent.Position
    end
    local ok, pivot = pcall(function()
        return model:GetPivot().Position
    end)
    if ok then return pivot end
    return nil
end

local function GetAvailableEggs()
    local rendered = workspace:FindFirstChild("RenderedEggs")
    local list = {}
    local total = 0
    if not rendered then return list, total end

    for _, m in ipairs(rendered:GetChildren()) do
        if m:IsA("Model") then
            total += 1
            if not CollectedEggs[m] then
                local pos = GetEggPos(m)
                if pos then
                    local rarity, active = ClassifyEgg(pos)
                    if rarity and active then
                        table.insert(list, { model = m, rarity = rarity, pos = pos })
                    end
                end
            end
        end
    end
    return list, total
end

local function CountActiveSpawns(selectedSet)
    local spawns = workspace:FindFirstChild("EggSpawns")
    local n = 0
    if not spawns then return 0 end
    for _, sp in ipairs(spawns:GetChildren()) do
        if sp:IsA("BasePart") and not sp.Name:match("%-$") and selectedSet[sp.Name] then
            n += 1
        end
    end
    return n
end

local function IsEggStillAvailable(model)
    if not model or not model.Parent then return false end
    local pos = GetEggPos(model)
    if not pos then return false end
    local rarity, active = ClassifyEgg(pos)
    return rarity ~= nil and active == true
end

local function MarkAsCollected(egg)
    if not egg then return end
    CollectedEggs[egg] = true
    task.delay(COLLECTED_TIMEOUT, function()
        CollectedEggs[egg] = nil
    end)
end

local function TweenTo(targetPos, shouldContinue)
    local root = GetRoot()
    if not root then return false end

    local distance = (root.Position - targetPos).Magnitude
    local duration = math.clamp(distance / math.max(TweenSpeed, 1), 0.25, 7)

    dbg(string.format("Tween -> dist %.1f, time %.2fs", distance, duration))

    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        CFrame = CFrame.new(targetPos)
    })

    local finished = false
    local conn
    conn = tween.Completed:Connect(function()
        finished = true
        conn:Disconnect()
    end)

    tween:Play()

    local t0 = os.clock()
    local lastCheck = t0
    while not finished and (os.clock() - t0) < (duration + 1) do
        if not root.Parent then
            tween:Cancel()
            return false
        end
        if shouldContinue and (os.clock() - lastCheck) > 0.2 then
            lastCheck = os.clock()
            if not shouldContinue() then
                tween:Cancel()
                if conn then conn:Disconnect() end
                return false
            end
        end
        task.wait()
    end

    if not finished then
        tween:Cancel()
        if conn then conn:Disconnect() end
    end

    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
    end)

    return finished
end

local function HoldE(duration)
    duration = duration or 2.5
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(duration)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

-- ====================== แก้ไขฟังก์ชัน StepInner เพื่อแก้ปัญหาไม่ได้ไข่ ======================
local function StepInner()
    if not AutoFarm or #SelectedEggs == 0 then
        return
    end
    
    local root = GetRoot()
    if not root then
        return
    end
    
    local selectedSet = {}
    for _, r in ipairs(SelectedEggs) do
        selectedSet[r] = true
    end
    
    local available, totalModels = GetAvailableEggs()
    local target
    
    -- หากลุ่มไข่ที่มีความสำคัญสูงสุดก่อน
    for _, rarity in ipairs(SelectedEggs) do
        local best, bestDist
        for _, c in ipairs(available) do
            if c.rarity == rarity then
                local d = (root.Position - c.pos).Magnitude
                if not bestDist or d < bestDist then
                    best, bestDist = c, d
                end
            end
        end
        if best then
            target = best
            break
        end
    end
    
    if not target then
        if DEBUG and (os.clock() - lastIdleLog) >= IDLE_LOG_EVERY then
            lastIdleLog = os.clock()
            dbg(string.format(
                "standing still | RenderedEggs models: %d | available (all rarities): %d | active spawn parts (selected): %d",
                totalModels, #available, CountActiveSpawns(selectedSet)
            ))
        end
        return
    end
    
    local goal = target.pos + Vector3.new(0, 3, 0)
    
    -- ตรวจสอบอีกครั้งก่อนเริ่มเคลื่อนที่
    if not IsEggStillAvailable(target.model) then
        MarkAsCollected(target.model)
        return
    end

    local reached = TweenTo(goal, function()
        return AutoFarm and IsEggStillAvailable(target.model)
    end)
    
    if not reached then
        if AutoFarm then
            MarkAsCollected(target.model)
        end
        return
    end
    
    -- [แก้จุดที่ 1] ถึงไข่แล้วรอแค่ 1 วิตามที่ต้องการ
    task.wait(1.0) 
    
    if not IsEggStillAvailable(target.model) then
        MarkAsCollected(target.model)
        return
    end
    
    -- [แก้จุดที่ 2] กด E แบบรวดเร็ว
    local prompt = GetPrompt(target.model)
    local holdTime = ((prompt and prompt.HoldDuration) or 2) + 0.3
    
    HoldE(holdTime)
    
    -- ไม่ต้องรอนานหลังเก็บเสร็จ รีบกลับ Plot ทันที
    MarkAsCollected(target.model)
    
    local myPlot = GetMyPlot()
    if myPlot then
        local returnPos = GetPlotReturnPosition(myPlot)
        if returnPos then
            -- กลับไปที่ Plot
            local returned = TweenTo(returnPos, function() return AutoFarm end)
            
            -- [แก้จุดที่ 3] พอถึง Plot ให้ยืน Check 1.5 วินาที เพื่อให้เกมโหลดไข่ใหม่
            if returned then
                task.wait(1.5) 
            end
        end
    end
end

Step = function()
    if Busy then return end
    Busy = true
    local ok, err = pcall(StepInner)
    Busy = false
    if not ok then
        warn("[AutoFarm] error:", err)
    end
end

local function GetTreeFolder()
    local map = workspace:FindFirstChild("Map")
    local nature = map and map:FindFirstChild("Nature")
    return nature and nature:FindFirstChild("Tree")
end

local function RefreshTreeList()
    table.clear(TreeList)
    local folder = GetTreeFolder()
    if not folder then
        warn("[VisualTree] ไม่เจอ workspace.Map.Nature.Tree")
        return
    end
    for _, c in ipairs(folder:GetChildren()) do
        if c:IsA("BasePart") then
            table.insert(TreeList, c)
        elseif c:IsA("Model") and c:FindFirstChildWhichIsA("BasePart", true) then
            table.insert(TreeList, c)
        end
    end
end

local function ClearHighlights()
    for t, h in pairs(ActiveHL) do
        h:Destroy()
        ActiveHL[t] = nil
    end
end

local function UpdateHighlights()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local origin = cam.CFrame.Position

    local near = {}
    for _, t in ipairs(TreeList) do
        if t.Parent then
            local ok, p = pcall(function() return t:GetPivot().Position end)
            if ok then
                local d = (p - origin).Magnitude
                if d <= TREE_RANGE then
                    table.insert(near, { t, d })
                end
            end
        end
    end
    table.sort(near, function(a, b) return a[2] < b[2] end)

    local want = {}
    for i = 1, math.min(TREE_MAX, #near) do
        want[near[i][1]] = true
    end

    for t, h in pairs(ActiveHL) do
        if not want[t] or not t.Parent then
            h:Destroy()
            ActiveHL[t] = nil
        end
    end

    for t in pairs(want) do
        if not ActiveHL[t] then
            local h = Instance.new("Highlight")
            h.Name = "TreeESP"
            h.FillColor = Color3.fromRGB(0, 255, 120)
            h.OutlineColor = Color3.fromRGB(255, 255, 255)
            h.FillTransparency = 0.5
            h.OutlineTransparency = 0
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = t
            ActiveHL[t] = h
        end
    end
end

local function ClassifySpawn(spawnParts, pos)
    local best, bestDist, bestVol
    for _, sp in ipairs(spawnParts) do
        local d = BoxDistance(sp, pos)
        if d <= MATCH_RANGE then
            local vol = sp.Size.X * sp.Size.Y * sp.Size.Z
            if not bestDist or d < bestDist or (d == bestDist and vol < bestVol) then
                best, bestDist, bestVol = sp, d, vol
            end
        end
    end
    if not best then return nil end
    return StripDash(best.Name), not best.Name:match("%-$")
end

local function GetEggPart(model)
    local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
        return prompt.Parent
    end
    return model:FindFirstChildWhichIsA("BasePart", true)
end

local function CreateGui(part)
    local gui = Instance.new("BillboardGui")
    gui.Name = "EggESP"
    gui.Adornee = part
    gui.AlwaysOnTop = true
    gui.Size = UDim2.fromOffset(140, 32)
    gui.StudsOffset = Vector3.new(0, 4, 0)
    gui.Parent = part

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 16
    label.TextStrokeTransparency = 0
    label.Parent = gui
    return gui, label
end

local function RemoveESP(model)
    local e = ESP[model]
    if not e then return end
    if e.hl then e.hl:Destroy() end
    if e.gui then e.gui:Destroy() end
    ESP[model] = nil
end

local function ClearAll()
    for m in pairs(ESP) do
        RemoveESP(m)
    end
end

local function UpdateESP()
    local rendered = workspace:FindFirstChild("RenderedEggs")
    local spawns = workspace:FindFirstChild("EggSpawns")
    local cam = workspace.CurrentCamera
    if not rendered or not spawns or not cam then
        ClearAll()
        return
    end

    local spawnParts = {}
    for _, sp in ipairs(spawns:GetChildren()) do
        if sp:IsA("BasePart") then
            spawnParts[#spawnParts + 1] = sp
        end
    end

    local origin = cam.CFrame.Position
    local wanted, list = {}, {}

    for _, m in ipairs(rendered:GetChildren()) do
        if m:IsA("Model") then
            local part = GetEggPart(m)
            if part then
                local rarity, active = ClassifySpawn(spawnParts, part.Position)
                if rarity and active and (ShowAll or ShowSet[rarity]) then
                    wanted[m] = true
                    list[#list + 1] = {
                        m = m, part = part, rarity = rarity,
                        dist = (part.Position - origin).Magnitude,
                    }
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.dist < b.dist end)

    for m in pairs(ESP) do
        if not wanted[m] or not m.Parent then
            RemoveESP(m)
        end
    end

    for i, item in ipairs(list) do
        local e = ESP[item.m]
        if not e then
            e = {}
            ESP[item.m] = e
        end
        local color = EGG_COLORS[item.rarity] or Color3.new(1, 1, 1)

        if not e.gui or not e.gui.Parent or e.part ~= item.part then
            if e.gui then e.gui:Destroy() end
            e.gui, e.label = CreateGui(item.part)
            e.part = item.part
        end
        e.label.TextColor3 = color
        e.label.Text = string.format("%s [%.0fm]", item.rarity, item.dist)

        if i <= EGG_HL_MAX then
            if not e.hl or not e.hl.Parent then
                local h = Instance.new("Highlight")
                h.Name = "EggESP"
                h.FillTransparency = 0.6
                h.OutlineTransparency = 0
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.Parent = item.m
                e.hl = h
            end
            e.hl.FillColor = color
            e.hl.OutlineColor = color
        elseif e.hl then
            e.hl:Destroy()
            e.hl = nil
        end
    end
end

-- Notification helpers
local function GetGuiParent()
    if type(gethui) == "function" then
        local ok, r = pcall(gethui)
        if ok and r then return r end
    end
    local core = game:GetService("CoreGui")
    if pcall(function() return core:GetChildren() end) then
        return core
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function EnsureGui()
    if Gui and Gui.Parent and Holder and Holder.Parent then return end

    Gui = Instance.new("ScreenGui")
    Gui.Name = "EggNotifier"
    Gui.ResetOnSpawn = false
    Gui.DisplayOrder = 999
    Gui.IgnoreGuiInset = true
    Gui.Parent = GetGuiParent()

    Holder = Instance.new("Frame")
    Holder.BackgroundTransparency = 1
    Holder.AnchorPoint = Vector2.new(1, 1)
    Holder.Position = UDim2.new(1, -16, 1, -BOTTOM_OFFSET)
    Holder.Size = UDim2.fromOffset(280, 420)
    Holder.Parent = Gui

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = Holder
end

local COLORS_NOTIFY = {
    Common    = Color3.fromRGB(173, 173, 173),
    Rare      = Color3.fromRGB(0, 170, 255),
    Epic      = Color3.fromRGB(170, 85, 255),
    Legendary = Color3.fromRGB(255, 170, 0),
    Mythic    = Color3.fromRGB(255, 170, 255),
    Ethereal  = Color3.fromRGB(170, 170, 255),
    Divine    = Color3.fromRGB(255, 255, 0),
}

local function ShowToast(rarity, detail)
    EnsureGui()

    local cards = {}
    for _, c in ipairs(Holder:GetChildren()) do
        if c:IsA("CanvasGroup") then
            cards[#cards + 1] = c
        end
    end
    table.sort(cards, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    while #cards >= NOTIFY_MAX do
        table.remove(cards, 1):Destroy()
    end

    Order += 1
    local color = COLORS_NOTIFY[rarity] or Color3.new(1, 1, 1)

    local card = Instance.new("CanvasGroup")
    card.Size = UDim2.fromOffset(280, 58)
    card.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    card.BorderSizePixel = 0
    card.GroupTransparency = 1
    card.LayoutOrder = Order
    card.Parent = Holder

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card

    local bar = Instance.new("Frame")
    bar.BorderSizePixel = 0
    bar.BackgroundColor3 = color
    bar.Size = UDim2.new(0, 5, 1, 0)
    bar.Parent = card

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(16, 6)
    title.Size = UDim2.new(1, -24, 0, 24)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = color
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = rarity .. " Egg spawned!"
    title.Parent = card

    local sub = Instance.new("TextLabel")
    sub.BackgroundTransparency = 1
    sub.Position = UDim2.fromOffset(16, 31)
    sub.Size = UDim2.new(1, -24, 0, 20)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 13
    sub.TextColor3 = Color3.fromRGB(200, 200, 205)
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Text = detail or ""
    sub.Parent = card

    TweenService:Create(card, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()

    local dismissed = false
    local function Dismiss()
        if dismissed then return end
        dismissed = true
        TweenService:Create(card, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
        task.delay(0.35, function()
            card:Destroy()
        end)
    end

    task.delay(NOTIFY_TIME, Dismiss)
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            Dismiss()
        end
    end)
end

local function DistanceFromMe(pos)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        return (root.Position - pos).Magnitude
    end
    return nil
end

local function NotifyEgg(rarity, pos)
    local d = DistanceFromMe(pos)
    ShowToast(rarity, d and string.format("%.0f studs away", d) or "")
end

local function Scan(silent)
    local spawns = workspace:FindFirstChild("EggSpawns")
    local rendered = workspace:FindFirstChild("RenderedEggs")
    if not spawns then return end

    local spawnParts = {}
    for _, sp in ipairs(spawns:GetChildren()) do
        if sp:IsA("BasePart") then
            spawnParts[#spawnParts + 1] = sp

            local rarity = StripDash(sp.Name)
            local active = not sp.Name:match("%-$")
            local was = Known[sp]
            Known[sp] = active

            if not silent and active and was ~= true
                and rarity ~= "Common" and NotifySet[rarity] then
                NotifyEgg(rarity, sp.Position)
            end
        end
    end

    if rendered then
        for _, m in ipairs(rendered:GetChildren()) do
            if m:IsA("Model") and not SeenModels[m] then
                SeenModels[m] = true
                if not silent and NotifySet.Common then
                    local part = GetEggPart(m)
                    if part then
                        local rarity, active = ClassifySpawn(spawnParts, part.Position)
                        if rarity == "Common" and active then
                            NotifyEgg("Common", part.Position)
                        end
                    end
                end
            end
        end
    end
end

-- Player ESP Helpers
local function Opt(name)
    return OptAll or OptSet[name] == true
end

local function RemovePlayerESP(plr)
    local e = ESP[plr]
    if not e then return end
    if e.hl then e.hl:Destroy() end
    if e.gui then e.gui:Destroy() end
    ESP[plr] = nil
end

local function ClearAllPlayerESP()
    for plr in pairs(ESP) do
        RemovePlayerESP(plr)
    end
end

local function CreatePlayerGui(part)
    local gui = Instance.new("BillboardGui")
    gui.Name = "PlayerESP"
    gui.Adornee = part
    gui.AlwaysOnTop = true
    gui.Size = UDim2.fromOffset(180, 40)
    gui.StudsOffset = Vector3.new(0, 3.5, 0)
    gui.Parent = part

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextStrokeTransparency = 0
    label.Parent = gui
    return gui, label
end

local function UpdatePlayerESP()
    local cam = workspace.CurrentCamera
    if not cam then return end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local origin = myRoot and myRoot.Position or cam.CFrame.Position

    local wanted, list = {}, {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local isSel = SelectedPlayers[plr.Name] == true
            if AllOn or isSel then
                local char = plr.Character
                local part = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
                if part then
                    wanted[plr] = true
                    list[#list + 1] = {
                        plr = plr, char = char, part = part, sel = isSel,
                        dist = (part.Position - origin).Magnitude,
                    }
                end
            end
        end
    end

    table.sort(list, function(a, b)
        if a.sel ~= b.sel then return a.sel end
        return a.dist < b.dist
    end)

    for plr in pairs(ESP) do
        if not wanted[plr] then
            RemovePlayerESP(plr)
        end
    end

    for i, item in ipairs(list) do
        local e = ESP[item.plr]
        if not e then
            e = {}
            ESP[item.plr] = e
        end

        if e.char ~= item.char or e.part ~= item.part or not e.gui or not e.gui.Parent then
            if e.gui then e.gui:Destroy() end
            if e.hl then e.hl:Destroy() e.hl = nil end
            e.gui, e.label = CreatePlayerGui(item.part)
            e.char, e.part = item.char, item.part
        end

        local color = item.sel and COLOR_SELECTED or COLOR_OTHER

        local parts = {}
        if Opt("Name") then
            parts[#parts + 1] = item.plr.Name
        end
        if Opt("Health") then
            local hum = item.char:FindFirstChildOfClass("Humanoid")
            if hum then
                parts[#parts + 1] = string.format("%.0f/%.0f HP", hum.Health, hum.MaxHealth)
            end
        end
        if Opt("Distance") then
            parts[#parts + 1] = string.format("[%.0fm]", item.dist)
        end
        e.label.Text = table.concat(parts, "  ")
        e.label.TextColor3 = color

        if Opt("Highlight") and i <= PLAYER_HL_MAX then
            if not e.hl or not e.hl.Parent then
                local h = Instance.new("Highlight")
                h.Name = "PlayerESP"
                h.FillTransparency = 0.6
                h.OutlineTransparency = 0
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.Adornee = item.char
                h.Parent = item.char
                e.hl = h
            end
            e.hl.FillColor = color
            e.hl.OutlineColor = color
        elseif e.hl then
            e.hl:Destroy()
            e.hl = nil
        end
    end
end

local function RestartPlayerESP()
    RunId += 1
    local id = RunId

    if not (AllOn or next(SelectedPlayers) ~= nil) then
        ClearAllPlayerESP()
        return
    end

    task.spawn(function()
        while id == RunId do
            pcall(UpdatePlayerESP)
            task.wait(PLAYER_INTERVAL)
        end
    end)
end

Players.PlayerRemoving:Connect(function(plr)
    RemovePlayerESP(plr)
    SelectedPlayers[plr.Name] = nil
end)


-- ====================== UI & LOGIC SETUP ======================

local Automation = GerenalPage:CreateSection("Auto Farm")

Automation:AddDropdown("selected Eggs", {"Common", "Epic", "Legendary", "Mythic", "Rare", "Ethereal", "Divine"}, true, function(selected)
    SelectedEggs = ToList(selected)
    dbg("SelectedEggs =", table.concat(SelectedEggs, ", "))
end)

Automation:AddDropdown("selected to get", {"Tween"}, false, function(selected)
    SelectedMethod = ToList(selected)[1] or "Tween"
end)

Automation:AddSlider("Tween", 20, 500, 20, function(val)
    TweenSpeed = tonumber(val) or 20
end)

Automation:AddToggle("Auto Farm Eggs", false, function(state)
    AutoFarm = state
    dbg("AutoFarm =", tostring(state))
    if state then
        task.spawn(function() Step() end)
    else
        CollectedEggs = {}
    end
end)

task.spawn(function()
    while true do
        if AutoFarm then
            Step()
        end
        task.wait(0.25)
    end
end)

local AutomationUpgrades = GerenalPage:CreateSection("Auto Upgrades")

AutomationUpgrades:AddToggle("Auto Boost Lucky", false, function(state)
    getgenv().boost = state
    spawn(function ()
        pcall(function()
            while getgenv().boost do
                local Event = game:GetService("ReplicatedStorage").Remotes.Game.Plot.Upgrades
                Event:FireServer()
                task.wait(0.5)
            end
        end)
    end)
end)

AutomationUpgrades:AddButton("Upgrade Boost Max", function()
    local s = game:GetService("Players").LocalPlayer.PlayerScripts.Game.Plot.Upgrades
    s:FireServer("Max")
end)

local AutomationBasical = GerenalPage:CreateSection("Basical")

AutomationBasical:AddButton("Rebirth", function()
    local s = game:GetService("ReplicatedStorage").Remotes.Game.Rebirth
    s:FireServer()
end)

local Notifications = GerenalPage:CreateSection("Notifications")

Notifications:AddDropdown("notify Eggs", {"Common", "Epic", "Legendary", "Mythic", "Rare", "Ethereal", "Divine"}, true, function(selected)
    NotifySet = {}
    for _, r in ipairs(ToList(selected)) do
        NotifySet[r] = true
    end
end)

Notifications:AddToggle("Notification egg spawn", false, function(state)
    NotifyOn = state
    RunId += 1
    local id = RunId
    if not state then return end

    task.spawn(function()
        table.clear(Known)
        table.clear(SeenModels)
        pcall(Scan, true) 
        while NotifyOn and id == RunId do
            task.wait(POLL)
            pcall(Scan, false)
        end
    end)
end)

Notifications:AddButton("Test notification", function()
    ShowToast("Legendary", "Example notification (click to close)")
end)

local BuyTab = Window:CreateTab("Buying")
local buyPage = BuyTab:CreatePage("Maintion")
local buygears = buyPage:CreateSection("Gears")

buygears:AddDropdown("selected Gears", {"Advanced Radar", "Jewel Radar", "Royal Radar", "Magic Radar", "Angellc Radar", "Eternal Radar"}, true, function(selected)
    SelectedGears = ToList(selected)
end)

buygears:AddButton("Buy", function()
    local remote = game:GetService("ReplicatedStorage").Remotes.Game.BuyWithCash
    for _, gear in ipairs(SelectedGears) do
        remote:FireServer("Gears", gear)
        task.wait(0.5)
    end
end)

local buyfood = buyPage:CreateSection("Food")

buyfood:AddDropdown("selected food", {"Grass", "Bone", "Meat", "Magic Apple", "Dragonfruits"}, true, function(selected)
    SelectedFood = ToList(selected)
end)

buyfood:AddButton("Buy", function()
    local remote = game:GetService("ReplicatedStorage").Remotes.Game.BuyWithCash
    for _, food in ipairs(SelectedFood) do
        remote:FireServer(FOOD_CATEGORY, food)
        task.wait(0.5)
    end
end)

local VisualTab = Window:CreateTab("Visuals")
local VisualPage = VisualTab:CreatePage("Main")
local VisualMap = VisualPage:CreateSection("Visual Map")

VisualMap:AddToggle("Visual Tree", false, function(state)
    getgenv().tree = state
    TreeRunId += 1
    local runId = TreeRunId

    if not state then
        ClearHighlights()
        return
    end

    task.spawn(function()
        RefreshTreeList()
        local lastRefresh = os.clock()
        while getgenv().tree and runId == TreeRunId do
            if os.clock() - lastRefresh > 5 then
                RefreshTreeList()
                lastRefresh = os.clock()
            end
            pcall(UpdateHighlights)
            task.wait(TREE_INTERVAL)
        end
    end)
end)

VisualMap:AddDropdown("selected Egg ESP", RARITY_ORDER, true, function(selected)
    local list = ToList(selected)
    ShowSet = {}
    for _, r in ipairs(list) do
        ShowSet[r] = true
    end
    ShowAll = (#list == 0)
end)

VisualMap:AddToggle("Visual Egg", false, function(state)
    getgenv().eggesp = state
    RunId += 1
    local id = RunId

    if not state then
        ClearAll()
        return
    end

    task.spawn(function()
        while getgenv().eggesp and id == RunId do
            pcall(UpdateESP)
            task.wait(EGG_INTERVAL)
        end
    end)
end)

local VisualPlayers = VisualPage:CreateSection("Visual Players")

local names = {}
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        table.insert(names, plr.Name)
    end
end
if #names == 0 then
    names = {"(no other players)"}
end

VisualPlayers:AddToggle("Visual All Players", false, function(state)
    AllOn = state
    RestartPlayerESP()
end)

VisualPlayers:AddDropdown("selected Players", names, true, function(selected)
    SelectedPlayers = {}
    for _, n in ipairs(ToList(selected)) do
        SelectedPlayers[n] = true
    end
    RestartPlayerESP()
end)

VisualPlayers:AddDropdown("Show", {"Highlight", "Name", "Distance", "Health"}, true, function(selected)
    local list = ToList(selected)
    OptSet = {}
    for _, o in ipairs(list) do
        OptSet[o] = true
    end
    OptAll = (#list == 0)
end)

-- แก้ไข: ลบช่องว่างในชื่อ Tab และ Page เพื่อป้องกัน Error
local SettingsTab = Window:CreateTab("set Ui", false, false)
local SettingsPage = SettingsTab:CreatePage("Settings")

local UI = SettingsPage:CreateSection("UI")
UI:AddToggle("Transparency", false, function(state)
    Window:SetTransparency(state and 0.2 or 0)
end)

local Config = SettingsPage:CreateSection("Config")
Config:AddConfigManager("zyronxSavers")


-- ====================== Fixed Toggle UI Button (ZyronX Safe Edition) ======================
task.spawn(function()
    pcall(function()
        local coreGui = game:GetService("CoreGui")
        local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        local UserInputService = game:GetService("UserInputService")
        local TweenService = game:GetService("TweenService")
        
        -- สร้าง ScreenGui สำหรับปุ่มเปิด-ปิด
        local toggleGui = Instance.new("ScreenGui")
        toggleGui.Name = "XZilerHub_FixedToggleButton"
        toggleGui.ResetOnSpawn = false
        toggleGui.DisplayOrder = 10000 -- อยู่ชั้นบนสุดเสมอ
        
        local success = pcall(function()
            if type(gethui) == "function" then
                toggleGui.Parent = gethui()
            else
                toggleGui.Parent = coreGui
            end
        end)
        if not success then
            toggleGui.Parent = playerGui
        end

        -- สร้างปุ่ม ImageButton
        local toggleBtn = Instance.new("ImageButton")
        toggleBtn.Name = "ToggleImageButton"
        toggleBtn.Size = UDim2.fromOffset(45, 45)
        toggleBtn.Position = UDim2.new(0, 20, 0.5, -22)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        toggleBtn.Image = "rbxassetid://123904148959662" -- (คง ID เดิมของคุณไว้)
        toggleBtn.AutoButtonColor = true
        toggleBtn.Parent = toggleGui

        -- ทำมุมโค้ง
        local uiCorner = Instance.new("UICorner")
        uiCorner.CornerRadius = UDim.new(0, 10)
        uiCorner.Parent = toggleBtn

        -- ทำขอบเรืองแสงสีม่วง
        local uiStroke = Instance.new("UIStroke")
        uiStroke.Color = Color3.fromRGB(190, 140, 255)
        uiStroke.Thickness = 1.5
        uiStroke.Parent = toggleBtn

        -- 🛠️ ระบบลากขยับแบบเสถียร (แก้ไข Memory Leak แล้ว)
        local dragging = false
        local dragStart, startPos
        local moved = false

        toggleBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                moved = false
                dragStart = input.Position
                startPos = toggleBtn.Position
            end
        end)

        toggleBtn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                if delta.Magnitude > 5 then
                    moved = true -- ขยับเกิน 5 พิกเซล = นับเป็นการลาก ไม่ใช่การคลิก
                end
                toggleBtn.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end)

        -- 🛠️ ฟังก์ชันเปิด-ปิด UI อย่างปลอดภัย (ไม่ปิด UI เกมจนโดนดีด)
        local isOpen = true
        
        local function toggleZyronXUI(state)
            -- 1. ลองหาชื่อที่แน่นอนที่คุณแจ้งมาก่อน
            local exactName = "ZyronX_UI_C2EDDF87-CA18-4A53-9B5F-8B9844E142F5"
            local targetGui = coreGui:FindFirstChild(exactName) or playerGui:FindFirstChild(exactName)
            
            if targetGui and targetGui:IsA("ScreenGui") then
                targetGui.Enabled = state
            end

            -- 2. ระบบสำรอง: หากชื่อเปลี่ยน (มีตัวเลขสุ่มใหม่) ให้หาทุกอันที่ขึ้นต้นด้วย "ZyronX" หรือ "XZiler"
            for _, gui in ipairs(coreGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui ~= toggleGui and (string.find(gui.Name, "ZyronX") or string.find(gui.Name, "XZiler")) then
                    gui.Enabled = state
                end
            end
            for _, gui in ipairs(playerGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui ~= toggleGui and (string.find(gui.Name, "ZyronX") or string.find(gui.Name, "XZiler")) then
                    gui.Enabled = state
                end
            end
        end

        toggleBtn.MouseButton1Click:Connect(function()
            -- ถ้ากำลังลากปุ่มอยู่ จะไม่ให้ทำงานเปิด-ปิด
            if moved then return end
            
            isOpen = not isOpen
            
            -- ใช้ pcall ครอบไว้กัน Error
            pcall(function()
                toggleZyronXUI(isOpen)
            end)
            
            -- Animation เล็กน้อยตอนกด
            TweenService:Create(toggleBtn, TweenInfo.new(0.1), {
                Size = isOpen and UDim2.fromOffset(45, 45) or UDim2.fromOffset(38, 38)
            }):Play()
            
            task.delay(0.1, function()
                TweenService:Create(toggleBtn, TweenInfo.new(0.1), {
                    Size = UDim2.fromOffset(45, 45)
                }):Play()
            end)
        end)
    end)
end)
