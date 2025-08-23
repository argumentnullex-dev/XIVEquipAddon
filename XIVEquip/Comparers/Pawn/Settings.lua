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
  -- Debug group: normalize legacy shapes (boolean) to the new table shape
  if type(st.Debug) == "boolean" then
    -- older code stored a boolean directly; convert to table
    st.Debug = {
      Enabled = st.Debug,
      Slot = nil,
    }
  else
    st.Debug = st.Debug or { Enabled = false, Slot = nil }
    -- Ensure fields exist and have safe types
    if type(st.Debug) == "table" then
      st.Debug.Enabled = not not st.Debug.Enabled
      -- leave Slot as-is (may be nil/string/number)
    else
      -- fallback: replace with sensible defaults
      st.Debug = { Enabled = false, Slot = nil }
    end
  end

  -- Mirror legacy globals for logger consumption
  rawset(_G, "XIVEquip_Debug", not not st.Debug.Enabled)
  rawset(_G, "XIVEquip_DebugSlot", st.Debug.Slot)

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
function S:SetDebugEnabled(val)
  local enabled = not not val
  ensure().Debug.Enabled = enabled
  -- mirror to the global Debug flag used by Debugf() so Debugf output can be enabled via commands
  _G.XIVEquip_Debug = enabled
end

function S:GetDebugEnabled() return ensure().Debug.Enabled end

function S:SetDebugSlot(slot)
  ensure().Debug.Slot = slot
  -- mirror to global used by Logger.Debugf
  rawset(_G, "XIVEquip_DebugSlot", slot)
end

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
