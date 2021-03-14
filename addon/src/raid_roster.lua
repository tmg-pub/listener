-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- Here's a simple module for resolving raid group numbers from player names.
-------------------------------------------------------------------------------

local Main = ListenerAddon

--
-- raid_groups[name] = group number
--
Main.raid_groups = {}

-------------------------------------------------------------------------------
-- Rebuild the raid_groups map.
--
function Main.UpdateRaidRoster()
	Main.raid_groups = {}
	if not IsInRaid() then return end
	
	for i = 1, GetNumGroupMembers() do
		local name, _, subgroup = GetRaidRosterInfo(i)
		if not name then return end
		Main.raid_groups[name] = subgroup
	end
end
