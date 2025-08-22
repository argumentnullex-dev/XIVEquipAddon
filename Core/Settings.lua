-- Core/Settings.lua
local addon, XIVEquip = ...
XIVEquip = XIVEquip or {}
XIVEquip.Settings = XIVEquip.Settings or {}

local S = XIVEquip.Settings

-- Internal helper to guarantee table + defaults
local function ensure()
  _G.XIVEquip_Settings = _G.XIVEquip_Settings or {}
  local st = _G.XIVEquip_Settings

  st.Messages   = st.Messages   or { Login=true, Equip=true }
  st.Automation = st.Automation or { AutoSpec=false, AutoSets=false }

  return st
end

-- Public accessor: always returns table
function S:Get() return ensure() end

-- Sugar: togglers / readers
function S:SetMessage(flag, val)
  local st = ensure()
  if st.Messages then st.Messages[flag] = val end
end
function S:GetMessage(flag)
  local st = ensure()
  return st.Messages and st.Messages[flag]
end

function S:SetAutomation(flag, val)
  local st = ensure()
  if st.Automation then st.Automation[flag] = val end
end
function S:GetAutomation(flag)
  local st = ensure()
  return st.Automation and st.Automation[flag]
end
