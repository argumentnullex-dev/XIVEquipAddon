-- Global/Settings.lua
local addonName, XIVEquip = ...
XIVEquip = XIVEquip or _G.XIVEquip or {}
XIVEquip.Settings = XIVEquip.Settings or {}

local S = XIVEquip.Settings

-- Ensure saved variables exist + seed defaults
local function ensure()
	_G.XIVEquip_Settings = _G.XIVEquip_Settings or {}
	local st = _G.XIVEquip_Settings

	-- Defaults you requested
	if st.Debug == nil then st.Debug = false end    -- debug disabled
	if st.DebugSlot == nil then st.DebugSlot = nil end -- no slot filter

	st.Messages         = st.Messages or { Login = false, Equip = false, Preview = true }
	st.Automation       = st.Automation or { AutoSpec = false, AutoSets = false }
	st.SelectedComparer = st.SelectedComparer or "Pawn" -- default to Pawn
	return st
end

-- Public API (used by commands / UI / logger)
-- [XIVEquip-AUTO] S:SetDebugEnabled: Emits addon debug output when debugging is enabled.
function S:SetDebugEnabled(val) ensure().Debug = (val == true) end

-- S:GetDebugEnabled: Shared utility: get debug enabled.
function S:GetDebugEnabled() return ensure().Debug == true end

-- S:SetDebugSlot: Shared utility: set debug slot.
function S:SetDebugSlot(val) ensure().DebugSlot = val end

-- S:GetDebugSlot: Shared utility: get debug slot.
function S:GetDebugSlot() return ensure().DebugSlot end

-- S:SetMessage: Shared utility: set message.
function S:SetMessage(flag, val) ensure().Messages[flag] = (val == true) end

-- S:GetMessage: Shared utility: get message.
function S:GetMessage(flag) return ensure().Messages[flag] == true end

-- S:SetAutomation: Shared utility: set automation.
function S:SetAutomation(flag, val) ensure().Automation[flag] = (val == true) end

-- S:GetAutomation: Shared utility: get automation.
function S:GetAutomation(flag) return ensure().Automation[flag] == true end

-- S:SetComparerName: Shared utility: set comparer name.
function S:SetComparerName(name) ensure().SelectedComparer = name end

-- S:GetComparerName: Shared utility: get comparer name.
function S:GetComparerName() return ensure().SelectedComparer end
