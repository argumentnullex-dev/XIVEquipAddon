-- Core/Settings.lua
local addon, XIVEquip = ...
XIVEquip = XIVEquip or {}
XIVEquip.Settings = XIVEquip.Settings or {}

local S = XIVEquip.Settings

-- Ensure table + defaults (idempotent; safe to call often)
local function ensure()
  _G.XIVEquip_Settings = _G.XIVEquip_Settings or {}
  local st = _G.XIVEquip_Settings

  -- Debug group
  st.Debug = st.Debug or {
    Enabled = false, -- debug messages OFF by default
    Slot    = nil,   -- nil = all; string/number to filter
  }

  -- Messages group
  st.Messages = st.Messages or {
    Login   = false, -- startup msg OFF by default
    Equip   = false, -- equip/change msg OFF by default
    Preview = true,  -- gear preview ON by default
  }

  -- Automation group
  st.Automation = st.Automation or {
    AutoSpec = false, -- auto equip on spec change OFF
    AutoSets = false, -- auto-save set after ERG OFF
  }

  -- Comparer selection: default Pawn
  if st.SelectedComparer == nil or st.SelectedComparer == "" then
    st.SelectedComparer = "Pawn"
  end

  return st
end

function S:Get() return ensure() end

-- Debug
function S:SetDebugEnabled(val) ensure().Debug.Enabled = not not val end

function S:GetDebugEnabled() return ensure().Debug.Enabled end

function S:SetDebugSlot(slot) ensure().Debug.Slot = slot end

function S:GetDebugSlot() return ensure().Debug.Slot end

-- Messages
function S:SetMessage(flag, val)
  local m = ensure().Messages; m[flag] = not not val
end

function S:GetMessage(flag)
  local m = ensure().Messages; return m and m[flag]
end

-- Automation
function S:SetAutomation(flag, val)
  local a = ensure().Automation; a[flag] = not not val
end

function S:GetAutomation(flag)
  local a = ensure().Automation; return a and a[flag]
end

-- Comparer
function S:SetComparerLabel(label)
  ensure().SelectedComparer = tostring(label or "Pawn")
end

function S:GetComparerLabel()
  return ensure().SelectedComparer or "Pawn"
end
