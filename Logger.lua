local addon, XIVEquip = ...
XIVEquip = XIVEquip or {}

local PREFIX = "|cff66ccffXIVEquip|r"
local function concatParts(...)
  local t = {}
  for i=1, select("#", ...) do
    local v = select(i, ...)
    t[#t+1] = (v == nil) and "nil" or tostring(v)
  end
  return table.concat(t, " ")
end

function XIVEquip.DebugEnabled()
  local s = _G.XIVEquip_Settings
  return s and s.Debug
end

XIVEquip.Log = {
  Debug = function(...) if XIVEquip.DebugEnabled() then print(PREFIX, concatParts(...)) end end,
  Info  = function(...) print(PREFIX, concatParts(...)) end,
  Warn  = function(...) print(PREFIX, "|cffffff00[warn]|r", concatParts(...)) end,
  Error = function(...) print(PREFIX, "|cffff3333[error]|r", concatParts(...)) end,
}

-- Optional: slash toggle
SLASH_XIVEQUIP1 = "/xivequip"
SlashCmdList.XIVEQUIP = function(msg)
  msg = (msg or ""):lower()
  if msg:find("debug") then
    _G.XIVEquip_Settings = _G.XIVEquip_Settings or {}
    local s = _G.XIVEquip_Settings
    s.Debug = not s.Debug
    print(PREFIX, "Debug:", s.Debug and "ON" or "OFF")
  else
    print(PREFIX, "Commands: /xivequip debug")
  end
end
