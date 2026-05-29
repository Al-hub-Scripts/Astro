--[[ Keybinds — ONE global InputBegan listener dispatches to every registered
     bind plus the window toggle key. Components route through here instead of
     each spawning their own connection. ]]
return function(require)
	local UserInputService = game:GetService("UserInputService")

	local Keybinds = {}
	Keybinds.__index = Keybinds

	function Keybinds.new(ctx)
		local self = setmetatable({}, Keybinds)
		self._binds = {} -- [id] = { key = KeyCode, fn = function }
		self._toggle = nil -- { key = KeyCode, fn = function }

		local conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			-- gameProcessed is true while typing in a TextBox etc. — ignore so
			-- keybinds don't fire mid-text-entry.
			if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			local key = input.KeyCode
			if self._toggle and key == self._toggle.key then
				task.spawn(self._toggle.fn)
			end
			for _, bind in pairs(self._binds) do
				if bind.key == key and bind.fn then
					task.spawn(bind.fn)
				end
			end
		end)
		ctx.maid:give(conn)
		return self
	end

	function Keybinds:setToggle(key, fn)
		self._toggle = { key = key, fn = fn }
	end

	function Keybinds:setToggleKey(key)
		if self._toggle then
			self._toggle.key = key
		end
	end

	function Keybinds:bind(id, key, fn)
		self._binds[id] = { key = key, fn = fn }
	end

	function Keybinds:unbind(id)
		self._binds[id] = nil
	end

	return Keybinds
end
