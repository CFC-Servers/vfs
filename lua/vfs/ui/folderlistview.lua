local self = {}

--[[
	Events:
		SelectedFileChanged (IFile file)
			Fired when a file is selected from the list.
		SelectedFolderChanged (IFolder folder)
			Fired when a folder is selected from the list.
		NodeOpened (INode node)
			Fired when a file or folder is double clicked.
		SelectedNodeChanged (INode node)
			Fired when a file or folder is selected from the list.
]]

function self:Init ()
	self.Folder = nil
	self.ChildNodes = {}
	self.HookedNodes = {} -- IFolders whose PermissionsChanged event have been hooked
	self.LastAccess = false
	self.LastReadAccess = false
	
	self:AddColumn ("Name")
	self:AddColumn ("Size")
		:SetAlignment (6)
		:SetMaxWidth (128)
	self:AddColumn ("Last Modified")
		:SetMaxWidth (192)
	
	self:SetColumnComparator ("Size",
		function (a, b)
			-- Put folders at the top
			if a == b then return false end
			if a.Node:IsFolder () and not b.Node:IsFolder () then return true end
			if b.Node:IsFolder () and not a.Node:IsFolder () then return false end
			return a.Size < b.Size
		end
	)
	
	self:SetColumnComparator ("Last Modified",
		function (a, b)
			-- Put folders at the top
			if a == b then return false end
			if a.Node:IsFolder () and not b.Node:IsFolder () then return true end
			if b.Node:IsFolder () and not a.Node:IsFolder () then return false end
			return a.LastModified < b.LastModified
		end
	)

	self.Menu = vgui.Create ("GMenu")
	self.Menu:AddEventListener ("MenuOpening",
		function (_, targetItem)
			local targetItem = self:GetSelectedNodes ()
			self.Menu:SetTargetItem (targetItem)
			self.Menu:GetItemById ("Permissions"):SetEnabled (#targetItem ~= 0)
			
			if self.Folder and self.Folder:IsFolder () then
				local permissionBlock = self.Folder:GetPermissionBlock ()
				if not permissionBlock then
					self.Menu:GetItemById ("Copy")         :SetEnabled (#targetItem ~= 0)
					self.Menu:GetItemById ("Paste")        :SetEnabled (true)
					self.Menu:GetItemById ("Create Folder"):SetEnabled (true)
					self.Menu:GetItemById ("Delete")       :SetEnabled (#targetItem ~= 0 and targetItem [1]:CanDelete ())
					self.Menu:GetItemById ("Rename")       :SetEnabled (#targetItem ~= 0)
				else
					self.Menu:GetItemById ("Copy")         :SetEnabled (#targetItem ~= 0 and (permissionBlock:IsAuthorized (GAuth.GetLocalId (), "Read") or permissionBlock:IsAuthorized (GAuth.GetLocalId (), "View Folder")))
					self.Menu:GetItemById ("Paste")        :SetEnabled (VFS.Clipboard:CanPaste (self.Folder))
					self.Menu:GetItemById ("Create Folder"):SetEnabled (not permissionBlock or permissionBlock:IsAuthorized (GAuth.GetLocalId (), "Create Folder"))
					self.Menu:GetItemById ("Delete")       :SetEnabled (#targetItem ~= 0 and targetItem [1]:CanDelete () and (not targetItem [1]:GetPermissionBlock () or targetItem [1]:GetPermissionBlock ():IsAuthorized (GAuth.GetLocalId (), "Delete")))
					self.Menu:GetItemById ("Rename")       :SetEnabled (#targetItem ~= 0 and (not targetItem [1]:GetPermissionBlock () or targetItem [1]:GetPermissionBlock ():IsAuthorized (GAuth.GetLocalId (), "Rename")))
				end
			else
				self.Menu:GetItemById ("Copy")         :SetEnabled (false)
				self.Menu:GetItemById ("Paste")        :SetEnabled (false)
				self.Menu:GetItemById ("Create Folder"):SetEnabled (false)
				self.Menu:GetItemById ("Delete")       :SetEnabled (false)
				self.Menu:GetItemById ("Rename")       :SetEnabled (false)
			end
		end
	)
	self.Menu:AddOption ("Copy",
		function (targetNodes)
			if #targetNodes == 0 then return end
			VFS.Clipboard:Clear ()
			for _, node in ipairs (targetNodes) do
				VFS.Clipboard:Add (node)
			end
		end
	):SetIcon ("gui/g_silkicons/page_white_copy")
	self.Menu:AddOption ("Paste",
		function ()
			VFS.Clipboard:Paste (self.Folder)
		end
	):SetIcon ("gui/g_silkicons/paste_plain")
	self.Menu:AddSeparator ()
	self.Menu:AddOption ("Create Folder",
		function ()
			if not self.Folder then return end
			local folder = self.Folder
			Derma_StringRequest ("Create folder...", "Enter the name of the new folder:", "", function (name)
				folder:CreateFolder (GAuth.GetLocalId (), name)
			end)
		end
	):SetIcon ("gui/g_silkicons/folder_add")
	self.Menu:AddOption ("Delete",
		function (targetNodes)
			if not self.Folder then return end
			if not targetNodes then return end
			if #targetNodes == 0 then return end
			local names = ""
			for i = 1, 3 do
				if i > 1 then
					if i == #targetNodes then names = names .. " and "
					else names = names .. ", " end
				end
				names = names .. targetNodes [i]:GetDisplayName ()
				if i == #targetNodes then break end
			end
			if #targetNodes > 3 then names = names .. " and " .. (#targetNodes - 3) .. " more item" .. ((#targetNodes - 3) > 1 and "s" or "") end
			Derma_Query ("Are you sure you want to delete " .. names .. "?", "Confirm deletion",
				"Yes",
					function ()					
						for _, node in ipairs (targetNodes) do
							node:Delete (GAuth.GetLocalId ())
						end
					end,
				"No", VFS.NullCallback
			)
		end
	):SetIcon ("gui/g_silkicons/cross")
	self.Menu:AddOption ("Rename",
		function (targetNodes)
			if not targetNodes then return end
			if #targetNodes == 0 then return end
			Derma_StringRequest ("Rename " .. targetNodes [1]:GetName () .. "...", "Enter " .. targetNodes [1]:GetName () .. "'s new name:", targetNodes [1]:GetName (),
				function (name)
					name = VFS.SanitizeNodeName (name)
					if not name then return end
					targetNodes [1]:Rename (GAuth.GetLocalId (), name)
				end
			)
		end
	):SetIcon ("gui/g_silkicons/pencil")
	self.Menu:AddSeparator ()
	self.Menu:AddOption ("Permissions",
		function (targetNodes)
			if not self.Folder then return end
			if not targetNodes then return end
			if #targetNodes == 0 then return end
			GAuth.OpenPermissions (targetNodes [1]:GetPermissionBlock ())
		end
	):SetIcon ("gui/g_silkicons/key")
	
	self:AddEventListener ("DoubleClick",
		function (_, item)
			if not item then return end
			if not item.Node then return end
			self:DispatchEvent ("NodeOpened", item.Node)
		end
	)
	
	self:AddEventListener ("SelectionChanged",
		function (_, item)
			local node = item and item.Node or nil
			self:DispatchEvent ("SelectedNodeChanged", node)
			self:DispatchEvent ("SelectedFileChanged", node and node:IsFile () and node or nil)
			self:DispatchEvent ("SelectedFolderChanged", node and node:IsFolder () and node or nil)
		end
	)
	
	self.PermissionsChanged = function (_)
		local access = self.Folder:GetPermissionBlock ():IsAuthorized (GAuth.GetLocalId (), "View Folder")
		local readAccess = self.Folder:GetPermissionBlock ():IsAuthorized (GAuth.GetLocalId (), "Read")
		if self.LastAccess ~= access then
			self.LastAccess = access
			if self.LastAccess then
				self:MergeRefresh ()
			else
				self:Clear ()
				self.ChildNodes = {}
			end
		end
		if self.LastReadAccess ~= readAccess then
			self.LastReadAccess = readAccess
			for _, listViewItem in pairs (self.ChildNodes) do
				if listViewItem.IsFile then
					self:UpdateIcon (listViewItem)
				end
			end
		end
	end
end

function self.DefaultComparator (a, b)
	-- Put folders at the top
	if a == b then return false end
	if a.Node:IsFolder () and not b.Node:IsFolder () then return true end
	if b.Node:IsFolder () and not a.Node:IsFolder () then return false end
	return a:GetText ():lower () < b:GetText ():lower ()
end

function self:GetFolder ()
	return self.Folder
end

function self:GetPath ()
	if not self.Folder then return nil end
	return self.Folder:GetPath ()
end

function self:GetSelectedFile ()
	local node = self:GetSelectedNode ()
	return node:IsFile () and node or nil
end

function self:GetSelectedFolder ()
	local node = self:GetSelectedNode ()
	return node:IsFolder () and node or nil
end

function self:GetSelectedNode ()
	local item = self.SelectionController:GetSelectedItem ()
	return item and item.Node or nil
end

function self:GetSelectedNodes ()
	local selectedNodes = {}
	for _, item in ipairs (self.SelectionController:GetSelectedItems ()) do
		selectedNodes [#selectedNodes + 1] = item.Node
	end
	return selectedNodes
end

function self:MergeRefresh ()
	if not self.Folder then return end

	local folder = self.Folder
	self.Folder:EnumerateChildren (GAuth.GetLocalId (),
		function (returnCode, node)
			if self.Folder ~= folder then return end
			
			if returnCode == VFS.ReturnCode.Success then
				self:AddNode (node)
			elseif returnCode == VFS.ReturnCode.EndOfBurst then
				self:Sort ()
			elseif returnCode == VFS.ReturnCode.AccessDenied then
			elseif returnCode == VFS.ReturnCode.Finished then				
				self.Folder:AddEventListener ("NodeCreated", tostring (self:GetTable ()),
					function (_, newNode)
						self:AddNode (newNode)
						self:Sort ()
					end
				)
				
				self.Folder:AddEventListener ("NodeDeleted", tostring (self:GetTable ()),
					function (_, deletedNode)
						self:RemoveItem (self.ChildNodes [deletedNode:GetName ()])
						self.ChildNodes [deletedNode:GetName ()] = nil
					end
				)
				
				self:Sort ()
			end
		end
	)
end

function self:SetFolder (folder)
	if type (folder) == "string" then
		VFS.Error ("FolderListView:SetFolder was called with a string. Did you mean SetPath?")
		self:SetPath (folder)
	end
	if self.Folder == folder then return end

	self:Clear ()
	self.ChildNodes = {}
	if self.Folder then
		self.Folder:RemoveEventListener ("NodeCreated",            tostring (self:GetTable ()))
		self.Folder:RemoveEventListener ("NodeDeleted",            tostring (self:GetTable ()))
		self.Folder:RemoveEventListener ("NodePermissionsChanged", tostring (self:GetTable ()))
		self.Folder:RemoveEventListener ("NodeRenamed",            tostring (self:GetTable ()))
		self.Folder:RemoveEventListener ("NodeUpdated",            tostring (self:GetTable ()))
		
		for i = #self.HookedNodes, 1, -1 do
			self.HookedNodes [i]:RemoveEventListener ("PermissionsChanged", tostring (self:GetTable ()))
			self.HookedNodes [i] = nil
		end
		self.Folder = nil
	end
	if not folder then return end
	if not folder:IsFolder () then return end
	self.Folder = folder
	self:MergeRefresh ()
	
	self.Folder:AddEventListener ("NodePermissionsChanged", tostring (self:GetTable ()),
		function (_, node)
			if not self.ChildNodes [node:GetName ()] then return end
			self:UpdateIcon (self.ChildNodes [node:GetName ()])
		end
	)
				
	self.Folder:AddEventListener ("NodeRenamed", tostring (self:GetTable ()),
		function (_, node, oldName, newName)
			self.ChildNodes [newName] = self.ChildNodes [oldName]
			self.ChildNodes [newName]:SetText (node:GetDisplayName ())
			self.ChildNodes [oldName] = nil
			
			self:Sort ()
		end
	)
	
	self.Folder:AddEventListener ("NodeUpdated", tostring (self:GetTable ()),
		function (_, updatedNode, updateFlags)
			local listViewItem = self.ChildNodes [updatedNode:GetName ()]
			if not listViewItem then return end
			if updateFlags & VFS.UpdateFlags.DisplayName ~= 0 then
				listViewItem:SetText (updatedNode:GetDisplayName ())
				self:Sort ()
			end
			if updateFlags & VFS.UpdateFlags.Size ~= 0 then
				listViewItem.Size = updatedNode:IsFile () and updatedNode:GetSize () or -1
				listViewItem:SetColumnText (2, listViewItem.Size ~= -1 and VFS.FormatFileSize (listViewItem.Size) or "")
			end
			if updateFlags & VFS.UpdateFlags.ModificationTime ~= 0 then
				listViewItem.LastModified = updatedNode:GetModificationTime ()
				listViewItem:SetColumnText (3, listViewItem.LastModified ~= -1 and VFS.FormatDate (listViewItem.LastModified) or "")
			end
		end
	)

	local parentFolder = self.Folder
	while parentFolder do
		self.HookedNodes [#self.HookedNodes + 1] = parentFolder
		parentFolder:AddEventListener ("PermissionsChanged", tostring (self:GetTable ()), self.PermissionsChanged)
		parentFolder = parentFolder:GetParentFolder ()
	end
	
	self.LastAccess = self.Folder:GetPermissionBlock ():IsAuthorized (GAuth.GetLocalId (), "View Folder")
end

function self:SetPath (path)
	VFS.Root:GetChild (GAuth.GetLocalId (), path,
		function (returnCode, node)
			if node:IsFolder () then
				self:SetFolder (node)
			else
				self:SetFolder (node:GetParentFolder ())
				self:AddNode (node):Select ()
			end
		end
	)
end

-- Internal, do not call
function self:AddNode (node)
	if self.ChildNodes [node:GetName ()] then return end
	
	local listViewItem = self:AddLine (node:GetName ())
	listViewItem:SetText (node:GetDisplayName ())
	listViewItem.Node = node
	
	listViewItem.IsFolder = node:IsFolder ()
	listViewItem.IsFile = node:IsFile ()
	listViewItem.Size = node:IsFile () and node:GetSize () or -1
	listViewItem.LastModified = node:GetModificationTime ()
	
	self:UpdateIcon (listViewItem)
	
	listViewItem:SetColumnText (2, listViewItem.Size ~= -1 and VFS.FormatFileSize (listViewItem.Size) or "")
	listViewItem:SetColumnText (3, listViewItem.LastModified ~= -1 and VFS.FormatDate (listViewItem.LastModified) or "")
	
	self.ChildNodes [node:GetName ()] = listViewItem
	return listViewItem
end

function self:UpdateIcon (listViewItem)
	local node = listViewItem.Node
	local permissionBlock = node:GetPermissionBlock ()
	local canView = not permissionBlock or permissionBlock:IsAuthorized (GAuth.GetLocalId (), listViewItem.IsFolder and "View Folder" or "Read")
	if listViewItem.IsFolder then
		listViewItem:SetIcon (canView and "gui/g_silkicons/folder" or "gui/g_silkicons/folder_delete")
	else
		listViewItem:SetIcon (canView and "gui/g_silkicons/page" or "gui/g_silkicons/page_delete")
	end
end

-- Event handlers
function self:OnRemoved ()
	self:SetFolder (nil)
end

-- Event handlers
self.PermissionsChanged = VFS.NullCallback

vgui.Register ("VFSFolderListView", self, "GListView")