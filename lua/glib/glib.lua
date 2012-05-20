if GLib then return end
GLib = {}

if SERVER then
	function GLib.AddCSLuaFolder (folder)
		local files = file.FindInLua (folder .. "/*")
		for _, fileName in pairs (files) do
			if fileName:sub (-4) == ".lua" then
				AddCSLuaFile (folder .. "/" .. fileName)
			end
		end
	end

	function GLib.AddCSLuaFolderRecursive (folder)
		GLib.AddCSLuaFolder (folder)
		local folders = file.FindDir ("lua/" .. folder .. "/*", true)
		for _, childFolder in pairs (folders) do
			GLib.AddCSLuaFolderRecursive (folder .. "/" .. childFolder)
		end
	end
	
	function GLib.AddReloadCommand (includePath, systemName, systemTableName)
		includePath = includePath or (systemName .. "/" .. systemName .. ".lua")
		
		concommand.Add (systemName .. "_reload_sv", function (ply, _, arg)
			if ply and ply:IsValid () and not ply:IsSuperAdmin () then return end
		
			local startTime = SysTime ()
			GLib.UnloadSystem (systemTableName)
			include (includePath)
			GLib.Debug (systemName .. "_reload took " .. tostring ((SysTime () - startTime) * 1000) .. " ms.")
		end)
		concommand.Add (systemName .. "_reload_sh", function (ply, _, arg)
			if ply and ply:IsValid () and not ply:IsSuperAdmin () then return end
			
			local startTime = SysTime ()
			GLib.UnloadSystem (systemTableName)
			include (includePath)
			for _, ply in ipairs (player.GetAll ()) do
				ply:ConCommand (systemName .. "_reload")
			end
			GLib.Debug (systemName .. "_reload took " .. tostring ((SysTime () - startTime) * 1000) .. " ms.")
		end)
	end
	
	GLib.AddCSLuaFolderRecursive ("glib")
elseif CLIENT then
	function GLib.AddCSLuaFolder (folder) end
	function GLib.AddCSLuaFolderRecursive (folder) end
	
	function GLib.AddReloadCommand (includePath, systemName, systemTableName)
		includePath = includePath or (systemName .. "/" .. systemName .. ".lua")
		
		concommand.Add (systemName .. "_reload", function (ply, _, arg)
			local startTime = SysTime ()
			GLib.UnloadSystem (systemTableName)
			include (includePath)
			GLib.Debug (systemName .. "_reload took " .. tostring ((SysTime () - startTime) * 1000) .. " ms.")
		end)
	end
end
GLib.AddReloadCommand ("glib/glib.lua", "glib", "GLib")

function GLib.Debug (message)
	-- ErrorNoHalt (message .. "\n")
end

function GLib.EnumerateDelayed (tbl, callback, finishCallback)
	if not callback then return end

	local next, tbl, key = pairs (tbl)
	local value = nil
	local function timerCallback ()
		key, value = next (tbl, key)
		if not key and finishCallback then finishCallback () return end
		callback (key, value)
		if not key then return end
		timer.Simple (0, timerCallback)
	end
	timer.Simple (0, timerCallback)
end

function GLib.Error (message)
	ErrorNoHalt (message .. "\n")
	GLib.PrintStackTrace ()
end

function GLib.FindUpValue (func, name)
	local i = 1
	local a, b = true, nil
	while a ~= nil do
		a, b = debug.getupvalue (func, i)
		if a == name then return b end
		i = i + 1
	end
end

function GLib.GetMetaTable (constructor)
	local name, basetable = debug.getupvalue (constructor, 1)
	return basetable
end

function GLib.GetStackDepth ()
	local i = 0
	while debug.getinfo (i) do
		i = i + 1
	end
	return i
end

function GLib.Import (tbl)
	for k, v in pairs (GLib) do
		if type (v) == "function" then
			tbl [k] = v
		elseif type (v) == "table" then
			tbl [k] = {}
			tbl [k].__index = v
			setmetatable (tbl [k], tbl [k])
		end
	end
end

function GLib.IncludeDirectory (dir, recursive)
	for _, file in ipairs (file.FindInLua (dir .. "/*.lua")) do
		if file:sub (-4):lower () == ".lua" then
			include (dir .. "/" .. file)
		elseif recursive then
			if file ~= "." and file ~= ".." then
				GLib.IncludeDirectory (dir .. "/" .. file, recursive)
			end
		end
	end
end

function GLib.InvertTable (tbl)
	local keys = {}
	for key, Value in pairs (tbl) do
		keys [#keys + 1] = key
	end
	for i = 1, #keys do
		tbl [tbl [keys [i]]] = keys [i]
	end
end

--[[
	GLib.MakeConstructor (metatable, base, base2)
		Returns: ()->Object
		
		Produces a constructor for the object defined by metatable.
		base may be nil or the constructor of a base class.
		base2 may be nil or the constructor of another base class.
		The second base class must not be a class with inheritance.
]]
function GLib.MakeConstructor (metatable, base, base2)
	metatable.__index = metatable
	
	if base then
		local basetable = GLib.GetMetaTable (base)
		metatable.__base = basetable
		setmetatable (metatable, basetable)
		
		if base2 then
			local base2table = base2
			if type (base2) == "function" then base2table = GLib.GetMetaTable (base2) end
			for k, v in pairs (base2table) do
				if k:sub (1, 2) ~= "__" then metatable [k] = v end
			end
			metatable.ctor2 = base2table.ctor
		end
	end
	
	return function (...)
		local object = {}
		setmetatable (object, metatable)
		
		-- Create constructor and destructor
		if not object.__ctor or not object.__dtor then
			local base = metatable
			local ctors = {}
			local dtors = {}
			while base ~= nil do
				ctors [#ctors + 1] = base.ctor
				ctors [#ctors + 1] = base.ctor2
				dtors [#dtors + 1] = base.dtor
				base = base.__base
			end
			
			function metatable:__ctor (...)
				for i = #ctors, 1, -1 do
					ctors [i] (self, ...)
				end
			end
			function metatable:__dtor (...)
				for i = 1, #dtors do
					dtors [i] (self, ...)
				end
			end
		end
		
		object.dtor = object.__dtor
		object:__ctor (...)
		return object
	end
end

function GLib.PrintStackTrace (levels, offset)
	local offset = offset or 0
	local exit = false
	local i = 0
	local shown = 0
	while not exit do
		local t = debug.getinfo (i)
		if not t or shown == levels then
			exit = true
		else
			local name = t.name
			local src = t.short_src
			src = src or "<unknown>"
			if i >= offset then
				shown = shown + 1
				if name then
					ErrorNoHalt (tostring (i) .. ": " .. name .. " (" .. src .. ": " .. tostring (t.currentline) .. ")\n")
				else
					if src and t.currentline then
						ErrorNoHalt (tostring (i) .. ": (" .. src .. ": " .. tostring (t.currentline) .. ")\n")
					else
						ErrorNoHalt (tostring (i) .. ":\n")
						PrintTable (t)
					end
				end
			end
		end
		i = i + 1
	end
end

function GLib.UnloadSystem (systemTableName)
	if not systemTableName then return end
	if type (_G [systemTableName]) == "table" and
		type (_G [systemTableName].DispatchEvent) == "function" then
		_G [systemTableName]:DispatchEvent ("Unloaded")
	end
	_G [systemTableName] = nil
end

function GLib.WeakKeyTable ()
	local tbl = {}
	setmetatable (tbl, { __mode = "v" })
	return tbl
end

function GLib.WeakValueTable ()
	local tbl = {}
	setmetatable (tbl, { __mode = "v" })
	return tbl
end

include ("eventprovider.lua")
include ("playermonitor.lua")
include ("utf8.lua")

include ("net/net.lua")
include ("net/datatype.lua")
include ("net/outbuffer.lua")
include ("net/concommanddispatcher.lua")
include ("net/usermessagedispatcher.lua")
include ("net/concommandinbuffer.lua")
include ("net/datastreaminbuffer.lua")
include ("net/usermessageinbuffer.lua")
include ("net/stringtable.lua")

include ("protocol/protocol.lua")
include ("protocol/channel.lua")
include ("protocol/endpoint.lua")
include ("protocol/endpointmanager.lua")
include ("protocol/session.lua")