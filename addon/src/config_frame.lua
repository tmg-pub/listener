-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This is for the configuration panel per-frame, when you open the frame
-- menu and click settings.
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L    = Main.Locale

local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local SharedMedia     = LibStub("LibSharedMedia-3.0")

-------------------------------------------------------------------------------
-- Values for the anchor settings in Layout.
--
local ANCHOR_VALUES = {
	TOPLEFT     = "Top Left";
	TOP         = "Top";
	TOPRIGHT    = "Top Right";
	LEFT        = "Left";
	CENTER      = "Center";
	RIGHT       = "Right";
	BOTTOMLEFT  = "Bottom Left";
	BOTTOM      = "Bottom";
	BOTTOMRIGHT = "Bottom Right";
};

-------------------------------------------------------------------------------
-- Helper function for the font list; returns the key for a valu.
--
local function FindValueKey( table, value ) 
	for k,v in pairs( table ) do
		if v == value then return k end
	end
end

-------------------------------------------------------------------------------
-- Values for the font outline options.
--
local OUTLINE_VALUES = { "None", "Thin Outline", "Thick Outline" }

local function FrameIndexValues()
	local values = {
		"Main",
		"Snooper",
	}
	
	for k, v in pairs( Main.frames ) do
		if k > 2 then
			values[k] = v.charopts.name
		end
	end
	return values
end

-------------------------------------------------------------------------------
-- Okay, now an important thing to consider for most of this program is that
-- the configuration frame operates on only one frame at a time.
--
-- This value here points to that frame, and can be used as a shortcut.
--
local g_frame  -- the current frame

-------------------------------------------------------------------------------
-- And this value is true if g_frame.frame_index == 1, i.e. g_frame is "Main".
--
local g_main

-------------------------------------------------------------------------------
-- This little helper function applies options to frames.
-- If it's the main frame, then all frames are updated, since other custom
-- frames may inherit options from the main frame.
--
local function ApplyOptionsAllIfMain()
	if g_main then
		for _, frame in pairs( Main.frames ) do
			frame:ApplyOptions()
		end
	else
		g_frame:ApplyOptions()
	end	
end

-------------------------------------------------------------------------------
-- Validate if an anchor name exists.
-- Currently this isn't used, since sometimes you might enter an invalid
-- name that will become a real frame later.
--
local function ValidateAnchorName( info, val )
	return true
end

-------------------------------------------------------------------------------
-- And here, a simple validator to make sure that something is a number.
-- They can even enter hexcodes if they're nuts. (But they'll probably be
-- converted to decimal right after.)
--
local function ValidateNumber( info, val )
	local a = tonumber(val)
	if not a then
		return "Value must be a number."
	end
	return true
end

-------------------------------------------------------------------------------
-- This creates a color option block, to be assigned directly to an
-- entry in the options table.
--
-- @param order The value for the 'order' key, i.e. where in the options it
--              will appear.
-- @param name  The name of the option. This argument should be localized
--              before passing it.
-- @param desc  The tooltip for this option. This should also be localized.
-- @param color The entry in the color block in the database that this option
--              will control, e.g. "edge".
--
local function ColorOption( order, name, desc, color )	
	return {
		order    = order;
		name     = name;
		desc     = desc;
		type     = "color";
		hasAlpha = true;
		
		get = function( info )
			local col = g_frame.frameopts.color[color] or g_frame.baseopts.color[color]
			return unpack( col )
		end;
		
		set = function( info, r, g, b, a )
			g_frame.frameopts.color[color] = { r, g, b, a }
			
			if g_main then
				for _, frame in pairs( Main.frames ) do
					frame:ApplyColorOptions()
				end
			else
				g_frame:ApplyColorOptions()
			end
		end;
	}
end

-------------------------------------------------------------------------------
-- Functions for the "hidden" key on some settings.
--
-- Hide if it's the main frame being configured.
--
local function HideMain()
	return g_main
end

-- Hide when it's not the snooper being configured
local function HideNotSnooper()
	return g_frame.frame_index ~= 2
end

-- Hide when configuring the snooper
local function HideSnooper()
	return g_frame.frame_index == 2
end

-------------------------------------------------------------------------------
-- And here we have the Ace3 options table.
--
local OPTIONS = {
	order  = 90;
	name   = L["Per-Frame Settings"];
	type   = "group";
	inline = true;
	args   = {
		frame = {
			order = 1;
			type   = "select";
			name   = L["Frame"];
			desc   = L["Which frame to adjust settings for."];
			values = FrameIndexValues;
			set = function( info, val )
				Main.FrameConfig_SetFrame( Main.frames[val] )
			end;
			get = function( info )
				return g_frame.frame_index
			end;
		};
		font = {
			order  = 9;
			type   = "group";
			name   = L["Font"];
			inline = true;
			args   = {
--[[				desc1 = {
					order = 0;
					type = "description";
					name = L["Tip: Font size can be adjusted easily by holding Ctrl and then scrolling the window."];
				};]]
				face = {
					order = 1;
					name  = L["Font Face"];
					type  = "select";
					values = Main.config_font_list_tag;
					set = function( info, val )
						g_frame.frameopts.font.face = Main.config_font_list[val]
						ApplyOptionsAllIfMain()
					end;
					get = function( info )
						return FindValueKey( Main.config_font_list, g_frame.frameopts.font.face or g_frame.baseopts.font.face )
					end;
				};
				size = {
					order = 2;
					name  = L["Size"];
					desc  = L["Font size. Can be adjusted easily by holding Ctrl and scrolling the mouse on the window."];
					type  = "range";
					min   = 6;
					max   = 24;
					step  = 1;
					set   = function( info, val )
						g_frame.frameopts.font.size = val
						ApplyOptionsAllIfMain()
					end;
					get = function( info, val )
						return g_frame.frameopts.font.size or g_frame.baseopts.font.size
					end;
				};
				outline = {
					order = 3;
					name  = L["Outline"];
					desc  = L["Thickness of outline around font."];
					type = "select";
					values = OUTLINE_VALUES;
					set = function( info, val )
						g_frame.frameopts.font.outline = val
						ApplyOptionsAllIfMain()
					end;
					get = function( info )
						return g_frame.frameopts.font.outline or g_frame.baseopts.font.outline
					end;
				};
				shadow = {
					order = 4;
					name  = L["Shadow"];
					desc  = L["Enable shadow behind text."];
					type  = "toggle";
					set = function( info, val )
						g_frame.frameopts.font.shadow = val
						ApplyOptionsAllIfMain()
					end;
					get = function( info )
						local s = g_frame.frameopts.font.shadow
						if s == nil then s = g_frame.baseopts.font.shadow end
						return s
					end;
				};
				reset = {
					order  = 5;
					name   = L["Inherit From Main"];
					desc   = L["Copy the font that the main window uses."];
					type   = "execute";
					hidden = HideMain;
					func = function()
						if g_main then error( "Internal error." ) end
						g_frame.frameopts.font = {}
						g_frame:ApplyOptions()
					end
				};
			};
		};
		color = { 
			order  = 10;
			type   = "group";
			name   = L["Color"];
			inline = true;
			args = {
				bg_color   = ColorOption( 10, L["Background Color"], nil, "bg" );
				edge_color = ColorOption( 11, L["Edge Color"], nil, "edge" );
				bar_color  = ColorOption( 12, L["Bar Color"], nil, "bar" );
				sep1 = {
					order = 13;
					type = "description";
					name = "";
				};
				easycolor = {
					order = 20;
					name = L["Easy Color"];
					desc = L["Set background and edge color according to title bar color."];
					type = "execute";
					func = function()
						local base = g_frame.frameopts.color.bar or g_frame.baseopts.color.bar
						if not g_frame.frameopts.color.bg then
							g_frame.frameopts.color.bg = { 0, 0, 0, g_frame.baseopts.color.bg[4] }
						end
						if not g_frame.frameopts.color.edge then
							g_frame.frameopts.color.edge = { 0, 0, 0, g_frame.baseopts.color.edge[4] }
						end
						
						g_frame.frameopts.color.bg[1] = base[1] * 0.2
						g_frame.frameopts.color.bg[2] = base[2] * 0.2
						g_frame.frameopts.color.bg[3] = base[3] * 0.2
						
						g_frame.frameopts.color.edge[1] = base[1]
						g_frame.frameopts.color.edge[2] = base[2]
						g_frame.frameopts.color.edge[3] = base[3]
						
						if g_main then
							-- apply to all, because some might inherit.
							for _, frame in pairs( Main.frames ) do
								frame:ApplyColorOptions()
							end
						else
							g_frame:ApplyColorOptions()
						end
					end;
				};
				reset = {
					order  = 21;
					name   = L["Inherit From Main"];
					desc   = L["Copy the colors that the main window uses."];
					type   = "execute";
					hidden = HideMain;
					func = function()
						if g_main then error( "Internal error." ) end
						g_frame.frameopts.color = {}
						g_frame:ApplyColorOptions()
					end
				};
			};
		};
		notify_sound = {
			order = 19;
			name = L["Notify Sound"];
			desc = L["Sound to play when notifications occur."];
			type = "select";
			values = Main.config_sound_list_tag;
			set = function( info, val )
				g_frame.frameopts.notify_sound = Main.config_sound_list[val]
			end;
			get = function( info )
				return FindValueKey( Main.config_sound_list, g_frame.frameopts.notify_sound or g_frame.baseopts.notify_sound )
			end;
		};
		hidecombat = {
			order = 20;
			name = L["Hide During Combat"];
			desc = L["Hide this window during combat."];
			type = "toggle";
			set = function( info, val ) g_frame.frameopts.combathide = val end;
			get = function( info ) return g_frame.frameopts.combathide end;
		};
		close_button = {
			order = 21;
			name = L["Close Button"];
			desc = L["Show the X button that closes the window."];
			type = "toggle";
			set = function( info, val ) 
				g_frame.frameopts.close_button = val 
				ApplyOptionsAllIfMain()
			end;
			get = function( info ) 
				local s = g_frame.frameopts.close_button
				if s == nil then s = g_frame.baseopts.close_button end
				return s
			end;
		};
		hideempty = {
			order = 21;
			name = L["Hide When Empty"];
			desc = L["Hide the window when there is nothing being shown."];
			type = "toggle";
			hidden = HideNotSnooper;
			set = function( info, val ) 
				g_frame.frameopts.hideempty = val
			end;
			get = function( info ) return g_frame.frameopts.hideempty end
		};
		target_only = {
			order = 22;
			name = L["Target Only"];
			desc = L["Don't show snooper on mouseover."];
			type = "toggle";
			hidden = HideNotSnooper;
			set = function( info, val )
				g_frame.frameopts.target_only = val
			end;
			get = function( info )
				return g_frame.frameopts.target_only
			end;
		};
		timestamp_brackets = {
			order = 22;
			name  = L["Timestamp Brackets"];
			desc  = L["Surround timestamps in brackets."];
			type  = "toggle";
			hidden = HideNotSnooper;
			set = function( info, val )
				g_frame.frameopts.timestamp_brackets = val
				g_frame:RefreshChat()
			end;
			get = function( info ) return g_frame.frameopts.timestamp_brackets end;
		};
		name_colors = {
			order = 23;
			name  = L["Name Colors"];
			desc  = L["Use TRP3 or class colors to color names."];
			type  = "toggle";
			hidden = HideNotSnooper;
			set = function( info, val )
				g_frame.frameopts.name_colors = val
				g_frame:RefreshChat()
			end;
			get = function( info ) return g_frame.frameopts.name_colors end;
		};
		shift_mouse = {
			order = 24;
			name  = L["Shift for Mouse"];
			desc  = L["Enables mouse clicking and scrolling when holding shift, even when they're disabled via the menu."];
			type  = "toggle";
			set = function( info, val )
				g_frame.frameopts.shift_mouse = val;
			end;
			get = function( info )
				return g_frame.frameopts.shift_mouse
			end;
		};
		tabsize = {
			order = 30;
			name  = L["Tab Size"];
			desc  = L["Size of the marker tabs to the left of the messages."];
			type  = "range";
			min   = 0;
			max   = 16;
			step  = 1;
			set   = function( info, val )
				g_frame.frameopts.tab_size = val
				ApplyOptionsAllIfMain()
			end;
			get   = function( info )
				return g_frame.frameopts.tab_size or g_frame.baseopts.tab_size
			end;
		};
		auto_fade = {
			order = 40;
			name  = L["Auto-fade time."];
			desc  = L["Time from inactivity before window fades down. 0 disables fading."];
			type  = "range";
			min   = 0;
			max   = 600;
			step  = 1;
			hidden = HideSnooper;
			set = function( info, val )
				g_frame.frameopts.auto_fade = val
				ApplyOptionsAllIfMain()
			end;
			
			get = function( info, val )
				return g_frame.frameopts.auto_fade or g_frame.baseopts.auto_fade
			end;
		};
		
		readmark = {
			order = 50;
			name  = L["Readmark"];
			desc  = L["The readmark is the line that separates new messages and old messages."];
			type  = "toggle";
			hidden = HideSnooper;
			set   = function( info, val )
				g_frame.frameopts.readmark = val
				g_frame:ApplyOptions()
			end;
			get   = function( info )
				return g_frame.frameopts.readmark
			end;
		};
		
		history_size = {
			order = 51;
			name  = L["History Size"];
			desc  = L["Number of messages that will be shown in the window when the chat is refreshed. Larger numbers may cause the game to pause when the chatboxes are refreshed (i.e. when you adjust filters and such)."];
			type  = "range";
			min   = 10;
			max   = 300;
			step  = 1;
			set = function( info, val )
				g_frame.frameopts.start_messages = val
			end;
			get = function( info )
				return g_frame.frameopts.start_messages
			end;
		};
		
		hide_bar_when_locked = {
			order = 52;
			name  = L["Hide Locked Bar"];
			desc  = L["If the frame is locked, don't show the top bar on mouseover."];
			type  = "toggle";
			set   = function( info, val )
				g_frame.frameopts.hide_bar_when_locked = val
			end;
			get   = function( info )
				return g_frame.frameopts.hide_bar_when_locked
			end;
		};
		
		-- layout settings
		layout = {
			order = 91;
			name = L["Layout"];
			type = "group";
			inline = true;
			args = {
		--[[		desc1 = {
					order  = 9;
					type   = "description";
					name   = L["Tip: Listener frames can easily be resized by holding SHIFT."];
				};]]
				anchor_from = {
					order  = 10;
					name   = L["Anchor From"];
					desc   = L["Point on the frame to anchor from."];
					type   = "select";
					values = ANCHOR_VALUES;
					get = function( info ) 
						return g_frame.frameopts.layout.anchor[1]
					end;
					set = function( info, val ) 
						g_frame.frameopts.layout.anchor[1] = val
						g_frame:ApplyLayoutOptions()
					end;
				};
				
				anchor_to = {
					order  = 11;
					name   = L["Anchor To"];
					desc   = L["Point on the anchor frame to attach to."];
					type   = "select";
					values = ANCHOR_VALUES;
					get = function( info ) 
						return g_frame.frameopts.layout.anchor[3]
					end;
					set = function( info, val ) 
						g_frame.frameopts.layout.anchor[3] = val
						g_frame:ApplyLayoutOptions()
					end;
				};
				
				anchor_name = {
					order = 12;
					name  = L["Anchor Region"];
					desc  = L["Name of frame to anchor to. Leave blank to anchor to screen. Use /fstack to find frame names."];
					type  = "input";
					validate = ValidateAnchorName;
					get = function( info )
						return g_frame.frameopts.layout.anchor[2] or ""
					end;
					set = function( info, val )
						if val == "" then
							g_frame.frameopts.layout.anchor[2] = nil
						else
							g_frame.frameopts.layout.anchor[2] = val
						end
						g_frame:ApplyLayoutOptions()
					end;
				};
				
				separator2 = {
					order = 13;
					type  = "description";
					name  = "";
				};
				anchor_x = {
					order = 20;
					name  = L["X"];
					desc  = L["Horizontal offset."];
					type  = "input";
					width = "half";
					validate = ValidateNumber;
					get = function( info )
						return tostring( g_frame.frameopts.layout.anchor[4] )
					end;
					set = function( info, val )
						g_frame.frameopts.layout.anchor[4] = tonumber(val)
						g_frame:ApplyLayoutOptions()
					end;
				};
				
				anchor_y = {
					order = 21;
					name  = L["Y"];
					desc  = L["Vertical offset."];
					type  = "input";
					width = "half";
					validate = ValidateNumber;
					get = function( info )
						return tostring( g_frame.frameopts.layout.anchor[5] )
					end;
					set = function( info, val )
						g_frame.frameopts.layout.anchor[5] = tonumber(val)
						g_frame:ApplyLayoutOptions()
					end;
				};
				
				width = {
					order = 30;
					name  = L["Width"];
					desc  = L["Width of frame."];
					type  = "input";
					width = "half";
					validate = ValidateNumber;
					get = function( info )
						return tostring( g_frame.frameopts.layout.width )
					end;
					set = function( info, val )
						g_frame.frameopts.layout.width = tonumber(val)
						g_frame:ApplyLayoutOptions()
					end;
				};
				
				height = {
					order = 31;
					name  = L["Height"];
					desc  = L["Height of frame."];
					type  = "input";
					width = "half";
					validate = ValidateNumber;
					get = function( info )
						return tostring( g_frame.frameopts.layout.height )
					end;
					set = function( info, val )
						g_frame.frameopts.layout.height = tonumber(val)
						g_frame:ApplyLayoutOptions()
					end;
				};
			};
		};
	};
}

Main.config_options.args.frame.args.perframe = OPTIONS

-------------------------------------------------------------------------------
-- This is for hiding options for certain frame types.
-- Anything listed in these blocks will be hidden via the "hidden" key.
--
local hidden_opts = {
	---------------------------------------------------------------------------
	-- Options listed in this block will be hidden when configuring the main
	-- window. (Frame #1)
	main = {
--		OPTIONS.args.color.args.reset;
--		OPTIONS.args.font.args.reset;
--		OPTIONS.args.timestamp_brackets;
--		OPTIONS.args.hideempty;
--		OPTIONS.args.name_colors;
	};
	
	---------------------------------------------------------------------------
	-- Options listed in this block will be hidden when configuring the snooper
	-- window. (Frame #2)
	snooper = {
	
		-- Snooper doesn't have support auto_fade.
	--	OPTIONS.args.auto_fade;
		
		-- Readmark doesn't make sense in the snooper.
	--	OPTIONS.args.readmark;
	};
	
	---------------------------------------------------------------------------
	-- Options listed in this block will be hidden when configuring custom
	-- frames. (Frame #3+)
	other = {
--		OPTIONS.args.timestamp_brackets;
--		OPTIONS.args.hideempty;
--		OPTIONS.args.name_colors;
	};
}

-------------------------------------------------------------------------------
-- Resets the "hidden" values and then sets them according to the table above.
--
-- @param name "main", "snooper" or "other"
--
local function HideOptions( name )
	for _, v in pairs( hidden_opts ) do
		for _, v2 in pairs( v ) do
			v2.hidden = nil
		end
	end
	
	for _, v in pairs( hidden_opts[name] ) do
		v.hidden = true
	end
end


function Main.FrameConfigInit()
	g_frame = Main.frames[1]
	g_main  = true
end

-------------------------------------------------------------------------------
-- Open the configuration panel for a frame.
--
local g_init
function Main.OpenFrameConfig( frame )
	Main.InitConfigPanel()
	--[[
	if not g_init then
		g_init = true
		AceConfig:RegisterOptionsTable( "Listener Frame Settings", OPTIONS )
		Main.Config_SearchForSMLists( OPTIONS )
	end
	
	if frame.frame_index == 1 then
		HideOptions( "main" )
	elseif frame.frame_index == 2 then
		HideOptions( "snooper" )
	else
		HideOptions( "other" )
	end
	
	g_frame = frame
	g_main  = frame.frame_index == 1
	AceConfigDialog:SetDefaultSize( "Listener Frame Settings", 420, 400 )
	AceConfigDialog:Open( "Listener Frame Settings" )
	LibStub("AceConfigRegistry-3.0"):NotifyChange( "Listener Frame Settings" )]]
end

function Main.FrameConfig_Open( frame )
	Main.InitConfigPanel()
	
	Main.FrameConfig_SetFrame( frame )
	Main.OpenConfig( "frame" )
end

function Main.FrameConfig_GetFrame()
	return g_frame
end

function Main.FrameConfig_SetFrame( frame )
	if frame == nil then frame = Main.frames[1] end
	
	g_frame = frame
	g_main  = frame.frame_index == 1
end
