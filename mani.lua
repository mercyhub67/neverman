--// CONFIG
local SilentAimEnabled = true
local FOV = 150

--// Intro Animation
local TweenService = game:GetService("TweenService")

local intro = Instance.new("ScreenGui")
intro.Parent = game.CoreGui
intro.Name = "JerryHubIntro"
intro.ResetOnSpawn = false

local logo = Instance.new("ImageLabel")
logo.Parent = intro
logo.Size = UDim2.fromOffset(110,110)
logo.AnchorPoint = Vector2.new(0.5,0.5)
logo.Position = UDim2.new(0.5,-140,0.5,0)
logo.BackgroundTransparency = 1
logo.Image = "rbxassetid://79955709475525"
logo.ImageTransparency = 1

local text = Instance.new("TextLabel")
text.Parent = intro
text.Size = UDim2.fromOffset(320,60)
text.AnchorPoint = Vector2.new(0.5,0.5)
text.Position = UDim2.new(0.5,60,0.5,0)
text.BackgroundTransparency = 1
text.Text = "Welcome To\nJerry Hub"
text.TextColor3 = Color3.fromRGB(255,255,255)
text.TextScaled = true
text.Font = Enum.Font.GothamBold
text.TextTransparency = 1

TweenService:Create(
	logo,
	TweenInfo.new(1.2,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
	{
		ImageTransparency = 0,
		Position = UDim2.new(0.5,-80,0.5,0)
	}
):Play()

TweenService:Create(
	text,
	TweenInfo.new(1),
	{TextTransparency = 0}
):Play()

task.wait(2.5)
intro:Destroy()

--// WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
Title = "Neverman x'Dev",
Author = "Kiwwy",
Icon = "rbxassetid://79955709475525",
Theme = "Dark",
Size = UDim2.fromOffset(350,450),
Acrylic = true,
HideSearchBar = true,

OpenButton = {
	Enabled = false
}
})

Window:Tag({
Title = "v1.6.6",
Icon = "github",
Color = Color3.fromHex("#30ff6a"),
Radius = 0,
})

Window:SetBackgroundTransparency(0.25)
Window:SetBackgroundImageTransparency(0.25)

--// Toggle Button
local gui = Instance.new("ScreenGui")
gui.Parent = game.CoreGui
gui.Name = "NM_Toggle"
gui.ResetOnSpawn = false

local btn = Instance.new("ImageButton")
btn.Parent = gui
btn.Size = UDim2.fromOffset(42,42)
btn.Position = UDim2.fromOffset(40,220)

btn.BackgroundTransparency = 1
btn.Image = "rbxassetid://79955709475525"
btn.ScaleType = Enum.ScaleType.Fit

btn.Active = true
btn.Draggable = true
btn.AnchorPoint = Vector2.new(0.5,0.5)

btn.MouseButton1Click:Connect(function()
	local down = TweenService:Create(btn,TweenInfo.new(0.07),{Size = UDim2.fromOffset(36,36)})
	local up = TweenService:Create(btn,TweenInfo.new(0.07),{Size = UDim2.fromOffset(42,42)})
	down:Play()
	down.Completed:Wait()
	up:Play()
	Window:Toggle()
end)

--// SERVICES & GLOBALS
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local PREDICTION_FACTOR = 0.165

--// SPEED WARP SETTINGS
local SpeedWarpEnabled = false
local warpDistance = 0.4
local warpCooldown = 0.05
local lastWarp = 0

local GunNames = {
"P226","MP5","M24","Draco","Glock","Sawnoff","Uzi","G3","C9",
"Hunting Rifle","Anaconda","AK47","Remington","Double Barrel"
}

local GunLookup = {}
for _,v in pairs(GunNames) do GunLookup[v] = true end

local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(255,255,255)
fovCircle.Thickness = 1
fovCircle.NumSides = 100
fovCircle.Radius = FOV
fovCircle.Filled = false
fovCircle.Visible = true

local tracerLine = Drawing.new("Line")
tracerLine.Color = Color3.fromRGB(255,0,0)
tracerLine.Thickness = 1
tracerLine.Visible = false

--// TABS
local CombatTab = Window:Tab({Title = "Combat", Icon = "crosshair"})
local VisualsTab = Window:Tab({Title = "Visuals", Icon = "eye"})
local PlayerTab = Window:Tab({Title = "Player", Icon = "user"})

--// COMBAT TAB
local Section = CombatTab:Section({Title = "Silent Aim (Advanced)"})

CombatTab:Toggle({
Title = "Enable Silent Aim",
Default = SilentAimEnabled,
Callback = function(v)
	SilentAimEnabled = v
	fovCircle.Visible = v
end
})

CombatTab:Slider({
Title = "FOV",
Step = 1,
Value = {Min = 50, Max = 800, Default = FOV},
Callback = function(v)
	FOV = v
	if fovCircle then fovCircle.Radius = v end
end
})

local function GetClosestTarget()
    local closest
    local shortest = math.huge
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _,player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local head = player.Character.Head
            local pos,onScreen = Camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local dist = (Vector2.new(pos.X,pos.Y) - center).Magnitude
                if dist < FOV and dist < shortest then
                    shortest = dist
                    closest = player
                end
            end
        end
    end
    return closest
end

--// NEW: รองรับการทำนายตำแหน่งรถและการเคลื่อนที่
local function PredictPosition(targetPart)
    local char = targetPart.Parent
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return targetPart.Position end

    local velocity = root.AssemblyLinearVelocity
    
    -- เช็คว่านั่งในรถหรือไม่ (ถ้ามี SeatWeld แสดงว่านั่งอยู่)
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.SeatPart then
        -- ถ้าอยู่บนรถ ใช้ความเร็วของรถทั้งหมดในการทำนาย
        velocity = humanoid.SeatPart.AssemblyLinearVelocity
        return targetPart.Position + (velocity * PREDICTION_FACTOR * 1.05)
    end

    -- กรองความเร็วที่ผิดปกติ (เช่น วาร์ป หรือตกแมพ)
    if velocity.Magnitude > 150 then return targetPart.Position end

    return targetPart.Position + (velocity * PREDICTION_FACTOR)
end

local function IsHoldingAllowedGun(args)
    local ok,weapon = pcall(function() return args[3] end)
    if ok and typeof(weapon) == "Instance" and GunLookup[weapon.Name] then return true end
    if LocalPlayer.Character then
        for _,v in pairs(LocalPlayer.Character:GetChildren()) do if v:IsA("Tool") and GunLookup[v.Name] then return true end end
    end
    return false
end

local send = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Send")
local oldFire
oldFire = hookfunction(send.FireServer,function(self,...)
    local args = {...}
    if SilentAimEnabled and IsHoldingAllowedGun(args) then
        local target = GetClosestTarget()
        if target and target.Character and target.Character:FindFirstChild("Head") then
            local head = target.Character.Head
            local aimPos = PredictPosition(head)
            args[4] = CFrame.new(1/0,1/0,1/0)
            args[5] = {[1] = {[1] = {["Instance"] = head, ["Position"] = aimPos}}}
        end
    end
    return oldFire(self,unpack(args))
end)

--// ITEM ESP LOGIC
local ContentProvider = game:GetService("ContentProvider")
local ItemESP_Enabled = true
local BillboardCache = {}
local ItemESP_UpdateConnections = {}
local WeaponDB = {}
local PreloadedImages = {}

local RARITY_COLORS = {
    ["Common"] = Color3.fromRGB(255,255,255),
    ["Uncommon"] = Color3.fromRGB(99,255,52),
    ["Rare"] = Color3.fromRGB(51,170,255),
    ["Epic"] = Color3.fromRGB(237,44,255),
    ["Legendary"] = Color3.fromRGB(255,150,0),
    ["Omega"] = Color3.fromRGB(255,20,51),
}

local VisualSection = VisualsTab:Section({Title = "Item ESP"})

VisualsTab:Toggle({
Title = "Enable Item ESP",
Default = ItemESP_Enabled,
Callback = function(v)
	ItemESP_Enabled = v
	for _, billboard in pairs(BillboardCache) do billboard.Enabled = v end
end
})

local function generateUniqueKey(tool)
    if not tool or not tool:IsA("Tool") then return nil end
    local itemId = tool:GetAttribute("ItemId") or tool:GetAttribute("Id")
    if itemId then return "ITEMID_"..tostring(itemId) end
    local partsData = {}
    for _,part in ipairs(tool:GetDescendants()) do
        if part:IsA("SpecialMesh") and part.MeshId ~= "" then table.insert(partsData,"MESH_"..part.MeshId.."|TEX_"..(part.TextureId or ""))
        elseif part:IsA("MeshPart") and part.MeshId ~= "" then table.insert(partsData,"MESH_"..part.MeshId.."|TEX_"..(part.TextureID or ""))
        elseif part:IsA("Decal") then table.insert(partsData,"DECAL_"..part.Texture)
        elseif part:IsA("Part") then table.insert(partsData,"PART_"..part.Name) end
    end
    if #partsData > 0 then table.sort(partsData) return "MESHKEY_"..table.concat(partsData,";") end
    local displayName = tool:GetAttribute("DisplayName") or tool.Name
    local rarity = tool:GetAttribute("RarityName") or tool:GetAttribute("Rarity") or "Common"
    local imageId = tool:GetAttribute("ImageId") or "NOIMAGE"
    return "NAME_"..displayName.."_"..rarity.."_"..imageId
end

local function registerItems(folder)
    for _,tool in ipairs(folder:GetDescendants()) do
        if not tool:IsA("Tool") then continue end
        local key = generateUniqueKey(tool)
        if not key then continue end
        local displayName = tool:GetAttribute("DisplayName") or tool.Name
        local imageId = tool:GetAttribute("ImageId") or "rbxassetid://7072725737"
        local rarity = tool:GetAttribute("RarityName") or tool:GetAttribute("Rarity") or "Common"
        WeaponDB[key] = {Name = displayName, Rarity = rarity, ImageId = imageId, Key = key}
        if imageId and not PreloadedImages[imageId] then
            PreloadedImages[imageId] = true
            task.spawn(function() pcall(function() ContentProvider:PreloadAsync({imageId}) end) end)
        end
    end
end

pcall(function()
    local itemsFolder = ReplicatedStorage:WaitForChild("Items",5)
    if itemsFolder then registerItems(itemsFolder) end
    for _,obj in ipairs(ReplicatedStorage:GetChildren()) do if obj:IsA("Folder") then registerItems(obj) end end
end)

local function getWeaponInfo(tool)
    local key = generateUniqueKey(tool)
    return WeaponDB[key]
end

local function createBillboardForPlayer(player)
    if player == LocalPlayer or BillboardCache[player] then return end
    local billboard, container, connections = nil, nil, {}
    local lastHash = ""

    local function updateESP()
        if not billboard then return end
        local currentTools = {}
        local function scan(folder)
            if not folder then return end
            for _,tool in ipairs(folder:GetChildren()) do
                if tool:IsA("Tool") and tool.Name ~= "Fists" then
                    local info = getWeaponInfo(tool)
                    if info then table.insert(currentTools,info) end
                end
            end
        end
        if player.Character then scan(player.Character) end
        if player:FindFirstChild("Backpack") then scan(player.Backpack) end
        container:ClearAllChildren()
        local layout = Instance.new("UIGridLayout")
        layout.CellSize = UDim2.new(0,16,0,16)
        layout.CellPadding = UDim2.new(0,4,0,0)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.Parent = container
        for i,info in ipairs(currentTools) do
            local img = Instance.new("ImageLabel")
            img.Parent = container
            img.Size = UDim2.new(0,16,0,16)
            img.BackgroundTransparency = 1
            img.Image = info.ImageId
            img.LayoutOrder = i
            img.ImageColor3 = RARITY_COLORS[info.Rarity] or Color3.new(1,1,1)
        end
    end

    local function setup()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local hrp = char.HumanoidRootPart
        billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0,200,0,20)
        billboard.StudsOffset = Vector3.new(0,-6.5,0)
        billboard.AlwaysOnTop = true
        billboard.Enabled = ItemESP_Enabled
        billboard.Adornee = hrp
        billboard.Parent = hrp
        container = Instance.new("Frame")
        container.Size = UDim2.new(1,0,1,0)
        container.BackgroundTransparency = 1
        container.Parent = billboard
        BillboardCache[player] = billboard
        table.insert(connections, RunService.RenderStepped:Connect(function()
            if not player.Character then return end
            local currentKeys = {}
            local function scan2(folder)
                if not folder then return end
                for _,tool in ipairs(folder:GetChildren()) do
                    if tool:IsA("Tool") then
                        local info = getWeaponInfo(tool)
                        if info then table.insert(currentKeys,info.Key) end
                    end
                end
            end
            scan2(player.Character)
            if player:FindFirstChild("Backpack") then scan2(player.Backpack) end
            table.sort(currentKeys)
            local newHash = table.concat(currentKeys,"|")
            if newHash ~= lastHash then lastHash = newHash; updateESP() end
        end))
        updateESP()
    end
    if player.Character then task.spawn(setup) end
    table.insert(connections, player.CharacterAdded:Connect(function() task.wait(1); setup() end))
    ItemESP_UpdateConnections[player] = connections
end

--// PLAYER ESP CONFIG
local ESP_Config = {Master = true, ShowName = true, ShowHealth = true, ShowDistance = true}
local ESP = {}

VisualsTab:Toggle({
    Title = "Enable ESP",
    Default = ESP_Config.Master,
    Callback = function(v)
        ESP_Config.Master = v
        for _, data in pairs(ESP) do
            if data.NameGui then data.NameGui.Enabled = v end
            if data.InfoGui then data.InfoGui.Enabled = v end
        end
    end
})

VisualsTab:Toggle({Title = "Show Names", Default = ESP_Config.ShowName, Callback = function(v) ESP_Config.ShowName = v end})
VisualsTab:Toggle({Title = "Show Health", Default = ESP_Config.ShowHealth, Callback = function(v) ESP_Config.ShowHealth = v end})
VisualsTab:Toggle({Title = "Show Distance", Default = ESP_Config.ShowDistance, Callback = function(v) ESP_Config.ShowDistance = v end})

local function CreateESP(player)
	if player == LocalPlayer then return end
	local NameGui = Instance.new("BillboardGui")
	NameGui.Size = UDim2.new(0,120,0,30)
	NameGui.StudsOffset = Vector3.new(0,2.5,0)
	NameGui.AlwaysOnTop = true
    NameGui.Enabled = ESP_Config.Master
	local NameText = Instance.new("TextLabel")
	NameText.Size = UDim2.new(1,0,1,0)
	NameText.BackgroundTransparency = 1
	NameText.TextColor3 = Color3.new(1,1,1)
	NameText.TextStrokeTransparency = 0
	NameText.TextSize = 10
	NameText.Font = Enum.Font.SourceSansBold
	NameText.Parent = NameGui
	local InfoGui = Instance.new("BillboardGui")
	InfoGui.Size = UDim2.new(0,120,0,20)
	InfoGui.StudsOffset = Vector3.new(0,-3.5,0)
	InfoGui.AlwaysOnTop = true
    InfoGui.Enabled = ESP_Config.Master
	local InfoText = Instance.new("TextLabel")
	InfoText.Size = UDim2.new(1,0,1,0)
	InfoText.BackgroundTransparency = 1
	InfoText.TextColor3 = Color3.new(1,1,1)
	InfoText.TextStrokeTransparency = 0
	InfoText.TextSize = 10
	InfoText.Font = Enum.Font.SourceSansBold
	InfoText.Parent = InfoGui
	ESP[player] = {NameGui = NameGui, NameText = NameText, InfoGui = InfoGui, InfoText = InfoText}
end

for _,p in pairs(Players:GetPlayers()) do CreateESP(p); createBillboardForPlayer(p) end
Players.PlayerAdded:Connect(function(p) CreateESP(p); createBillboardForPlayer(p) end)
Players.PlayerRemoving:Connect(function(p)
	if ESP[p] then if ESP[p].NameGui then ESP[p].NameGui:Destroy() end; if ESP[p].InfoGui then ESP[p].InfoGui:Destroy() end; ESP[p] = nil end
    if BillboardCache[p] then BillboardCache[p]:Destroy(); BillboardCache[p] = nil end
    if ItemESP_UpdateConnections[p] then for _,c in pairs(ItemESP_UpdateConnections[p]) do c:Disconnect() end; ItemESP_UpdateConnections[p] = nil end
end)

--// PLAYER TAB (MOVEMENT)
local PlayerSection = PlayerTab:Section({Title = "Character Settings"})

PlayerTab:Toggle({
    Title = "Speed Warp (วาร์ปวิ่ง)",
    Default = SpeedWarpEnabled,
    Callback = function(v) SpeedWarpEnabled = v end
})

PlayerTab:Slider({
    Title = "Warp Distance",
    Step = 0.1,
    Value = {Min = 0.1, Max = 2.0, Default = 0.4},
    Callback = function(v) warpDistance = v end
})

PlayerTab:Slider({
    Title = "Jump Power",
    Step = 1,
    Value = {Min = 50, Max = 300, Default = 50},
    Callback = function(v)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            hum.UseJumpPower = true; hum.JumpPower = v
        end
    end
})

--// FINAL UPDATE LOOP
RunService.RenderStepped:Connect(function()
	local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
	fovCircle.Position = center; fovCircle.Radius = FOV
	if SilentAimEnabled then
		local target = GetClosestTarget()
		if target and target.Character and target.Character:FindFirstChild("Head") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
			local pred = PredictPosition(target.Character.Head)
			local pos,onScreen = Camera:WorldToViewportPoint(pred)
			local ourPos,ourOnScreen = Camera:WorldToViewportPoint(LocalPlayer.Character.Head.Position)
			if onScreen and ourOnScreen then tracerLine.From = Vector2.new(ourPos.X, ourPos.Y); tracerLine.To = Vector2.new(pos.X,pos.Y); tracerLine.Visible = true else tracerLine.Visible = false end
		else tracerLine.Visible = false end
	else tracerLine.Visible = false end

	local myChar = LocalPlayer.Character
	if myChar and myChar:FindFirstChild("HumanoidRootPart") then
		local myRoot = myChar.HumanoidRootPart
		for player,data in pairs(ESP) do
			local char = player.Character
			if char and ESP_Config.Master then
				local head = char:FindFirstChild("Head")
				local root = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChildOfClass("Humanoid")
				if head and root and hum then
					local dist = (myRoot.Position - root.Position).Magnitude
					data.NameGui.Enabled = true; data.InfoGui.Enabled = true
					if dist <= 100 then
						data.NameGui.Parent = head; data.InfoGui.Parent = root
						data.NameText.Text = ESP_Config.ShowName and player.Name or ""
						data.InfoText.Text = (ESP_Config.ShowHealth and "["..math.floor(hum.Health).." HP] " or "").. (ESP_Config.ShowDistance and "["..math.floor(dist).."M]" or "")
					else
						data.NameGui.Parent = head; data.InfoGui.Parent = nil
						data.NameText.Text = (ESP_Config.ShowName and player.Name or "").. "\n\n".. (ESP_Config.ShowHealth and "["..math.floor(hum.Health).." HP] " or "").. (ESP_Config.ShowDistance and "["..math.floor(dist).."M]" or "")
					end
				end
			else if data.NameGui then data.NameGui.Enabled = false end; if data.InfoGui then data.InfoGui.Enabled = false end end
		end
	end
end)

--// SPEED WARP HEARTBEAT
RunService.Heartbeat:Connect(function()
    if SpeedWarpEnabled then
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            if hrp and hum and tick() - lastWarp >= warpCooldown then
                if hum.MoveDirection.Magnitude > 0 then
                    hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * warpDistance
                    lastWarp = tick()
                end
            end
        end
    end
end)
