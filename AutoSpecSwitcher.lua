-- AutoSpecSwitcher.lua
local addon, XIVEquip = ...
local L = XIVEquip.L

local function GetCurrentSpecInfo()
  local idx = GetSpecialization()
  if not idx then return nil end
  local specID, name, _, icon = GetSpecializationInfo(idx)
  return specID, name, icon
end

local function FindEquipmentSetIDByName(name)
  if not (C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs) then return nil end
  for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
    local setName = C_EquipmentSet.GetEquipmentSetInfo(id)
    if setName == name then return id end
  end
  return nil
end

local function SaveSetByName(setName, iconFileID)
  if not C_EquipmentSet then
    print(L.AddonPrefix .. L.SpecAuto_NoEM)
    return
  end
  local setID = FindEquipmentSetIDByName(setName)
  if not setID and C_EquipmentSet.CreateEquipmentSet then
    setID = C_EquipmentSet.CreateEquipmentSet(setName, iconFileID)
  end
  if setID then
    if C_EquipmentSet.ModifyEquipmentSet then
      C_EquipmentSet.ModifyEquipmentSet(setID, setName, iconFileID)
    end
    C_EquipmentSet.SaveEquipmentSet(setID)
    if XIVEquip.ShouldShowEquipMsgs() then
      print(L.AddonPrefix .. string.format(L.SpecAuto_Saved, setName))
    end
  else
    print(L.AddonPrefix .. L.SpecAuto_NoEM)
  end
end

local function targetSetNameForSpec(specID, specName)
  local map = XIVEquip_Settings and XIVEquip_Settings.AutoSpecMap or nil
  local sel = map and map[specID] or "AUTO"
  if sel == "AUTO" or sel == nil then
    return (specName .. ".xiv")
  else
    return sel -- explicit equipment set name chosen in settings
  end
end

local function EquipAndSaveForCurrentSpec()
  if InCombatLockdown() then return end
  if not (XIVEquip_Settings and XIVEquip_Settings.AutoSpecSets) then return end

  -- 1) Equip best for the current spec
  if XIVEquip.Gear and XIVEquip.Gear.EquipBest then
    XIVEquip.Gear:EquipBest()
  end

  -- 2) Save into the chosen set for this spec
  local specID, specName, icon = GetCurrentSpecInfo()
  if specID and specName and icon then
    local setName = targetSetNameForSpec(specID, specName)
    SaveSetByName(setName, icon)
  end
end

-- Event frame (unchanged)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit == "player" then
    EquipAndSaveForCurrentSpec()
  end
end)
