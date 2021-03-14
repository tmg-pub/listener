-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2018)
--
-- The sound API. This handles queuing and managing sound priorities.
-------------------------------------------------------------------------------

local Main        = ListenerAddon
local L           = Main.Locale
local SharedMedia = LibStub("LibSharedMedia-3.0")

Main.Sound = {
	channels = {}
}
local Me = Main.Sound

-------------------------------------------------------------------------------
local function InitChannel( channel )
	Main.Sound.channels[channel] = {
		queued = false;
		priority = -1;
		sound = nil;
	}
end

InitChannel( "messages" )

-------------------------------------------------------------------------------
local function FireChannel( channel )
	local ch = Me.channels[channel]
	ch.queued = false
	ch.priority = -1
	
	local ch = Me.channels[channel]
	local file = SharedMedia:Fetch( "sound", ch.sound )
	PlaySoundFile( file, "Master" )
end

-------------------------------------------------------------------------------
-- Play a sound.
--
-- @param channel Name of channel to play on. Higher priority sounds will
--                 cancel lower priority sounds played on the same channel
--                 at the same time.
-- @param priority How important this sound is. Higher numbers cancel lower
--                  numbers. Must be >= 0.
-- @param sound Sound to play. SharedMedia index.
--
function Me.Play( channel, priority, sound )

	local ch = Me.channels[channel]
	if not ch then return end
	if priority <= ch.priority then return end
	
	ch.sound = sound
	ch.priority = priority
	if not ch.queued then
		ch.queued = true
		C_Timer.After( 0.01, function() FireChannel( channel) end )
	end
end
