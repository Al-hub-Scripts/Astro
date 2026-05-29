--[[ ConfigManager — flag registry + save/load + named profiles + autoload.
     Every file call is guarded; with no file API the whole thing no-ops cleanly
     and the library still works in memory. Load applies values through each
     component's :Set() so the UI animates to the loaded state. ]]
return function(require)
	local HttpService = game:GetService("HttpService")

	local ConfigManager = {}
	ConfigManager.__index = ConfigManager

	-- Detect the executor file API once. Any missing piece → persistence off.
	local hasFiles = type(writefile) == "function"
		and type(readfile) == "function"
		and type(isfile) == "function"
		and type(listfiles) == "function"

	local function safe(fn, ...)
		local ok, res = pcall(fn, ...)
		if ok then
			return res
		end
		return nil
	end

	-- ---- value (de)serialization for JSON-hostile types ----
	local function serialize(value)
		local t = typeof(value)
		if t == "Color3" then
			return { __t = "Color3", r = value.R, g = value.G, b = value.B }
		elseif t == "EnumItem" then
			return { __t = "KeyCode", name = value.Name }
		elseif t == "table" then
			local out = {}
			for k, v in pairs(value) do
				out[k] = serialize(v)
			end
			return out
		end
		return value
	end

	local function deserialize(value)
		if type(value) == "table" then
			if value.__t == "Color3" then
				return Color3.new(value.r, value.g, value.b)
			elseif value.__t == "KeyCode" then
				return Enum.KeyCode[value.name]
			end
			local out = {}
			for k, v in pairs(value) do
				out[k] = deserialize(v)
			end
			return out
		end
		return value
	end

	function ConfigManager.new(ctx)
		local self = setmetatable({}, ConfigManager)
		self._flags = {}
		self.enabled = hasFiles
		self.root = (ctx.folder or "Astrophysics")
		self.configs = self.root .. "/configs"

		if hasFiles then
			if type(makefolder) == "function" then
				if type(isfolder) ~= "function" or not safe(isfolder, self.root) then
					safe(makefolder, self.root)
				end
				if type(isfolder) ~= "function" or not safe(isfolder, self.configs) then
					safe(makefolder, self.configs)
				end
			end
		end
		return self
	end

	function ConfigManager:register(flag, handle)
		self._flags[flag] = handle
	end

	function ConfigManager:unbindAll()
		self._flags = {}
	end

	function ConfigManager:getValues()
		local values = {}
		for flag, handle in pairs(self._flags) do
			local ok, v = pcall(function()
				return handle:Get()
			end)
			if ok then
				values[flag] = serialize(v)
			end
		end
		return values
	end

	-- Apply a values table through component :Set() so the UI animates + feature
	-- callbacks fire.
	function ConfigManager:setValues(values)
		for flag, raw in pairs(values) do
			local handle = self._flags[flag]
			if handle and handle.Set then
				pcall(function()
					handle:Set(deserialize(raw))
				end)
			end
		end
	end

	local function profilePath(self, name)
		return self.configs .. "/" .. name .. ".json"
	end

	function ConfigManager:save(name)
		if not self.enabled then
			return false, "no file api"
		end
		name = name or "default"
		local payload = safe(function()
			return HttpService:JSONEncode({ values = self:getValues() })
		end)
		if not payload then
			return false, "encode failed"
		end
		safe(writefile, profilePath(self, name), payload)
		return true
	end

	function ConfigManager:load(name)
		if not self.enabled then
			return false, "no file api"
		end
		name = name or "default"
		local path = profilePath(self, name)
		if not safe(isfile, path) then
			return false, "missing"
		end
		local raw = safe(readfile, path)
		if not raw then
			return false, "read failed"
		end
		local data = safe(function()
			return HttpService:JSONDecode(raw)
		end)
		if not data or not data.values then
			return false, "decode failed"
		end
		self:setValues(data.values)
		return true
	end

	function ConfigManager:list()
		if not self.enabled then
			return {}
		end
		local files = safe(listfiles, self.configs) or {}
		local names = {}
		for _, path in ipairs(files) do
			-- handle both / and \ separators across executors
			local name = tostring(path):match("([^/\\]+)%.json$")
			if name then
				table.insert(names, name)
			end
		end
		table.sort(names)
		return names
	end

	function ConfigManager:delete(name)
		if not self.enabled or type(delfile) ~= "function" then
			return false
		end
		local path = profilePath(self, name)
		if safe(isfile, path) then
			safe(delfile, path)
			return true
		end
		return false
	end

	-- ---- autoload bookkeeping ----
	local function autoPath(self)
		return self.root .. "/autoload.txt"
	end

	function ConfigManager:setAutoload(name)
		if not self.enabled then
			return false
		end
		safe(writefile, autoPath(self), tostring(name or ""))
		return true
	end

	function ConfigManager:getAutoload()
		if not self.enabled then
			return nil
		end
		if not safe(isfile, autoPath(self)) then
			return nil
		end
		local name = safe(readfile, autoPath(self))
		if name and name ~= "" then
			return name
		end
		return nil
	end

	function ConfigManager:autoload()
		local name = self:getAutoload()
		if name then
			return self:load(name)
		end
		return false
	end

	return ConfigManager
end
