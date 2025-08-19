-- XIVEquip.lua
local addonName, XIVEquip = ...
local L = XIVEquip.L

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

local status

-- message gates
local function msgLogin(text)
  if XIVEquip_Settings and XIVEquip_Settings.Messages and XIVEquip_Settings.Messages.Login then
    print(L.AddonPrefix .. text)
  end
end
local function msgError(text) print(L.AddonPrefix .. text) end
function XIVEquip.ShouldShowEquipMsgs()
  return XIVEquip_Settings and XIVEquip_Settings.Messages and XIVEquip_Settings.Messages.Equip
end

f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == addonName then
    -- defaults
    XIVEquip_Settings = XIVEquip_Settings or {}
    local s = XIVEquip_Settings
    s.SelectedComparer = s.SelectedComparer or "default"
    s.Messages = s.Messages or { Login = true, Equip = true }
    if s.AutoSpecSets == nil then s.AutoSpecSets = false end  -- default OFF
    s.AutoSpecMap  = s.AutoSpecMap or {}   -- SpecID -> "AUTO" or equipment set name
    s.Weapons = s.Weapons or {}
    s.Weapons.Mode = s.Weapons.Mode or "AUTO"   -- AUTO | TWOHAND | DUAL_1H | DUAL_2H | MH_SHIELD | MH_OFFHAND | SOLO_1H
    s.Weapons.Bias = s.Weapons.Bias or "AUTO"   -- AUTO | PREF_2H | PREF_DW | PREF_1H | NONE

  elseif event == "PLAYER_LOGIN" then
    if not (XIVEquip.Comparers and XIVEquip.Comparers.Initialize) then
      print((XIVEquip.L and XIVEquip.L.AddonPrefix or "XIVEquip: ") ..
            "Comparer core not loaded (check TOC order / Comparers.lua).")
      return
    end
    local status = XIVEquip.Comparers:Initialize()
    local active = XIVEquip.Comparers:GetActiveName()
    if     status == "default:pawn"      then msgLogin(L.Loaded_Default_Pawn)
    elseif status == "default:ilvl"      then msgLogin(L.Loaded_Default_Ilvl)
    elseif status == "saved:ok"          then msgLogin(string.format(L.Loaded_Using_Name, tostring(active)))
    elseif status == "saved:unknown"     then msgLogin(L.Warn_Unknown)
    elseif status == "saved:unavailable" then msgLogin(L.Warn_Unavailable)
    else                                          msgLogin(string.format(L.Loaded_Using_Name, tostring(active or "ilvl")))
    end
  end
end)

-- Called by the UI button
function XIVEquip:EquipBestGear()
  if not XIVEquip.Gear or not XIVEquip.Gear.EquipBest then
    msgError(L.NoComparer)
    return
  end
  XIVEquip.Gear:EquipBest()
end

SLASH_XIVEQUIP1 = "/xivequip"
SlashCmdList.XIVEQUIP = function(msg)
  msg = (msg or ""):lower()
  if msg:find("debug") then
    _G.XIVEquip_Settings = _G.XIVEquip_Settings or {}
    local s = _G.XIVEquip_Settings
    s.Debug = not s.Debug
    print("XIVEquip Debug:", s.Debug and "ON" or "OFF")
  else
    print("/xivequip debug — toggle debug logging")
  end
end
