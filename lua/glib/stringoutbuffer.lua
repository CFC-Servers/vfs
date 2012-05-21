local self = {}
GLib.StringOutBuffer = GLib.MakeConstructor (self)

function self:ctor ()
	self.Data = ""
end

function self:GetString ()
	return self.Data
end

function self:UInt8 (n)
	self.Data = self.Data .. string.char (n)
end

function self:UInt16 (n)
	self.Data = self.Data .. string.char (n % 256)
	self.Data = self.Data .. string.char (math.floor (n / 256))
end

function self:UInt32 (n)
	self.Data = self.Data .. string.char (n % 256)
	self.Data = self.Data .. string.char (math.floor (n / 256) % 256)
	self.Data = self.Data .. string.char (math.floor (n / 65536) % 256)
	self.Data = self.Data .. string.char (math.floor (n / 16777216) % 256)
end

function self:UInt64 (n)
	self.Data = self.Data .. string.char (n % 256)
	self.Data = self.Data .. string.char (math.floor (n / 256) % 256)
	self.Data = self.Data .. string.char (math.floor (n / 65536) % 256)
	self.Data = self.Data .. string.char (math.floor (n / 16777216) % 256)
	self.Data = self.Data .. string.char (math.floor (n / 4294967296) % 256)
	self.Data = self.Data .. string.char (math.floor (n / 1099511627776) % 256)
	self.Data = self.Data .. string.char (math.floor (n / 281474976710656) % 256)
	self.Data = self.Data .. string.char (math.floor (n / 72057594037927936) % 256)
end

function self:Int8 (n)
	if n < 0 then n = n + 256 end
	self:UInt8 (n)
end

function self:Int16 (n)
	if n < 0 then n = n + 65536 end
	self:UInt16 (n)
end

function self:Int32 (n)
	if n < 0 then n = n + 4294967296 end
	self:UInt32 (n)
end

function self:Int64 (n)
	self:UInt32 (n % 4294967296)
	self:Int32 (math.floor (n / 4294967296))
end

function self:Char (char)
	self.Data = self.Data .. char:sub (1, 1)
end

function self:String (data)
	self:UInt16 (data:len ())
	self.Data = self.Data .. data
end

function self:Boolean (b)
	self:UInt8 (b and 1 or 0)
end