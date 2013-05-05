--[[
	Shine AFK kick plugin.
]]

local Shine = Shine

local Notify = Shared.Message
local Encode, Decode = json.encode, json.decode

local Plugin = {}
Plugin.Version = "1.0"

Plugin.HasConfig = true
Plugin.ConfigName = "AFKKick.json"

Plugin.Users = {}

function Plugin:Initialise()
	self.Enabled = true

	return true
end

function Plugin:GenerateDefaultConfig( Save )
	self.Config = {
		MinPlayers = 10,
		Delay = 1,
		WarnTime = 5,
		KickTime = 15,
		Warn = true
	}

	if Save then
		local Success, Err = Shine.SaveJSONFile( self.Config, Shine.Config.ExtensionDir..self.ConfigName )

		if not Success then
			Notify( "Error writing afkkick config file: "..Err )	

			return	
		end

		Notify( "Shine afkkick config file created." )
	end
end

function Plugin:SaveConfig()
	local Success, Err = Shine.SaveJSONFile( self.Config, Shine.Config.ExtensionDir..self.ConfigName )

	if not Success then
		Notify( "Error writing afkkick config file: "..Err )	

		return	
	end

	Notify( "Shine afkkick config file saved." )
end

function Plugin:LoadConfig()
	local PluginConfig = Shine.LoadJSONFile( Shine.Config.ExtensionDir..self.ConfigName )

	if not PluginConfig then
		self:GenerateDefaultConfig( true )

		return
	end

	self.Config = PluginConfig
end

--[[
	On client connect, add the client to our table of clients.
]]
function Plugin:ClientConnect( Client )
	if not Client then return end

	if Client:GetIsVirtual() then return end

	local Player = Client:GetControllingPlayer()

	if not Player then return end

	self.Users[ Client ] = {
		LastMove = Shared.GetTime() + ( self.Config.Delay * 60 ),
		Pos = Player:GetOrigin(),
		Ang = Player:GetViewAngles()
	}
end

--[[
	Hook into movement processing to help prevent false positive AFK kicking.
]]
function Plugin:OnProcessMove( Player, Input )
	local Players = Shared.GetEntitiesWithClassname( "Player" ):GetSize()

	if Players < self.Config.MinPlayers then return end

	local Client = Server.GetOwner( Player )

	if not Client then return end

	if Client:GetIsVirtual() then return end
	if Shine:HasAccess( Client, "sh_afk" ) then return end --Immunity.

	local DataTable = self.Users[ Client ]

	if not DataTable then return end

	local Move = Input.move

	local Time = Shared.GetTime()

	local Pitch, Yaw = Input.pitch, Input.yaw

	if not ( Move.x == 0 and Move.y == 0 and Move.z == 0 and Input.commands == 0 and DataTable.LastYaw == Yaw and DataTable.LastPitch == Pitch ) then
		DataTable.LastMove = Time

		if DataTable.Warn then
			DataTable.Warn = false
		end
	end

	DataTable.LastPitch = Pitch
	DataTable.LastYaw = Yaw

	local KickTime = self.Config.KickTime * 60

	if not DataTable.Warn and self.Config.Warn then
		local WarnTime = self.Config.WarnTime * 60

		if DataTable.LastMove + WarnTime < Time then
			DataTable.Warn = true

			local AFKTime = Time - DataTable.LastMove
			
			Server.SendNetworkMessage( Client, "AFKWarning", { timeAFK = AFKTime, maxAFKTime = KickTime }, true )

			return
		end

		return
	end

	if DataTable.LastMove + KickTime < Time then
		self:ClientDisconnect( Client ) --Failsafe.

		Shine:Print( "Client %s[%s] was AFK for over %s. Kicking...", true, Player:GetName(), Client:GetUserId(), string.TimeToString( KickTime ) )

		Server.DisconnectClient( Client )
	end
end

--[[
	When a client disconnects, remove them from the player list.
]]
function Plugin:ClientDisconnect( Client )
	if self.Users[ Client ] then
		self.Users[ Client ] = nil
	end
end

function Plugin:Cleanup()
	for k, v in pairs( self.Users ) do
		self.Users[ k ] = nil
	end

	self.Enabled = false
end

Shine:RegisterExtension( "afkkick", Plugin )
