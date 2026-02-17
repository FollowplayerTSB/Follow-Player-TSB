-- StarterPlayerScripts/FollowPlayer_LocalOnly.client.lua
-- Follow Player UI (Local): Select target + Follow + Noclip + Discord Copy + Run(ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- ========================= CONFIG =========================
local TITLE = "Follow Player"
local DISCORD_INVITE = "discord.gg/t9xfTRjCwm"

-- Follow positioning
local EXTRA_GAP_UNDERFEET = 2.5
local BEHIND_OFFSET_Z = 2.3
local FLAT_ANGLE_DEG = 50

-- UI
local UI_TWEEN_MED = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ========================= STATE =========================
local selectedPlayer: Player? = nil
local following = false
local hbConn: RBXScriptConnection? = nil
local noclipOn = false

-- Cache for performance
local cachedMyChar: Model? = nil
local cachedMyHRP: BasePart? = nil
local cachedTargetChar: Model? = nil
local cachedTargetHRP: BasePart? = nil
local cachedTargetHum: Humanoid? = nil

-- External action module (optional)
local ExtraAction: any = nil
local function loadExtraAction()
	ExtraAction = nil
	local ok, mod = pcall(function()
		local m = ReplicatedStorage:FindFirstChild("DiscordExtraAction")
		if not m then return nil end
		return require(m)
	end)
	if ok then
		ExtraAction = mod
	else
		warn("[FollowPlayer] DiscordExtraAction require failed:", mod)
	end
end
loadExtraAction()

-- ========================= UTILS =========================
local function tween(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

local function notify(text: string)
	pcall(function()
		GuiService:SendNotification({ Title = TITLE, Text = text, Duration = 2.5 })
	end)
end

local function tryCopyToClipboard(text: string): boolean
	if setclipboard then
		setclipboard(text)
		return true
	end
	return false
end

local function getHumanoid(char: Model?): Humanoid?
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

local function setFlat(isFlat: boolean)
	local char = LocalPlayer.Character
	if not char then return end
	local hum = getHumanoid(char)
	if not hum then return end

	if isFlat then
		hum.AutoRotate = false
		hum.PlatformStand = true
	else
		hum.PlatformStand = false
		hum.AutoRotate = true
	end
end

local function clearTargetCache()
	cachedTargetChar = nil
	cachedTargetHRP = nil
	cachedTargetHum = nil
end

local function clearMyCache()
	cachedMyChar = nil
	cachedMyHRP = nil
end

local function refreshCaches()
	-- My cache
	local myChar = LocalPlayer.Character
	if myChar ~= cachedMyChar then
		cachedMyChar = myChar
		cachedMyHRP = nil
	end
	if cachedMyChar and not cachedMyHRP then
		cachedMyHRP = cachedMyChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	end

	-- Target cache
	local tPlr = selectedPlayer
	local tChar = tPlr and tPlr.Character or nil
	if tChar ~= cachedTargetChar then
		cachedTargetChar = tChar
		cachedTargetHRP = nil
		cachedTargetHum = nil
	end
	if cachedTargetChar then
		if not cachedTargetHRP then
			cachedTargetHRP = cachedTargetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		end
		if not cachedTargetHum then
			cachedTargetHum = getHumanoid(cachedTargetChar)
		end
	end
end

-- ========================= FOLLOW =========================
local function stopFollow()
	following = false
	if hbConn then hbConn:Disconnect(); hbConn = nil end
	setFlat(false)
end

local function startFollow()
	if not selectedPlayer then return end
	following = true

	if hbConn then hbConn:Disconnect() end
	hbConn = RunService.Heartbeat:Connect(function()
		if not following then return end
		if not selectedPlayer or not selectedPlayer.Parent then
			stopFollow()
			return
		end

		refreshCaches()

		local myHRP = cachedMyHRP
		local tHRP = cachedTargetHRP
		if not myHRP or not tHRP then return end

		-- Keep flat
		setFlat(true)

		-- Rotation: keep target's yaw (remove position component)
		local targetRot = (tHRP.CFrame - tHRP.Position)
		local flatRot = CFrame.Angles(math.rad(FLAT_ANGLE_DEG), 0, 0)

		local tHum = cachedTargetHum
		local hip = (tHum and tHum.HipHeight) or 2

		local down =
			(tHRP.Size.Y / 2)
			+ hip
			+ (myHRP.Size.Y / 2)
			+ EXTRA_GAP_UNDERFEET

		local pos = (tHRP.CFrame * CFrame.new(0, -down, BEHIND_OFFSET_Z)).Position
		myHRP.CFrame = CFrame.new(pos) * targetRot * flatRot
	end)
end

-- ========================= NOCLIP =========================
local function applyNoclip(on: boolean)
	local char = LocalPlayer.Character
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = not on
		end
	end
end

RunService.Stepped:Connect(function()
	if noclipOn then
		applyNoclip(true)
	end
end)

-- ========================= UI BUILD =========================
local gui = Instance.new("ScreenGui")
gui.Name = "FollowPlayerUI_LocalOnly"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(500, 520)
main.Position = UDim2.new(0, 25, 0, 25)
main.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)

local shadow = Instance.new("ImageLabel")
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://1316045217"
shadow.ImageTransparency = 0.6
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(10, 10, 118, 118)
shadow.Size = UDim2.new(1, 42, 1, 42)
shadow.Position = UDim2.new(0, -21, 0, -21)
shadow.ZIndex = 0
shadow.Parent = main
main.ZIndex = 1

local grad = Instance.new("UIGradient")
grad.Rotation = 90
grad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(24,24,28)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12,12,14)),
})
grad.Parent = main

-- TopBar
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 64)
topBar.BackgroundTransparency = 1
topBar.Parent = main

local header = Instance.new("TextLabel")
header.BackgroundTransparency = 1
header.Position = UDim2.new(0, 18, 0, 12)
header.Size = UDim2.new(1, -120, 0, 26)
header.Font = Enum.Font.GothamBlack
header.TextSize = 24
header.TextXAlignment = Enum.TextXAlignment.Left
header.TextColor3 = Color3.fromRGB(255,255,255)
header.Text = TITLE
header.Parent = topBar

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Position = UDim2.new(0, 18, 0, 38)
sub.Size = UDim2.new(1, -120, 0, 18)
sub.Font = Enum.Font.Gotham
sub.TextSize = 12
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.TextColor3 = Color3.fromRGB(170,170,175)
sub.Text = "Select player • Follow • Noclip • Discord"
sub.Parent = topBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(36, 36)
minBtn.Position = UDim2.new(1, -52, 0, 14)
minBtn.Text = "—"
minBtn.Font = Enum.Font.GothamBlack
minBtn.TextSize = 22
minBtn.TextColor3 = Color3.fromRGB(255,255,255)
minBtn.BackgroundColor3 = Color3.fromRGB(32,32,38)
minBtn.AutoButtonColor = false
minBtn.Parent = topBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 10)

-- Search
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -36, 0, 38)
searchBox.Position = UDim2.new(0, 18, 0, 74)
searchBox.PlaceholderText = "Search player..."
searchBox.Text = ""
searchBox.ClearTextOnFocus = false
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 16
searchBox.TextColor3 = Color3.fromRGB(240,240,240)
searchBox.PlaceholderColor3 = Color3.fromRGB(140,140,150)
searchBox.BackgroundColor3 = Color3.fromRGB(24,24,30)
searchBox.BorderSizePixel = 0
searchBox.Parent = main
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 12)

-- Bottom
local bottom = Instance.new("Frame")
bottom.BackgroundTransparency = 1
bottom.AnchorPoint = Vector2.new(0, 1)
bottom.Position = UDim2.new(0, 18, 1, -18)
bottom.Size = UDim2.new(1, -36, 0, 136)
bottom.Parent = main

local bottomLayout = Instance.new("UIListLayout")
bottomLayout.SortOrder = Enum.SortOrder.LayoutOrder
bottomLayout.Padding = UDim.new(0, 10)
bottomLayout.Parent = bottom

local bottomPad = Instance.new("UIPadding")
bottomPad.PaddingTop = UDim.new(0, 6)
bottomPad.PaddingBottom = UDim.new(0, 6)
bottomPad.Parent = bottom

local function mkBtn(text, order, color)
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.Size = UDim2.new(1, 0, 0, 44)
	b.AutoButtonColor = false
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.TextColor3 = Color3.fromRGB(255,255,255)
	b.Parent = bottom
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
	return b
end

local followBtn = mkBtn("FOLLOW : OFF", 1, Color3.fromRGB(38,38,44))
local noclipBtn = mkBtn("NOCLIP : OFF", 2, Color3.fromRGB(48,48,58))

local discordRow = Instance.new("Frame")
discordRow.LayoutOrder = 3
discordRow.BackgroundTransparency = 1
discordRow.Size = UDim2.new(1, 0, 0, 36)
discordRow.Parent = bottom

local BTN_W, GAP = 80, 10
local rightButtonsTotal = (BTN_W * 2 + GAP)

local discordText = Instance.new("TextLabel")
discordText.BackgroundTransparency = 1
discordText.Size = UDim2.new(1, -rightButtonsTotal, 1, 0)
discordText.Font = Enum.Font.Gotham
discordText.TextSize = 14
discordText.TextXAlignment = Enum.TextXAlignment.Left
discordText.TextColor3 = Color3.fromRGB(170,170,175)
discordText.Text = "Discord: " .. DISCORD_INVITE
discordText.ClipsDescendants = true
discordText.Parent = discordRow

local copyBox = Instance.new("TextBox")
copyBox.Size = UDim2.new(1, -rightButtonsTotal, 1, 0)
copyBox.BackgroundTransparency = 1
copyBox.TextTransparency = 1
copyBox.TextEditable = false
copyBox.ClearTextOnFocus = false
copyBox.Text = DISCORD_INVITE
copyBox.Parent = discordRow

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.fromOffset(BTN_W, 36)
copyBtn.Position = UDim2.new(1, -(BTN_W*2 + GAP), 0, 0)
copyBtn.AutoButtonColor = false
copyBtn.BackgroundColor3 = Color3.fromRGB(88,101,242)
copyBtn.Text = "Copy"
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 14
copyBtn.TextColor3 = Color3.fromRGB(255,255,255)
copyBtn.Parent = discordRow
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 10)

local runBtn = Instance.new("TextButton")
runBtn.Size = UDim2.fromOffset(BTN_W, 36)
runBtn.Position = UDim2.new(1, -BTN_W, 0, 0)
runBtn.AutoButtonColor = false
runBtn.Text = "Fling/Yield"
runBtn.Font = Enum.Font.GothamBold
runBtn.TextSize = 14
runBtn.TextColor3 = Color3.fromRGB(255,255,255)
runBtn.Parent = discordRow
Instance.new("UICorner", runBtn).CornerRadius = UDim.new(0, 10)

local function setRunEnabled(enabled: boolean)
	runBtn.Active = enabled
	runBtn.AutoButtonColor = enabled
	runBtn.BackgroundColor3 = enabled and Color3.fromRGB(70, 140, 110) or Color3.fromRGB(55, 55, 60)
	runBtn.TextTransparency = enabled and 0 or 0.25
end
setRunEnabled(ExtraAction ~= nil)

-- Player list
local listFrame = Instance.new("ScrollingFrame")
listFrame.BackgroundColor3 = Color3.fromRGB(18,18,22)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 6
listFrame.Parent = main
Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 12)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listFrame

local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 10)
listPad.PaddingBottom = UDim.new(0, 10)
listPad.PaddingLeft = UDim.new(0, 10)
listPad.PaddingRight = UDim.new(0, 10)
listPad.Parent = listFrame

-- Layout calc: auto based on actual objects positions/sizes
local function recalcLayout()
	local leftPad = 18
	local rightPad = 36

	local listTop = searchBox.AbsolutePosition.Y - main.AbsolutePosition.Y + searchBox.AbsoluteSize.Y + 10
	local bottomTop = bottom.AbsolutePosition.Y - main.AbsolutePosition.Y
	local available = bottomTop - listTop - 10
	if available < 120 then available = 120 end

	listFrame.Position = UDim2.new(0, leftPad, 0, listTop)
	listFrame.Size = UDim2.new(1, -rightPad, 0, available)
end

recalcLayout()
main:GetPropertyChangedSignal("AbsoluteSize"):Connect(recalcLayout)
searchBox:GetPropertyChangedSignal("AbsolutePosition"):Connect(recalcLayout)
bottom:GetPropertyChangedSignal("AbsolutePosition"):Connect(recalcLayout)

-- ========================= MINIMIZE =========================
local minimized = false
local expandedSize = main.Size

local function setContentVisible(v: boolean)
	searchBox.Visible = v
	listFrame.Visible = v
	bottom.Visible = v
end

minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	if minimized then
		tween(main, UI_TWEEN_MED, { Size = UDim2.fromOffset(expandedSize.X.Offset, 78) })
		task.delay(0.12, function()
			setContentVisible(false)
			sub.Text = "Minimized • Click — to expand"
		end)
	else
		setContentVisible(true)
		sub.Text = "Select player • Follow • Noclip • Discord"
		tween(main, UI_TWEEN_MED, { Size = expandedSize })
		task.delay(0.05, recalcLayout)
	end
end)

-- ========================= LIST BUILD =========================
local function refreshCanvas()
	task.defer(function()
		listFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
	end)
end

local function clearListButtons()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
end

local function buildPlayerButton(plr: Player)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 46)
	b.Text = plr.Name
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.TextColor3 = Color3.fromRGB(255,255,255)
	b.BackgroundColor3 = Color3.fromRGB(44,44,52)
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Parent = listFrame
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)

	b.MouseButton1Click:Connect(function()
		selectedPlayer = plr
		clearTargetCache()
		sub.Text = "Target: " .. plr.Name
	end)
end

local function rebuildList(filter: string?)
	filter = (filter or ""):lower()
	clearListButtons()

	local plrs = Players:GetPlayers()
	table.sort(plrs, function(a,b) return a.Name:lower() < b.Name:lower() end)

	for _, plr in ipairs(plrs) do
		if plr ~= LocalPlayer then
			if filter == "" or plr.Name:lower():find(filter, 1, true) then
				buildPlayerButton(plr)
			end
		end
	end

	refreshCanvas()
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	rebuildList(searchBox.Text)
end)

Players.PlayerAdded:Connect(function()
	rebuildList(searchBox.Text)
end)

Players.PlayerRemoving:Connect(function(plr)
	if selectedPlayer == plr then
		selectedPlayer = nil
		clearTargetCache()
		stopFollow()
		followBtn.Text = "FOLLOW : OFF"
		sub.Text = "Select player • Follow • Noclip • Discord"
	end
	rebuildList(searchBox.Text)
end)

-- ========================= BUTTONS =========================
local function setFollowUI(on: boolean)
	if on then
		followBtn.Text = "FOLLOW : ON"
		followBtn.BackgroundColor3 = Color3.fromRGB(50,110,70)
	else
		followBtn.Text = "FOLLOW : OFF"
		followBtn.BackgroundColor3 = Color3.fromRGB(38,38,44)
	end
end

followBtn.MouseButton1Click:Connect(function()
	if following then
		stopFollow()
		setFollowUI(false)
		return
	end
	if not selectedPlayer then
		notify("Select a player first.")
		return
	end
	startFollow()
	setFollowUI(true)
end)

noclipBtn.MouseButton1Click:Connect(function()
	noclipOn = not noclipOn
	applyNoclip(noclipOn)
	noclipBtn.Text = noclipOn and "NOCLIP : ON" or "NOCLIP : OFF"
	noclipBtn.BackgroundColor3 = noclipOn and Color3.fromRGB(70,120,90) or Color3.fromRGB(48,48,58)
end)

copyBtn.MouseButton1Click:Connect(function()
	local ok = tryCopyToClipboard(DISCORD_INVITE)
	if ok then
		notify("Discord copied to clipboard!")
	else
		copyBox.TextTransparency = 0
		copyBox.TextEditable = true
		copyBox:CaptureFocus()
		copyBox.SelectionStart = 1
		copyBox.CursorPosition = #copyBox.Text + 1
		notify("Clipboard not available. Text selected, press Ctrl+C.")
		task.delay(1.2, function()
			if copyBox and copyBox.Parent then
				copyBox:ReleaseFocus()
				copyBox.TextEditable = false
				copyBox.TextTransparency = 1
			end
		end)
	end
end)

runBtn.MouseButton1Click:Connect(function()

	if not ExtraAction then
		loadExtraAction()
		setRunEnabled(ExtraAction ~= nil)
	end
	if not ExtraAction then
		notify("DiscordExtraAction not found.")
		return
	end

	local ok, err = pcall(function()
		if typeof(ExtraAction) == "table" and typeof(ExtraAction.Run) == "function" then
			ExtraAction.Run(LocalPlayer)
		elseif typeof(ExtraAction) == "function" then
			ExtraAction(LocalPlayer)
		else
			error("DiscordExtraAction must return a function or a table with Run()")
		end
	end)

	if ok then
		notify("Script exécuté !")
	else
		warn("[FollowPlayer] ExtraAction error:", err)
		notify("Erreur: check console (F9)")
	end
end)

-- ========================= DRAG =========================
do
	local dragging = false
	local dragStartPos: Vector2? = nil
	local frameStartPos: UDim2? = nil
	local dragInput: InputObject? = nil

	local function update(input: InputObject)
		if not dragging or not dragStartPos or not frameStartPos then return end
		local delta = input.Position - dragStartPos
		main.Position = UDim2.new(
			frameStartPos.X.Scale,
			frameStartPos.X.Offset + delta.X,
			frameStartPos.Y.Scale,
			frameStartPos.Y.Offset + delta.Y
		)
	end

	topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStartPos = input.Position
			frameStartPos = main.Position
			dragInput = input
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)

	topBar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput then update(input) end
	end)
end

-- ========================= RESPAWN HANDLING =========================
LocalPlayer.CharacterAdded:Connect(function()
	clearMyCache()
	if following then
		task.wait(0.2)
		startFollow()
	end
	if noclipOn then
		task.wait(0.2)
		applyNoclip(true)
	end
end)

-- If selected target respawns, caches will update automatically (refreshCaches)
-- init
rebuildList("")
setFollowUI(false)
