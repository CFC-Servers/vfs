if VFS then return end
VFS = VFS or {}

local t = GLib.LoadTimer ("VFS")

if not _G.GLib then
    include ("glib/glib.lua")
    t.step ("Load GLib")
end

if not _G.Gooey then
    include ("gooey/gooey.lua")
    t.step ("Load Gooey")
end

if not _G.GAuth then
    include ("gauth/gauth.lua")
    t.step ("Load GAuth")
end

GLib.Initialize ("VFS", VFS)
GLib.AddCSLuaPackSystem ("VFS")
GLib.AddCSLuaPackFile ("autorun/vfs.lua")
GLib.AddCSLuaPackFolderRecursive ("vfs")
t.step ("Init")

VFS.PlayerMonitor = VFS.PlayerMonitor ("VFS")
t.step ("PlayerMonitor")

include ("clipboard.lua")
include ("path.lua")
include ("openflags.lua")
include ("returncode.lua")
include ("seektype.lua")
include ("updateflags.lua")
t.step ("Step 1")

include ("filesystemwatcher.lua")
include ("permissionsaver.lua")
t.step ("Step 2")

-- Resources
include ("iresource.lua")
include ("httpresource.lua")
include ("fileresource.lua")
include ("iresourcelocator.lua")
include ("defaultresourcelocator.lua")
t.step ("Step 3")

include ("filesystem/nodetype.lua")
include ("filesystem/inode.lua")
include ("filesystem/ifile.lua")
include ("filesystem/ifolder.lua")
include ("filesystem/ifilestream.lua")
include ("filesystem/memoryfilestream.lua")
t.step ("Step 4")

-- Real
include ("filesystem/realnode.lua")
include ("filesystem/realfile.lua")
include ("filesystem/realfolder.lua")
include ("filesystem/realfilestream.lua")
t.step ("Step 5")

-- Networked
include ("filesystem/netnode.lua")
include ("filesystem/netfile.lua")
include ("filesystem/netfolder.lua")
include ("filesystem/netfilestream.lua")
t.step ("Step 6")

-- Virtual
include ("filesystem/vnode.lua")
include ("filesystem/vfile.lua")
include ("filesystem/vfolder.lua")
include ("filesystem/vfilestream.lua")
t.step ("Step 7")

-- Mounted
include ("filesystem/mountednode.lua")
include ("filesystem/mountedfile.lua")
include ("filesystem/mountedfolder.lua")
include ("filesystem/mountedfilestream.lua")
t.step ("Step 8")

if CLIENT and GetConVar("is_gcompute_user"):GetBool() then
	include ("filetypes.lua")
	include ("filetype.lua")
	t.step ("Filetypes")
end

-- Networking
include ("protocol/protocol.lua")
include ("protocol/session.lua")
include ("protocol/nodecreationnotification.lua")
include ("protocol/nodedeletionnotification.lua")
include ("protocol/noderenamenotification.lua")
include ("protocol/nodeupdatenotification.lua")
include ("protocol/fileopenrequest.lua")
include ("protocol/fileopenresponse.lua")
include ("protocol/folderchildrequest.lua")
include ("protocol/folderchildresponse.lua")
include ("protocol/folderlistingrequest.lua")
include ("protocol/folderlistingresponse.lua")
include ("protocol/nodecreationrequest.lua")
include ("protocol/nodecreationresponse.lua")
include ("protocol/nodedeletionrequest.lua")
include ("protocol/nodedeletionresponse.lua")
include ("protocol/noderenamerequest.lua")
include ("protocol/noderenameresponse.lua")
t.step ("Step 9")

include ("protocol/endpoint.lua")
include ("protocol/endpointmanager.lua")
t.step ("Step 10")

if CLIENT and GetConVar("is_gcompute_user"):GetBool() then
	VFS.IncludeDirectoryAsync ("vfs/ui")
end
t.step ("Step 11")

VFS.AddReloadCommand ("vfs/vfs.lua", "vfs", "VFS")
t.step ("Step 12")

function VFS.Debug (message)
	-- print ("[VFS] " .. message)
end

local nextUniqueName = -1
function VFS.GetUniqueName ()
	nextUniqueName = nextUniqueName + 1
	return string.format ("%08x%02x", os.time (), nextUniqueName % 256)
end

if SERVER then
	function VFS.GetLocalHomeDirectory ()
		return ""
	end
else
	function VFS.GetLocalHomeDirectory ()
		return GAuth.GetLocalId ()
	end
end

function VFS.SanitizeNodeName (segment)
	segment = segment:gsub ("\\", "_")
	segment = segment:gsub ("/", "_")
	if segment == "." then return nil end
	if segment == ".." then return nil end
	return segment
end

function VFS.SanitizeOpenFlags (openFlags)
	if bit.band (openFlags, VFS.OpenFlags.Overwrite) ~= 0 and bit.band (openFlags, VFS.OpenFlags.Write) == 0 then
		openFlags = openFlags - VFS.OpenFlags.Overwrite
	end
	return openFlags
end

t.step ("Step 13")

--[[
	Server:
		root (VFolder)
			STEAM_X:X:X (NetFolder)
			...
			Public (VFolder)
			Admins (VFolder)
			...
	
	Client:
		root (NetFolder)
			STEAM_X:X:X (NetFolder)
			STEAM_LOCAL (VFolder)
]]
VFS.RealRoot    = VFS.RealFolder ("", "GAME", "")
if SERVER then
	VFS.Root = VFS.VFolder ("")
elseif CLIENT then
	VFS.Client = VFS.EndPointManager:GetEndPoint (GAuth.GetServerId ())
	VFS.Root = VFS.Client:GetRoot ()
end
VFS.Root:SetDeletable (false)
VFS.Root:MarkPredicted ()
VFS.PermissionDictionary = GAuth.PermissionDictionary ()
VFS.PermissionDictionary:AddPermission ("Create Folder")
VFS.PermissionDictionary:AddPermission ("Delete")
VFS.PermissionDictionary:AddPermission ("Read")
VFS.PermissionDictionary:AddPermission ("Rename")
VFS.PermissionDictionary:AddPermission ("View Folder")
VFS.PermissionDictionary:AddPermission ("Write")
VFS.Root:GetPermissionBlock ():SetPermissionDictionary (VFS.PermissionDictionary)
VFS.Root:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Everyone", "View Folder",        GAuth.Access.Allow)
VFS.Root:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Modify Permissions", GAuth.Access.Allow)
VFS.Root:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Set Owner",          GAuth.Access.Allow)
VFS.Root:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Create Folder",      GAuth.Access.Allow)
VFS.Root:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Delete",             GAuth.Access.Allow)
VFS.Root:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Read",               GAuth.Access.Allow)
VFS.Root:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Rename",             GAuth.Access.Allow)
VFS.Root:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "View Folder",        GAuth.Access.Allow)
VFS.Root:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Write",              GAuth.Access.Allow)
VFS.Root:ClearPredictedFlag ()

VFS.PermissionSaver:Load ()
VFS.PermissionSaver:HookNodeRecursive (VFS.Root)

t.step ("Step 14")

VFS.IncludeDirectoryAsync ("vfs/folders")
VFS.IncludeDirectoryAsync ("vfs/folders/" .. (SERVER and "server" or "client"))

t.step ("Step 15")

-- Events
VFS.PlayerMonitor:AddEventListener ("PlayerConnected",
	function (_, ply, userId, isLocalPlayer)
		local folder = nil
		local mountedFolder = nil
		if isLocalPlayer then
			-- create the VFolder and mount it into the root NetFolder
			folder = VFS.VFolder (GAuth.GetLocalId (), VFS.Root)
			mountedFolder = VFS.Root:MountLocal (GAuth.GetLocalId (), folder)
		else
			-- pre-empt the NetFolder creation
			local endPoint = nil
			if SERVER then
				endPoint = VFS.EndPointManager:GetEndPoint (userId)
			elseif CLIENT then
				endPoint = VFS.Client
			end
			folder = endPoint:GetRoot ():CreatePredictedFolder (userId)
			mountedFolder = folder
		end
		mountedFolder.PlayerFolder = true
		
		folder:SetDeletable (false)
		folder:MarkPredicted ()
		folder:SetDisplayName (ply:Nick ())
		if SERVER then
			VFS.Root:Mount (userId, folder)
			folder:GetPermissionBlock ():SetParentFunction (
				function ()
					return VFS.Root:GetPermissionBlock ()
				end
			)
		elseif CLIENT then
			if isLocalPlayer then				
				local mountPaths =
				{
					"data/luapad",
				}
				for _, realPath in ipairs (mountPaths) do
					VFS.RealRoot:GetChild (GAuth.GetSystemId (), realPath,
						function (returnCode, node)
							if not node then return end
							folder:Mount (node:GetName (), node)
								:SetDeletable (false)
						end
					)
				end
				
				folder:CreateFolder (GAuth.GetSystemId (), "tmp",
					function (returnCode, node)
						if node then node:SetDeletable (false) end
					end
				)
				
				-- Set up networking
				VFS.EndPointManager:GetEndPoint ("Server"):HookNode (mountedFolder)
				VFS.PermissionBlockNetworker:SynchronizeBlock ("Server", mountedFolder:GetPermissionBlock ())
			end
		end
		
		-- Do permission block stuff after folder has been inserted into filesystem tree
		folder:SetOwner (GAuth.GetSystemId (), userId)
		folder:GetPermissionBlock ():SetInheritPermissions (GAuth.GetSystemId (), false)
		folder:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Modify Permissions", GAuth.Access.Allow)
		folder:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Set Owner",          GAuth.Access.Allow)
		folder:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Create Folder",      GAuth.Access.Allow)
		folder:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Delete",             GAuth.Access.Allow)
		folder:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Read",               GAuth.Access.Allow)
		folder:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Rename",             GAuth.Access.Allow)
		folder:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "View Folder",        GAuth.Access.Allow)
		folder:GetPermissionBlock ():SetGroupPermission (GAuth.GetSystemId (), "Owner",    "Write",              GAuth.Access.Allow)
		folder:ClearPredictedFlag ()
	end
)

VFS.PlayerMonitor:AddEventListener ("PlayerDisconnected",
	function (_, ply, userId)
		if userId == "" then return end
		if SERVER then
			VFS.EndPointManager:RemoveEndPoint (userId)
			if VFS.Root:GetChildSynchronous (userId) then
				VFS.Root:GetChildSynchronous (userId):SetDeletable (true)
				VFS.Root:DeleteChild (GAuth.GetSystemId (), userId)
			end
		end
	end
)

VFS:AddEventListener ("Unloaded", function ()
	VFS.PermissionSaver:dtor ()
	VFS.PlayerMonitor:dtor ()
end)

t.step ("Step 16")
