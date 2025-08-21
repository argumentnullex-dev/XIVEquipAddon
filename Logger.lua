local addon, XIVEquip = ...
local Const = XIVEquip.Const
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
  Debugf =
    function(slotID, fmt, ...)
      if not _G.XIVEquip_Debug then return end

      local bypass = (slotID == "force")

      if not bypass then
        local only = rawget(_G, "XIVEquip_DebugSlot")
        if only ~= nil then
          if type(only) == "number" then
            if slotID ~= only then return end
          elseif type(only) == "string" then
            local n = tonumber(only)
            if n and slotID ~= n then return end
          elseif type(only) == "table" then
            if not only[slotID] then return end
          end
        end
      end

      local labels = (Const and Const.SLOT_LABEL) or (XIVEquip and XIVEquip.Gear_Core and XIVEquip.Gear_Core.SLOT_LABEL)
      local name = (labels and labels[slotID]) or ("Slot "..tostring(slotID))

      -- safe format so a bad fmt/args combo doesn't crash logs
      local ok, msg = pcall(string.format, fmt, ...)
      if not ok then msg = tostring(fmt) end

      print(string.format("|cff7fbfffXIVEquip:DBG|r [%s] %s", name, msg))
    end
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
