--[[
    Example.lua — a full demo menu wiring REAL features so the whole library is
    verifiable end to end. ESP / Fly / WalkSpeed all actually run and clean up.

    Load (executor):
        local Astro = loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/Al-hub-Scripts/Astro/refs/heads/main/Loader.lua"))()

    Load (Roblox Studio, no HTTP):
        local Astro = require(path.to.Astrophysics) -- the src/ ModuleScript
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Astro = loadstring(game:HttpGet("https://raw.githubusercontent.com/Al-hub-Scripts/Astro/refs/heads/main/Loader.lua"))()

local Window = Astro:CreateWindow({
	Title = "Astro",
	TitleAccent = "physics",
	Subtitle = "v1.0",
	ToggleKey = Enum.KeyCode.RightShift,
	Theme = "Nebula",
	ConfigFolder = "Astrophysics",
	AutoLoad = true,
	Status = "Initialising…",
})

-- ===========================================================================
--  FEATURE: ESP (Highlight + name billboards, distance-gated)
-- ===========================================================================
local ESP = {
	enabled = false,
	color = Color3.fromRGB(140, 120, 245),
	names = false,
	maxDistance = 1000,
	objects = {}, -- [player] = { highlight, billboard, label }
	conns = {},
}

function ESP:_build(player, character)
	if self.objects[player] then
		pcall(function()
			self.objects[player].highlight:Destroy()
			self.objects[player].billboard:Destroy()
		end)
		self.objects[player] = nil
	end
	local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not head then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = self.color
	highlight.OutlineColor = self.color
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 0
	highlight.Adornee = character
	highlight.Parent = character

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 18)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = head
	billboard.Enabled = false
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextStrokeTransparency = 0.5
	label.TextColor3 = self.color
	label.Text = player.Name
	label.Parent = billboard

	self.objects[player] = { highlight = highlight, billboard = billboard, label = label }
end

function ESP:_track(player)
	if player == LocalPlayer then
		return
	end
	table.insert(
		self.conns,
		player.CharacterAdded:Connect(function(character)
			if self.enabled then
				task.wait(0.2)
				self:_build(player, character)
			end
		end)
	)
	if player.Character then
		self:_build(player, player.Character)
	end
end

function ESP:start()
	if self.enabled then
		return
	end
	self.enabled = true
	for _, player in ipairs(Players:GetPlayers()) do
		self:_track(player)
	end
	table.insert(
		self.conns,
		Players.PlayerAdded:Connect(function(player)
			self:_track(player)
		end)
	)
	table.insert(
		self.conns,
		Players.PlayerRemoving:Connect(function(player)
			local obj = self.objects[player]
			if obj then
				pcall(function()
					obj.highlight:Destroy()
					obj.billboard:Destroy()
				end)
				self.objects[player] = nil
			end
		end)
	)
	-- per-frame: gate by distance, push live colour/name
	table.insert(
		self.conns,
		RunService.RenderStepped:Connect(function()
			local myChar = LocalPlayer.Character
			local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
			for player, obj in pairs(self.objects) do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root and myRoot then
					local dist = (root.Position - myRoot.Position).Magnitude
					local within = dist <= self.maxDistance
					obj.highlight.Enabled = within
					obj.highlight.FillColor = self.color
					obj.highlight.OutlineColor = self.color
					obj.billboard.Enabled = within and self.names
					if within and self.names then
						obj.label.TextColor3 = self.color
						obj.label.Text = string.format("%s  [%dm]", player.Name, math.floor(dist))
					end
				else
					obj.highlight.Enabled = false
					obj.billboard.Enabled = false
				end
			end
		end)
	)
end

function ESP:stop()
	self.enabled = false
	for _, conn in ipairs(self.conns) do
		conn:Disconnect()
	end
	self.conns = {}
	for player, obj in pairs(self.objects) do
		pcall(function()
			obj.highlight:Destroy()
			obj.billboard:Destroy()
		end)
		self.objects[player] = nil
	end
end

-- ===========================================================================
--  FEATURE: Fly (camera-relative, respawn-safe)
-- ===========================================================================
local Fly = { enabled = false, speed = 60, conns = {} }

function Fly:start()
	if self.enabled then
		return
	end
	self.enabled = true
	table.insert(
		self.conns,
		RunService.RenderStepped:Connect(function()
			local char = LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid then
				return
			end
			humanoid.PlatformStand = true
			local cam = Workspace.CurrentCamera.CFrame
			local dir = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				dir += cam.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				dir -= cam.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				dir -= cam.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				dir += cam.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				dir += Vector3.yAxis
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				dir -= Vector3.yAxis
			end
			if dir.Magnitude > 0 then
				dir = dir.Unit
			end
			root.AssemblyLinearVelocity = dir * self.speed
		end)
	)
end

function Fly:stop()
	self.enabled = false
	for _, conn in ipairs(self.conns) do
		conn:Disconnect()
	end
	self.conns = {}
	local char = LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if humanoid then
		humanoid.PlatformStand = false
	end
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

-- ===========================================================================
--  FEATURE: WalkSpeed (respawn-safe)
-- ===========================================================================
local WalkSpeed = { value = 16 }
function WalkSpeed:apply()
	local char = LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = self.value
	end
end
function WalkSpeed:set(v)
	self.value = v
	self:apply()
end

-- Master cleanup list for demo-owned connections (not part of the window).
local demoConns = {}
table.insert(
	demoConns,
	LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.4)
		WalkSpeed:apply()
		if ESP.enabled then
			-- existing players re-tracked via their own CharacterAdded
		end
	end)
)

-- ===========================================================================
--  UI
-- ===========================================================================
Window:Section("Modules")

-- ---------- Visuals ----------
local visuals = Window:CreateTab({ Name = "Visuals" })
local espGroup = visuals:CreateGroup({ Name = "ESP" })

espGroup:Section({ Name = "Player ESP" })
espGroup:Toggle({
	Name = "Enabled",
	Default = false,
	Flag = "esp_enabled",
	Tooltip = "Highlight every other player",
	Callback = function(on)
		if on then
			ESP:start()
		else
			ESP:stop()
		end
		Window:SetStatus(on and "ESP on" or "ESP off")
	end,
})
espGroup:Toggle({
	Name = "Show Names",
	Default = false,
	Flag = "esp_names",
	Callback = function(on)
		ESP.names = on
	end,
})
espGroup:ColorPicker({
	Name = "ESP Colour",
	Default = ESP.color,
	Flag = "esp_color",
	Callback = function(color)
		ESP.color = color
	end,
})
espGroup:Slider({
	Name = "Max Distance",
	Min = 100,
	Max = 5000,
	Default = 1000,
	Increment = 50,
	Suffix = "m",
	Flag = "esp_dist",
	Callback = function(v)
		ESP.maxDistance = v
	end,
})
espGroup:Paragraph({
	Title = "About ESP",
	Body = "Draws an always-on-top highlight on each player plus an optional name tag. Targets beyond the max distance are hidden. Everything is removed when you toggle off or unload.",
})

-- ---------- Movement ----------
local movement = Window:CreateTab({ Name = "Movement" })
local flyGroup = movement:CreateGroup({ Name = "Fly" })

local flyToggle = flyGroup:Toggle({
	Name = "Fly",
	Default = false,
	Flag = "fly_enabled",
	Tooltip = "WASD + Space / Ctrl while flying",
	Callback = function(on)
		if on then
			Fly:start()
		else
			Fly:stop()
		end
	end,
})
flyGroup:Slider({
	Name = "Fly Speed",
	Min = 16,
	Max = 400,
	Default = 60,
	Increment = 2,
	Flag = "fly_speed",
	Callback = function(v)
		Fly.speed = v
	end,
})
flyGroup:Keybind({
	Name = "Toggle Fly",
	Default = Enum.KeyCode.F,
	Flag = "fly_key",
	Callback = function()
		flyToggle:Set(not flyToggle:Get())
	end,
})

local charGroup = movement:CreateGroup({ Name = "Character" })
local speedSlider = charGroup:Slider({
	Name = "WalkSpeed",
	Min = 16,
	Max = 250,
	Default = 16,
	Flag = "walkspeed",
	Callback = function(v)
		WalkSpeed:set(v)
	end,
})
charGroup:Button({
	Name = "Reset WalkSpeed",
	Callback = function()
		speedSlider:Set(16)
	end,
})

-- ---------- Settings ----------
local settings = Window:CreateTab({ Name = "Settings" })

local appearance = settings:CreateGroup({ Name = "Appearance" })
appearance:Dropdown({
	Name = "Theme",
	Options = Astro.Themes,
	Default = "Nebula",
	Flag = "theme",
	Callback = function(name)
		Window:SetTheme(name)
	end,
})
appearance:Keybind({
	Name = "Toggle Menu Key",
	Default = Enum.KeyCode.RightShift,
	Flag = "toggle_key",
	OnChanged = function(key)
		Window:SetToggleKey(key)
	end,
})

local configGroup = settings:CreateGroup({ Name = "Config" })
local currentProfile = "default"
local profileBox = configGroup:Textbox({
	Name = "Profile Name",
	Placeholder = "profile name",
	Default = "default",
	Callback = function(text)
		if text ~= "" then
			currentProfile = text
		end
	end,
})
local profileDropdown
local function refreshProfiles()
	if profileDropdown then
		profileDropdown:SetOptions(Window.config:list())
	end
end
profileDropdown = configGroup:Dropdown({
	Name = "Saved Profiles",
	Options = Window.config:list(),
	Callback = function(name)
		if name then
			currentProfile = name
			profileBox:Set(name, true)
		end
	end,
})
configGroup:Button({
	Name = "Save",
	Callback = function()
		local ok = Window.config:save(currentProfile)
		refreshProfiles()
		Astro:Notify({
			Title = ok and "Saved" or "Save unavailable",
			Content = ok and ("Profile \"" .. currentProfile .. "\" written.") or "No file API on this executor.",
			Type = ok and "success" or "error",
			Duration = 4,
		})
	end,
})
configGroup:Button({
	Name = "Load",
	Callback = function()
		local ok = Window.config:load(currentProfile)
		Astro:Notify({
			Title = ok and "Loaded" or "Load failed",
			Content = ok and ("Profile \"" .. currentProfile .. "\" applied.") or "Profile not found.",
			Type = ok and "success" or "error",
			Duration = 4,
		})
	end,
})
configGroup:Button({
	Name = "Delete",
	Callback = function()
		Window.config:delete(currentProfile)
		refreshProfiles()
		Astro:Notify({ Title = "Deleted", Content = currentProfile, Type = "info", Duration = 3 })
	end,
})
configGroup:Button({
	Name = "Set as Autoload",
	Callback = function()
		Window.config:setAutoload(currentProfile)
		Astro:Notify({
			Title = "Autoload set",
			Content = "\"" .. currentProfile .. "\" will load on startup.",
			Type = "success",
			Duration = 4,
		})
	end,
})

local danger = settings:CreateGroup({ Name = "Danger" })
danger:Paragraph({ Title = "Unload", Body = "Tears down the entire UI, stops every feature, and disconnects all listeners." })
danger:Button({
	Name = "Unload Astrophysics",
	Callback = function()
		ESP:stop()
		Fly:stop()
		for _, conn in ipairs(demoConns) do
			conn:Disconnect()
		end
		demoConns = {}
		Window:Destroy()
	end,
})

-- ===========================================================================
Window:SetStatus("Ready")
Astro:Notify({
	Title = "Astrophysics loaded",
	Content = "Press RightShift to toggle. Drag the title bar to move.",
	Type = "success",
	Duration = 6,
})
