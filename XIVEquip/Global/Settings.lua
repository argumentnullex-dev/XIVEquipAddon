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
function S:SetDebugEnabled(val) ensure().Debug = (val == true) end

function S:GetDebugEnabled() return ensure().Debug == true end

function S:SetDebugSlot(val) ensure().DebugSlot = val end

function S:GetDebugSlot() return ensure().DebugSlot end

function S:SetMessage(flag, val) ensure().Messages[flag] = (val == true) end

function S:GetMessage(flag) return ensure().Messages[flag] == true end

function S:SetAutomation(flag, val) ensure().Automation[flag] = (val == true) end

function S:GetAutomation(flag) return ensure().Automation[flag] == true end

function S:SetComparerName(name) ensure().SelectedComparer = name end

function S:GetComparerName() return ensure().SelectedComparer end
