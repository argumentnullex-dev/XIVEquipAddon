local addon, XIVEquip = ...
-- Be defensive: some tools or unusual load contexts may not pass the addon table via `...`.
-- Fall back to the global table if present before indexing into it.
XIVEquip = XIVEquip or _G.XIVEquip or {}
local Const = XIVEquip and XIVEquip.Const

local PREFIX = "|cff66ccffXIVEquip|r"
local function concatParts(...)
  local t = {}
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    t[#t + 1] = (v == nil) and "nil" or tostring(v)
  end
  return table.concat(t, " ")
end

-- Use a safe print reference (prefer global print if present). This avoids errors if
-- some other file accidentally shadows or nils out a local `print` in the same env.
local _print = rawget(_G, "print") or print or function() end

function XIVEquip.DebugEnabled()
  local s = _G.XIVEquip_Settings
  if not s then return false end
  local d = s.Debug
  if type(d) == "boolean" then return d end
  if type(d) == "table" then return not not d.Enabled end
  return false
end

XIVEquip.Log = {
  Debug  = function(...) if XIVEquip.DebugEnabled() then _print(PREFIX, concatParts(...)) end end,
  Info   = function(...) _print(PREFIX, concatParts(...)) end,
  Warn   = function(...) _print(PREFIX, "|cffffff00[warn]|r", concatParts(...)) end,
  Error  = function(...) _print(PREFIX, "|cffff3333[error]|r", concatParts(...)) end,
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

        local labels = (Const and Const.SLOT_LABEL) or
            (XIVEquip and XIVEquip.Gear_Core and XIVEquip.Gear_Core.SLOT_LABEL)
        local name = (labels and labels[slotID]) or ("Slot " .. tostring(slotID))

        -- safe format so a bad fmt/args combo doesn't crash logs
        local ok, msg = pcall(string.format, fmt, ...)
        if not ok then msg = tostring(fmt) end

        _print(string.format("|cff7fbfffXIVEquip:DBG|r [%s] %s", name, msg))
      end
}

-- Optional: slash toggle
SLASH_XIVEQUIP1 = SLASH_XIVEQUIP1 or "/xivequip"
SlashCmdList = SlashCmdList or {}
SlashCmdList.XIVEQUIP = SlashCmdList.XIVEQUIP or function(msg)
  msg = (msg or ""):lower()
  if msg:find("debug") then
    _G.XIVEquip_Settings = _G.XIVEquip_Settings or {}
    local s = _G.XIVEquip_Settings
    s.Debug = not s.Debug
    _print(PREFIX, "Debug:", s.Debug and "ON" or "OFF")
  else
    _print(PREFIX, "Commands: /xivequip debug")
  end
end
