-- AutoSpecSwitcher.lua (drop-in)
local addonName, XIVEquip = ...
XIVEquip = XIVEquip or {}

-- Saved setting (default: ON)
_G.XIVEquip_Settings = _G.XIVEquip_Settings or {}
if _G.XIVEquip_Settings.AutoSpecEquip == nil then
  _G.XIVEquip_Settings.AutoSpecEquip = true
end

-- Helpers
local function GearMod() return XIVEquip and XIVEquip.Gear end
local function prefix()
  return (XIVEquip and XIVEquip.L and XIVEquip.L.AddonPrefix) or "XIVEquip: "
end
local function dbg(fmt, ...)
  if not _G.XIVEquip_DebugAutoSpec then return end
  local ok, msg = pcall(string.format, fmt, ...)
  print(prefix() .. "[AutoSpec] " .. (ok and msg or tostring(fmt)))
end

local f = CreateFrame("Frame")
local lastSpecIndex = nil
local pending = false
local lastRunAt = 0

local function canRun()
  if not (_G.XIVEquip_Settings and _G.XIVEquip_Settings.AutoSpecEquip) then
    dbg("blocked: setting OFF")
    return false
  end
  if InCombatLockdown() then
    dbg("blocked: in combat")
    return false
  end
  local Gear = GearMod()
  if not (Gear and Gear.EquipBest) then
    dbg("blocked: Gear:EquipBest not available yet")
    return false
  end
  return true
end

local function equipNow(reason)
  dbg("equipNow(%s) called", tostring(reason))
  if not canRun() then
    if InCombatLockdown() then
      pending = true
      f:RegisterEvent("PLAYER_REGEN_ENABLED")
      dbg("queued for after combat")
    end
    return
  end
  local now = GetTime and GetTime() or 0
  if (now - lastRunAt) < 0.75 then
    dbg("throttled (%.2f s since last run)", now - lastRunAt)
    return
  end
  lastRunAt = now

  local Gear = GearMod()
  if Gear and Gear.EquipBest then
    dbg("calling Gear:EquipBest()")
    Gear:EquipBest()  -- your Gear handles saving "Spec.xive" set
  end
end

local function updateSpecIndex(tag)
  local idx = GetSpecialization()
  dbg("updateSpecIndex(%s): old=%s new=%s", tostring(tag), tostring(lastSpecIndex), tostring(idx))
  if idx and idx ~= lastSpecIndex then
    lastSpecIndex = idx
    C_Timer.After(0.25, function() equipNow(tag or "SPEC_CHANGED") end)
  else
    dbg("no change detected; not equipping")
  end
end

f:SetScript("OnEvent", function(self, event, arg1)
  if event == "PLAYER_ENTERING_WORLD" then
    -- Initialize baseline and don’t auto-equip at login/zone by default
    lastSpecIndex = GetSpecialization()
    dbg("PEW: baseline specIndex=%s", tostring(lastSpecIndex))

  elseif event == "PLAYER_LOGIN" then
    -- Redundant baseline for safety
    lastSpecIndex = GetSpecialization()
    dbg("LOGIN: baseline specIndex=%s", tostring(lastSpecIndex))

  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    -- Some clients pass unit, some don’t—treat nil as player
    local unit = arg1 or "player"
    dbg("PLAYER_SPECIALIZATION_CHANGED unit=%s", tostring(unit))
    if unit == "player" then
      updateSpecIndex("PLAYER_SPECIALIZATION_CHANGED")
    end

  elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
    dbg("ACTIVE_TALENT_GROUP_CHANGED")
    updateSpecIndex("ACTIVE_TALENT_GROUP_CHANGED")

  elseif event == "PLAYER_TALENT_UPDATE" then
    -- Fires a lot; we still gate by spec index change and throttle
    dbg("PLAYER_TALENT_UPDATE")
    updateSpecIndex("PLAYER_TALENT_UPDATE")

  elseif event == "PLAYER_REGEN_ENABLED" then
    if pending then
      pending = false
      self:UnregisterEvent("PLAYER_REGEN_ENABLED")
      dbg("out of combat; running equip")
      C_Timer.After(0.10, function() equipNow("OUT_OF_COMBAT") end)
    end
  end
end)

-- Register events
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
f:RegisterEvent("PLAYER_TALENT_UPDATE")

-- Slash toggle + test
SLASH_XIVEAUTO1 = "/xiveauto"
SlashCmdList.XIVEAUTO = function(msg)
  msg = tostring(msg or ""):lower()
  if msg:match("^%s*test") then
    equipNow("SLASH_TEST")
    return
  end
  local s = _G.XIVEquip_Settings
  s.AutoSpecEquip = not s.AutoSpecEquip
  print(prefix() .. "Auto-equip on spec change: " .. (s.AutoSpecEquip and "|cff55ff55ON|r" or "|cffff5555OFF|r"))
end
