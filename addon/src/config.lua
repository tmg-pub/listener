-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- The configuration module.
--
-- In here you'll find the default database table and the main
-- configuration options.
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L    = Main.Locale

local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local SharedMedia     = LibStub("LibSharedMedia-3.0")

--
-- This version number is used for future compatibility. It's saved globally
-- and then the idea is that when the database upgrades or changes in the
-- future, some importing operations can be done on the older data if
-- an older version is recognized.
--
-- As of now it's not used for that and is still VERSION 1.
--
-- Database patches are done within CreateDB, you can see a comment there.
--
local VERSION = 1

-- these tables mirror the sharedmedia list with metamethods
local g_font_list = {}
local g_font_list_tag = {} -- tag is replaced with font list after init

local g_sound_list = {}
local g_sound_list_tag = {}

--[[ wow doesnt have lua 5.2
local smlist_metatable = {
	__index = function( table, key )
		return table.source[key]
	end;
	
	__len = function( table )
		return #table.source
	end;
	
	__pairs = function( table )
		return pairs( table.source )
	end;
	
	__ipairs = function( table )
		return ipairs( table.source )
	end;
}]]

--setmetatable( g_sound_list, smlist_metatable )
--setmetatable( g_font_list, smlist_metatable )


-------------------------------------------------------------------------------
-- These functions are for converting a hex string into a color value.
-- 
-- It accepts a few formats, such as "rgb", "rgba", "rrggbb", or "rrggbbaa"
-- and it's output is { r, g, b } or { r, g, b, a } if using an alpha value.
--
local function ToNumber2( expr )
	return tonumber( expr ) or 0
end

-------------------------------------------------------------------------------
local function Hexc( hex )
	if hex:len() == 3 then
		return {ToNumber2("0x"..hex:sub(1,1))/15, ToNumber2("0x"..hex:sub(2,2))/15, ToNumber2("0x"..hex:sub(3,3))/15}
	elseif hex:len() == 4 then
		return {ToNumber2("0x"..hex:sub(1,1))/15, ToNumber2("0x"..hex:sub(2,2))/15, ToNumber2("0x"..hex:sub(3,3))/15, ToNumber2("0x"..hex:sub(4,4))/15}
	elseif hex:len() == 6 then
		return {ToNumber2("0x"..hex:sub(1,2))/255, ToNumber2("0x"..hex:sub(3,4))/255, ToNumber2("0x"..hex:sub(5,6))/255}
	elseif hex:len() == 8 then
		return {ToNumber2("0x"..hex:sub(1,2))/255, ToNumber2("0x"..hex:sub(3,4))/255, ToNumber2("0x"..hex:sub(5,6))/255, ToNumber2("0x"..hex:sub(7,8))/255}
	end
	return {1, 1, 1}
end

-------------------------------------------------------------------------------
-- A note about frame configuration:
-- Some of the options are stored in the PROFILE while most are stored in CHAR.
-- For the primary frame (index 1), the position settings are stored in the PROFILE.
-- For other frames, they're character based, and are entirely stored in the CHAR.

-------------------------------------------------------------------------------
-- The default structure of the saved data.
--
-- AFAIK whenever you set a value to nil in the database, it will refer to any
-- value found in this table on the next reload.
--
local DB_DEFAULTS = {
	
	---------------------------------------------------------------------------
	-- Global variables (for all characters on all realms).
	--
	global = {
	
		-- See VERSION above.
		version = nil;
		
		-- Help notes that have been acknowledged (see help.lua).
		help    = {};
	};
	
	---------------------------------------------------------------------------
	-- Per-realm variables.
	--
	realm = {
		-- This is a table which maps player names to guids. Index is normal
		-- Name for same-realm or Name-Realm
		guids = {};
	};
	
	---------------------------------------------------------------------------
	-- Per-character variables.
	--
	char = {
	
		-----------------------------------------------------------------------
		-- It's a little messy here, but the gist of it here is that a lot of
		-- the frame variables can be overwritten in here. Some options are 
		-- strictly per-character, while others are profile based with
		-- character overrides.
		--
		-- For the profile based options, the main frame and the snooper frame
		-- (frames 1 and 2) are always using the profile options. Other frames
		-- are per-character and their overrides use per-character options,
		-- here, to save options.
		--
		frames = {
			-------------------------------------------------------------------
			-- Two frames should always be defined in here (after initial setup)
			-- The primary frame [1] and the snooper [2].
			-- [3..x] are custom frames.
			--
			-- Options here that are purely character options are:
			--   players    - The player filter list.
			--   listen_all - The inclusion mode option.
			--   filter     - Chat events that are shown in this frame.
			--                Entries are uppercase event names or channel
			--                names prefixed by #. e.g. "SAY" or "#TEST"
			--   showhidden - Show excluded players as faded instead of hidden.
			--   hidden     - The window is closed.
			--   sound      - The "notify" option. Plays a sound on message.
			--   flash      - Flash the taskbar on message.
			
			--
			-- Some options are split, but they're not overrides. For example
			-- combathide is stored in profile.frame for frame 1, 
			-- profile.snoop for frame 2, and then here, in the per-character
			-- variables for custom frames.
			--   combathide - Hide during combat.
			--   readmark   - Show readmark.
			--   layout     - Window position/size.
			--   locked     - Window cannot be moved.
			--   auto_popup - Open window on new message.
			
			-- As for overrides, see profile.frame, and the options that
			-- can be overriden are noted as such.
		};
		
		-- If DM Tags are enabled.
		dmtags = false;
	};
	
	---------------------------------------------------------------------------
	-- Per-profile variables.
	--
	profile = {
	
		-------------------------------------------------------------
		-- Savedata for the minimap button library.
		--
		minimapicon = {
		
			-- If the button is shown or not.
			hide = false;
		};
		
		-------------------------------------------------------------
		-- Automatically clear the readmark when a message is
		-- posted.
		--
		auto_clear_readmark = true;
		
		-------------------------------------------------------------
		-- Flash the taskbar when a notification is received 
		-- (whenever a sound plays).
		--
		-- replaced with more specific options.
		--flashclient      = true;
		
		-------------------------------------------------------------
		-- Time that needs to pass before another beep is 
		-- made. This is a time of no messages being
		-- received.
		--
		-- In other words, if you keep receiving messages
		-- every 1 second, and the threshold is 3, then
		-- you'll only hear the first beep and then you won't
		-- hear another one until the messages stop coming
		-- for at least 3 seconds.
		--
		beeptime         = 3;
		
		-------------------------------------------------------------
		-- RPConnect is an addon that's meant for cross-realm RP, 
		-- and with this switch the messages that are translated by 
		-- the relay bots will be parsed and then associated with 
		-- the opposite faction player that they're supposed to be 
		-- coming from. In other words, you can select a Horde
		-- player as Alliance and see their messages in the snooper
		-- if they are using raid chat through RPConnect
		--
		-- Currently there's no UI option to turn this off.
		--
		rpconnect        = true;
		
		-------------------------------------------------------------
		-- By default names are shortened, which is a feature in
		-- the names module to try and keep names to a minimum and
		-- maximum length. A name like "Sato Whisperfur" will include
		-- the whole name, since the first name is so short, but
		-- a name like "Rennae Fricke" will only use the first name
		-- since it's longer than four characters.
		--
		shorten_names    = true;
		
		-------------------------------------------------------------
		-- Option to strip titles. There's no UI setting for this
		-- but what it does is causes the names module to cut away
		-- commonly used titles. This is necessary because the
		-- Mary Sue protocol does not have a separate title field
		-- and it'll show as part of the character's name when using
		-- MRP or XRP.
		--
		strip_titles     = true;
		
		-------------------------------------------------------------
		-- This option adds URL detection, and URLs will be turned
		-- into clickable links.
		--
		convert_links    = true;
		
		-------------------------------------------------------------
		-- This option adds NPC emote detection, which is "| "
		-- prefixing an /e message. TRP has this feature to remove
		-- the character's name before the message.
		--
		trp_emotes       = true;
		
		-------------------------------------------------------------
		-- The keywords module adds a chat filter that highlights
		-- certain terms and also makes a notification when they're
		-- found.
		--
		-- Some substitutions are allowed, such as <firstname>,
		-- <lastname>, and <oocname> (all are set by default)
		--
		-- keywords_color is the color they are highlighted with.
		--
		keywords_enable    = true;
		keywords_string    = "<firstname>, <lastname>, <oocname>";
		keywords_color     = Hexc "75F754";
		keywords_flash     = true;
		keywords_sound     = true;
		keywords_soundfile = "ListenerPoke";
		
		---------------------------------------------------------
		-- Play a sound when target emotes. This means that if
		-- you're targeting someone ("target" unit is them), then
		-- a notification will occur whenever you receive a
		-- chat event from them.
		--
		-- This might change to use the snooper filter.
		--
		notify_target_sound = true;
		notify_target_file  = "ListenerBeep";
		notify_target_flash = true;
		
		---------------------------------------------------------
		-- Enable /poke notifications. This is a special sound
		-- whenever someone directs a stock emote at you, such
		-- as /wave, /poke, /hi, etc. It works by looking for
		-- "you" in the message.
		--
		notify_poke_sound   = true;
		notify_poke_file    = "ListenerPoke";
		notify_poke_flash   = true;
		
		-----------------------------------------------------------------------
		-- Profile frame settings. (See note above!)
		frame = {
		
			---------------------------------------------------------
			-- Split option.
			-- Anchor and size. Subframes define their own layout.
			--
			layout = {
				-- anchor contains everything for a SetPoint call.
				-- { point, region, relativePoint, x, y }
				-- region is a string for a frame's name.
				anchor = {};
				
				-- width and height are pixel size.
				width  = 350;
				height = 400;
			};
			
			---------------------------------------------------------
			-- Inherited option.
			--
			-- Otherwise known as History Size, this is the number
			-- of messages that populate the message frame when
			-- refresh chat is called.
			--
			-- For this snooper, this is ideally much less since
			-- it refreshes a lot more often. 
			-- (But it probably doesn't matter).
			--
			start_messages = 120;
			
			---------------------------------------------------------
			-- Split option.
			--
			-- Enable mouse interaction in the window.
			-- If false, user must hold shift.
			--
			enable_mouse = true;
			
			---------------------------------------------------------
			-- Split option. (Currently hidden/snooper only)
			--
			-- Enable scrolling.
			-- If false, user must hold shift.
			--
			enable_scroll = true;
			
			---------------------------------------------------------
			-- Split option.
			--
			-- Show the readmark.
			--
			readmark = true;
			
			---------------------------------------------------------
			-- Split option.
			--
			-- Show the close button.
			--
			close_button = true;
			
			---------------------------------------------------------
			-- Split option.
			--
			-- Hide the frame title bar when the frame is Locked.
			-- Ignores mouseover too.
			--
			hide_bar_when_locked = false;
			
			---------------------------------------------------------
			-- (Split) Sound file for notifications.
			--
			notify_sound = "ListenerBeep";
			
			---------------------------------------------------------
			-- Split option.
			--
			-- Hide during combat.
			--
			combathide = true;
			
			---------------------------------------------------------
			-- Split option.
			--
			-- Window can be dragged.
			--
			locked = false;
			
			---------------------------------------------------------
			-- Global option.
			--
			-- Timestamp format. 
			--  [0] = None
			--  [1] = HH:MM:SS
			--  [2] = HH:MM
			--  [3] = HH:MM (12-hour)
			--  [4] = MM:SS
			--  [5] = MM
			--
			timestamps = 0;
			
			---------------------------------------------------------
			-- Inherited option.
			--
			-- This is the number of seconds of inactivity before 
			-- a window fades down to auto_fade_opacity.
			--
			auto_fade = 0;
			
			---------------------------------------------------------
			-- Split option.
			--
			-- Automatically open window when a new message is
			-- added.
			auto_popup = false;
			
			---------------------------------------------------------
			-- Global option.
			--
			-- Show TRP3 icons if using that addon. Zoom changes
			-- the texture coordinates to cut off the icon borders.
			--
			show_icons = true;
			zoom_icons = true;
			
			---------------------------------------------------------
			-- Global option.
			--
			-- Pixel width of the tabs next to messages, the feature
			-- that has replaced full highlighting.
			--
			tab_size = 2;
			
			---------------------------------------------------------
			-- Global option.
			--
			-- Pixel width of the edges that surround Listener frames.
			--
			edge_size = 2;
			
			---------------------------------------------------------
			-- Global option
			--
			-- Opacity for windows that have faded out due to
			-- inactivity/auto fade duration.
			--
			auto_fade_opacity = 20;
			
			---------------------------------------------------------
			-- Inherited option.
			--
			-- Font style for this frame.
			--
			font = {
				size = 12;              -- Size/height.
				face = "Arial Narrow";  -- Face/family (SharedMedia name).
				outline = 1;            -- 1 = None, 2 = Thin, 3 = Thick.
				shadow = true;          -- Text shadow.
			};
			
			---------------------------------------------------------
			-- Global option.
			--
			-- Font style for the title bars.
			--
			barfont = {
				size = 14;
				face = "Accidental Presidency";
			};
			
			---------------------------------------------------------
			-- Color settings (mixed global/inherited)
			--
			color = {
				-----------------------------------------------------
				-- Inherited options.
				--
				-- The colors of the window.
				--
				bg       = Hexc "090f17ff"; -- Background behind chatbox.
				edge     = Hexc "1F344E80"; -- The border color.
				bar      = Hexc "1F344Eff"; -- The titlebar color.
			
				-----------------------------------------------------
				-- Global option.
				--
				-- The color of the readmark. (default red)
				--
				readmark = Hexc "BF060FC0";
				
				-----------------------------------------------------
				-- Global options.
				--
				-- The tab colors.
				--
				tab_self   = Hexc "29D24EFF"; -- Self/own messages. (default green)
				tab_target = Hexc "BF060FFF"; -- Target messages. (default red)
				tab_marked = Hexc "D3DA37FF"; -- Marked messages. (default yellow)
			};
		};
		
		-------------------------------------------------------------
		-- Snooper settings. The snooper has a bunch of options that
		-- are specific to it, but is otherwise just a normal frame.
		--
		snoop = {
		
			---------------------------------------------------------
			-- Layout struct.
			layout = {
				anchor = {};
				width  = 350;
				height = 400;
			};
			
			---------------------------------------------------------
			-- Inherited options and their default settings for the
			-- snooper.
			--
			locked             = false;
			auto_fade          = 0;
			tab_size           = 0;
			
			-- The snooper gets refreshed a lot so a lower
			-- start_messages value can help performance.
			start_messages     = 50;
			
			font  = {};
			color = {};
			
			enable_mouse       = false;
			enable_scroll      = false;
			
			---------------------------------------------------------
			-- Snooper specific options.
			--
			
			-- Wrap timestamps in square brackets for style.
			timestamp_brackets = true;
			
			-- Enable mouse when holding shift.
			shift_mouse        = true;
			
			-- Color names. (/e messages include the character name.)
			name_colors        = false;
			
			-- don't show for mouseover
			target_only        = false;
		};
		
		-------------------------------------------------------------
		-- Options for the DM Tags module.
		--
		dmtags = {
		
			---------------------------------------------------------
			-- Font for the tags.
			font = {
				size = 12; 
				face = "Accidental Presidency";
			};
		};
	};
}
 
-------------------------------------------------------------------------------
-- Simple helper function to return the key for a unique value in a table.
--
local function FindValueKey( table, value ) 
	for k,v in pairs( table ) do
		if v == value then return k end
	end
end

-------------------------------------------------------------------------------
-- Apply options for all chat.
--
local function FrameSettingsChanged()
	Main.Frame.ApplyGlobalOptions()
	for _, frame in pairs( Main.frames ) do
		frame:ApplyOptions()
	end
end

-------------------------------------------------------------------------------
-- Refresh all windows.
--
local function RefreshAllChat()
	for _, frame in pairs( Main.frames ) do
		frame:RefreshChat()
		frame:UpdateProbe()
	end
end

-------------------------------------------------------------------------------
-- Creates an option to adjust a color. Used for tabs/readmark (global).
--
local function FrameColorOption( order, name, desc, color )
	return {
		order = order;
		name  = name;
		desc  = desc;
		type  = "color";
		hasAlpha = true;
		get   = function( info )
			return unpack( Main.db.profile.frame.color[color] )
		end;
		set   = function( info, r, g, b, a )
			Main.db.profile.frame.color[color] = { r, g, b, a }
			FrameSettingsChanged()
		end;
	}
end

-------------------------------------------------------------------------------
-- The main options table.
--
-- Most of the things in here are fairly self explanatory.
--
Main.config_options = {
	type = "group";
	args = { 
		
		mmicon = {
			name = L["Minimap Icon"];
			desc = L["Hide/Show the minimap icon."];
			type = "toggle";
			set = function( info, val ) Main.MinimapButton.Show( val ) end;
			get = function( info ) return not Main.db.profile.minimapicon.hide end;
		};
		 
		general = {
			name  = L["General"];
			type  = "group";
			order = 1;
			args  = {
			
				--[[
				playsound_target = {
					order = 61;
					name = L["Target Emote Sound"];
					desc = L["Play a sound when your targeted player emotes."];
					type = "toggle";
					set = function( info, val ) Main.db.profile.sound.target = val end;
					get = function( info ) return Main.db.profile.sound.target end;
				};]]
				
				soundthrottle = {
					order = 62;
					name = L["Sound Throttle Time"];
					desc = L["Minimum amount of time between emotes before playing another sound is allowed."];
					type = "range";
					min  = 0.1;
					max  = 120;
					softMax = 10;
					step = 0.1;
					set = function( info, val ) Main.db.profile.beeptime = val end;
					get = function( info ) return Main.db.profile.beeptime end;
				};
--[[				
				playsound2 = {
					order = 63;
					name = L["Poke Sound"];
					desc = L["Play a sound when a person directs a stock emote at you. (e.g. /poke)"];
					type = "toggle";
					set = function( info, val ) Main.db.profile.sound.poke = val end;
					get = function( info ) return Main.db.profile.sound.poke end;
				};
	]]
--[[	
				flash1 = {
					order = 65;
					name = L["Flash Taskbar Icon"];
					desc = L["Flash Taskbar Icon when Listener plays a sound."];
					type = "toggle";
					set = function( info, val ) Main.db.profile.flashclient = val end;
					get = function( info ) return Main.db.profile.flashclient end;
				};
	]]			
				shorten_names = {
					order = 71;
					name = L["Shorten Names"];
					desc = L["Shorten names in chat and other places. Cuts off surnames unless the first name is really short."];
					type = "toggle";
					set = function( info, val )
						LibRPNames.ClearCache()
						Main.db.profile.shorten_names = val
						RefreshAllChat()
						FrameSettingsChanged()
					end;
					get = function( info ) return Main.db.profile.shorten_names end;
				};
				
				links = {
					order = 81;
					name = L["Clickable Links"];
					desc = L["Convert links into clickable items. You might want to disable this if you already have another addon that handles this."];
					type = "toggle";
					set = function( info, val )
						Main.db.profile.convert_links = val
					end;
					get = function( info, val )
						return Main.db.profile.convert_links
					end;
				};
				
				trp_emotes = {
					order = 82;
					name  = L["TRP NPC Emotes"];
					desc  = L["Hide name when an emote is prefixed by |."];
					type  = "toggle";
					set = function( info, val )
						Main.db.profile.trp_emotes = val
						RefreshAllChat()
					end;
					get = function( info )
						return Main.db.profile.trp_emotes
					end;
				};
				
				auto_clear_readmark = {
					order = 83;
					name  = L["Auto-clear Readmark"];
					desc  = L["Automatically clear readmark (new messages line) when you post a message. Otherwise, you have to press the hotkey."];
					type  = "toggle";
					set   = function( info, val )
						Main.db.profile.auto_clear_readmark = val
					end;
					get = function( info )
						return Main.db.profile.auto_clear_readmark
					end;
				};
				
				notify_target = {
					order  = 90;
					name   = L["Target Notification"];
					type   = "group";
					inline = true;
					args = {
						desc = {
							order = 0;
							type = "description";
							name = L["Notification options for when your current target emotes."];
						};
						flash = {
							order = 1;
							type = "toggle";
							name = L["Flash Taskbar"];
							desc = L["Flash the taskbar icon when your current target emotes."];
							set = function( info, val ) Main.db.profile.notify_target_flash = val end;
							get = function( info ) return Main.db.profile.notify_target_flash end;
						};
						sound = {
							order = 2;
							type = "toggle";
							name = L["Play Sound"];
							desc = L["Play a sound when your current target emotes."];
							set = function( info, val ) Main.db.profile.notify_target_sound = val end;
							get = function( info ) return Main.db.profile.notify_target_sound end;
						};
						file = {
							order = 3;
							type = "select";
							name = L["Sound"];
							desc = L["Which sound to play when your target emotes."];
							values = g_sound_list_tag;
							set = function( info, val )
								Main.db.profile.notify_target_file = g_sound_list[val]
								Main.Sound.Play( "messages", 10, g_sound_list[val] )
							end;
							get = function( info )
								return FindValueKey( g_sound_list, Main.db.profile.notify_target_file )
							end;
						};
					}
				};
				
				notify_poke = {
					order  = 91;
					name   = L["Poke Notification"];
					type   = "group";
					inline = true;
					args = {
						desc = {
							order = 0;
							type = "description";
							name = L["Notification options for when a stock emote is directed at you. e.g. /poke, /wave, etc."];
						};
						flash = {
							order = 1;
							type = "toggle";
							name = L["Flash Taskbar"];
							desc = L["Flash the taskbar icon when you're poked."];
							set = function( info, val ) Main.db.profile.notify_poke_flash = val end;
							get = function( info ) return Main.db.profile.notify_poke_flash end;
						};
						sound = {
							order = 2;
							type = "toggle";
							name = L["Play Sound"];
							desc = L["Play a sound when you're poked."];
							set = function( info, val ) Main.db.profile.notify_poke_sound = val end;
							get = function( info ) return Main.db.profile.notify_poke_sound end;
						};
						file = {
							order = 3;
							type = "select";
							name = L["Sound"];
							desc = L["Which sound to play when you're poked."];
							values = g_sound_list_tag;
							set = function( info, val )
								Main.db.profile.notify_poke_file = g_sound_list[val]
								Main.Sound.Play( "messages", 10, g_sound_list[val] )
							end;
							get = function( info )
								return FindValueKey( g_sound_list, Main.db.profile.notify_poke_file )
							end;
						};
					}
				};
				
				keywords = {
					order = 92;
					name  = L["Keywords"];
					type = "group";
					inline = true;
					args = {
						
						keywords_desc = {
							order = 91;
							type  = "description";
							name  = L["The keywords feature highlights things that appear in chat, such as your name. They may also make a notification. Separate keywords with commas. Keywords are not case-sensitive. Some substitutions are available:\n<firstname> - Your character's RP first name.\n<lastname> - Your character's RP last name.\n<oocname> - Your character's in-game name."];
						};
						
						keywords_enable = {
							order = 92;
							type  = "toggle";
							name  = L["Enable Keywords"];
							set = function( info, val )
								Main.db.profile.keywords_enable = val;
							end;
							get = function( info )
								return Main.db.profile.keywords_enable
							end;
						};
						
						keywords_string = {
							order = 93;
							type  = "input";
							width = "full";
							name  = L["Keywords To Highlight"];
							desc  = L["Enter keywords separated by commas."];
							set = function( info, val )
								Main.db.profile.keywords_string = val;
								Main.LoadKeywordsConfig()
							end;
							get = function( info )
								return Main.db.profile.keywords_string
							end;
						};
						
						keywords_color = {
							order    = 94;
							type     = "color";
							name     = L["Highlight Color"];
							desc     = L["The color that keywords will be highlighted with."];
							hasAlpha = false;
							
							set = function( info, r, g, b )
								Main.db.profile.keywords_color = {r,g,b,1.0};
								Main.LoadKeywordsConfig()
							end;
							get = function( info )
								return unpack( Main.db.profile.keywords_color )
							end;
						};
						
						keywords_flash = {
							order = 100;
							type  = "toggle";
							name  = L["Flash Taskbar"];
							desc  = L["Flash the taskbar icon when someone mentions one of your keywords."];
							set = function( info, val )
								Main.db.profile.keywords_flash = val
							end;
							get = function( info )
								return Main.db.profile.keywords_flash
							end;
						};
						
						keywords_sound = {
							order = 101;
							type = "toggle";
							name = L["Play Sound"];
							desc = L["Play a sound when someone mentions one of your keywords."];
							set = function( info, val )
								Main.db.profile.keywords_sound = val
							end;
							get = function( info )
								return Main.db.profile.keywords_sound
							end
						};
						
						keywords_soundfile = {
							order = 102;
							type = "select";
							name = L["Sound"];
							desc = L["Sound to play."];
							values = g_sound_list_tag;
							set = function( info, val )
								Main.db.profile.keywords_soundfile = g_sound_list[val]
								Main.Sound.Play( "messages", 10, g_sound_list[val] )
							end;
							get = function( info )
								return FindValueKey( g_sound_list, Main.db.profile.keywords_soundfile )
							end;
						}
					};
				};
				dmtags = {
					order  = 101;
					name   = L["DM Tags"];
					type   = "group";
					inline = true;
					args   = {
						desc = {
							order = 1;
							type = "description";
							name = L["DM Tags are a feature (that you might not use) which mark your unit frames with the time since a player's last emote. They're toggleable in the minimap menu."];
						};
						fontface = {
							order = 11;
							name  = L["Font"];
							desc  = L["Font for DM tags."];
							type  = "select";
							values = g_font_list_tag;
							set   = function( info, val ) 
								Main.db.profile.dmtags.font.face = g_font_list[val]
								Main.DMTags.LoadConfig()
							end;
							get   = function( info ) 
								return FindValueKey( g_font_list, Main.db.profile.dmtags.font.face ) 
							end;
						};
						size = {
							order = 12;
							name  = L["Size"];
							desc  = L["Font size for DM tags."];
							type  = "range";
							min   = 6;
							max   = 32;
							step  = 1;
							set   = function( info, val )
								Main.db.profile.dmtags.font.size = val;
								Main.DMTags.LoadConfig()
							end;
							get   = function( info )
								return Main.db.profile.dmtags.font.size
							end;
						};
					};
				};
				resethelp = {
					order = 150;
					type= "execute";
					name = L["Reset Help"];
					desc = L["Click to reset the help notes. (Will show on next login.)"];
					func = function() Main:Help_Reset() end;
				};
			};
			
		};
		
		frame = {
			name  = L["Frame"];
			type  = "group";
			order = 2;
			args  = {
				desc1 = {
					name  = L["Global settings. See below for per-frame settings."];
					type  = "description"; 
					order = 9;
				};
				edge_size = {
					order = 20;
					name  = L["Edge Size"];
					desc  = L["Thickness of the border around frames."];
					type  = "range";
					min   = 0;
					max   = 16;
					step  = 1;
					set   = function( info, val )
						Main.db.profile.frame.edge_size = val
						FrameSettingsChanged()
					end;
					get   = function( info )
						return Main.db.profile.frame.edge_size
					end;
				};
				bar_fontface = {
					order = 30;
					name  = L["Header Font"];
					desc  = L["Font face for header above the chatbox."];
					type  = "select";
					values = g_font_list_tag;
					set   = function( info, val ) 
						Main.db.profile.frame.barfont.face = g_font_list[val]
						FrameSettingsChanged()
					end;
					get   = function( info ) 
						return FindValueKey( g_font_list, Main.db.profile.frame.barfont.face ) 
					end;
				};
				bar_font_size = {
					order = 31;
					name  = L["Header Font Size"];
					desc  = L["Font size for header above the chatbox."];
					type  = "range";
					min   = 6;
					max   = 24;
					step  = 1;
					set   = function( info, val )
						Main.db.profile.frame.barfont.size = val
						FrameSettingsChanged()
					end;
					get   = function( info )
						return Main.db.profile.frame.barfont.size
					end;
				};
				timestamp = {
					order = 32;
					name = L["Timestamps"];
					type = "select";
					values = { 
						[0] = "None";
						[1] = "HH:MM:SS";
						[2] = "HH:MM";
						[3] = "HH:MM (12-hour)";
						[4] = "MM:SS";
						[5] = "MM";
					};
					set = function( info, val )
						Main.db.profile.frame.timestamps = val
						RefreshAllChat()
					end;
					get = function( info ) 
						return Main.db.profile.frame.timestamps 
					end;
				};
				readmark_color = FrameColorOption( 40, L["Readmark Color"], L['Color for the line that separates "new" messages. (Set to transparent to disable.)'], "readmark" );
				
				show_icons = {
					order = 60;
					name  = L["Show Icons"];
					desc  = L["If using Total RP 3, show character icons next to names."];
					type  = "toggle";
					get   = function( info )
						return Main.db.profile.frame.show_icons
					end;
					set   = function( info, val )
						Main.db.profile.frame.show_icons = val
						RefreshAllChat()
					end;
				};
				zoom_icons = {
					order = 61;
					name  = L["Zoom Icons"];
					desc  = L["Zoom icons to cut off ugly borders."];
					type  = "toggle";
					get   = function( info )
						return Main.db.profile.frame.zoom_icons
					end;
					set   = function( info, val )
						Main.db.profile.frame.zoom_icons = val
						RefreshAllChat()
					end;
				};
				auto_fade_opacity = {
					order = 70;
					name  = L["Auto-Fade Opacity"];
					desc  = L["Opacity (percent) for windows that fade out due to inactivity."];
					type  = "range";
					min   = 0;
					max   = 100;
					get   = function( info )
						return Main.db.profile.frame.auto_fade_opacity
					end;
					set   = function( info, val )
						Main.db.profile.frame.auto_fade_opacity = val
						for _,f in pairs( Main.frames ) do
							f:ApplyOtherOptions()
						end
					end;
				};
				
				-- tab colors
				group_tab_colors = {
					order  = 80;
					type   = "group";
					name   = L["Tab Colors"];
					inline = true;
					args   = {
						desc1 = {
							order = 1;
							type  = "description";
							name  = L["Colors for the tabs next to messages. To disable anything, just set them to transparent."];
						};
						tab_self   = FrameColorOption( 10, L["Self"], L["The tab that marks your messages."], "tab_self" );
						tab_target = FrameColorOption( 11, L["Target"],	L["The tab that marks your target's messages."], "tab_target" );
						tab_marked = FrameColorOption( 12, L["Marked"],	L["The tab that marks messages that you click!"], "tab_marked" );
					};
				};
			};
		};
		
	};
}
  
-------------------------------------------------------------------------------
-- Create/initialize the database. This is called once at startup.
-- Must be called before accessing Main.db.
--
function Main.CreateDB() 

	local acedb = LibStub( "AceDB-3.0" )
	Main.db = acedb:New( "ListenerAddonSaved", DB_DEFAULTS, true )
	
	-- this might be a bit much, but who cares, reload everything
	-- when the profile is changed.
	Main.db.RegisterCallback( Main, "OnProfileChanged", "ApplyConfig" )
	Main.db.RegisterCallback( Main, "OnProfileCopied",  "ApplyConfig" )
	Main.db.RegisterCallback( Main, "OnProfileReset",   "ApplyConfig" )
	
	-- important note for when the time comes:
	-- database patching should iterate through all profiles as well.
	
	-- insert older database patches here: --
	
	-----------------------------------------
 
	Main.db.global.version = VERSION
end

Main.config_font_list_tag = g_font_list_tag
Main.config_sound_list_tag = g_sound_list_tag

function Main.Config_SearchForSMLists( table )
	for k,v in pairs( table ) do
		if type( v ) == "table" then
			if v == g_font_list_tag then
				table[k] = g_font_list
			elseif v == g_sound_list_tag then
				table[k] = g_sound_list
			else
				Main.Config_SearchForSMLists( v )
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Initialize the configuration panel.
--
local g_init
function Main.InitConfigPanel()
	if g_init then return end
	g_init = true
	
	Main.FrameConfigInit()
	
	local options = Main.config_options
	
	g_font_list = SharedMedia:List( "font" )
	g_sound_list = SharedMedia:List( "sound" )
	Main.config_font_list  = g_font_list
	Main.config_sound_list = g_sound_list
	Main.Config_SearchForSMLists( Main.config_options )
	
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable( Main.db )
	options.args.profile.order = 500
	 
	AceConfig:RegisterOptionsTable( "Listener", options )
end

-------------------------------------------------------------------------------
-- Open the configuration panel, as done through the Settings button
-- in the minimap menu.
--
function Main.OpenConfig( tab )
	Main.InitConfigPanel()	
	AceConfigDialog:Open( "Listener" )
	if tab then 
		AceConfigDialog:SelectGroup( "Listener", tab )
	end
	
	-- hack to fix the scrollbar missing on the first page when you
	-- first open the panel
	Main.Config_NotifyChange()
end

function Main.Config_NotifyChange()
	if not g_init then return end
	LibStub("AceConfigRegistry-3.0"):NotifyChange( "Listener" )
end
 
-------------------------------------------------------------------------------
-- Apply the configuration settings.
--
function Main:ApplyConfig( onload )
	if not Main.db.profile.snoop.initialized then
		Main.db.profile.snoop.initialized = true;
		Main.db.profile.snoop.color = {
			bg   = Hexc "00000030";
			edge = Hexc "00000020";
			bar  = Hexc "00000040";
		}
	end
	FrameSettingsChanged()
	Main.DMTags.LoadConfig()
	Main.Snoop2.LoadConfig()
	
	-- any other configuration loading things should go in here.
end
 