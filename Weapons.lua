-- Weapons.lua
local addon, XIVEquip = ...
local L = XIVEquip.L
local Log = (XIVEquip and XIVEquip.Log) or { Debug=function() end, Info=function() end, Warn=function() end, Error=function() end }

local Weapons = {}
XIVEquip.Weapons = Weapons

-- === Spec & talent helpers ===
local function getSpecID()
  local idx = GetSpecialization()
  if not idx then return nil end
  return GetSpecializationInfo(idx)
end
local function specID() return getSpecID() end

-- Basic class/spec capability flags used to gate combo generation
local function classFlags()
  local _, class = UnitClass("player")
  local canDW = (CanDualWield and CanDualWield()) or (IsDualWielding and IsDualWielding()) or false

  -- Shields
  local canShield = (class == "WARRIOR" or class == "PALADIN" or class == "SHAMAN")

  -- Frills (INVTYPE_HOLDABLE)
  local sID = (function() local i=GetSpecialization(); return i and GetSpecializationInfo(i) or nil end)()
  local isHolyPal = (class == "PALADIN" and sID == 65)
  local canFrill =
       class == "MAGE" or class == "PRIEST" or class == "WARLOCK"
    or class == "DRUID" or class == "SHAMAN" or class == "EVOKER"
    or isHolyPal or (class == "MONK" and sID == 270)

  return { dw = canDW, shield = canShield, frill = canFrill, class = class, specID = sID }
end

-- Talent/spell IDs for auto-bias (safe if missing)
local SMF_SPELL_ID = 81099  -- Single-Minded Fury (dual 1H)
local TG_SPELL_ID  = 46917  -- Titan's Grip (dual 2H)
local DK_2H_ID     = 81327  -- Might of the Frozen Wastes (2H bias)
local DK_DW_ID     = 66192  -- Threat of Thassarian (DW bias)
local function hasSpell(id) return id and IsPlayerSpell and IsPlayerSpell(id) end

-- === EquipLoc helpers ===
local WEAPON_EQUIPLOCS = {
  INVTYPE_2HWEAPON   = true,
  INVTYPE_RANGED     = true,   -- bows/guns/xbows (hunter)
  INVTYPE_RANGEDRIGHT= true,   -- wand (non-hunter main-hand-only) or ranged (hunter)
  INVTYPE_WEAPON     = true,   -- either hand 1H
  INVTYPE_WEAPONMAINHAND = true,
  INVTYPE_WEAPONOFFHAND  = true,
  INVTYPE_SHIELD     = true,
  INVTYPE_HOLDABLE   = true,
}

local function getEquipLocFromLink(link)
  if not link then return nil end
  local _, _, _, _, _, _, _, _, equipLoc = GetItemInfoInstant(link)
  return equipLoc
end

-- Normalize any "location-like" value and get link + ItemLocation
local function normalizeLoc(loc)
  if type(loc) == "table" and loc.GetEquipmentSlot then
    local link = nil
    if C_Item.DoesItemExist and C_Item.DoesItemExist(loc) then
      link = C_Item.GetItemLink(loc)
      if not link and C_Item.RequestLoadItemData then C_Item.RequestLoadItemData(loc) end
      link = link or (C_Item.GetItemLink(loc))
    end
    return loc, link
  end

  local bag, slot
  if type(loc) == "table" and loc.bagID and loc.slotIndex then
    bag, slot = loc.bagID, loc.slotIndex
  elseif type(loc) == "table" and loc.GetBagAndSlot then
    bag, slot = loc:GetBagAndSlot()
  end
  if bag ~= nil and slot ~= nil then
    local link = C_Container.GetContainerItemLink(bag, slot)
    local itemLoc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    return itemLoc, link
  end

  if type(loc) == "number" then
    local itemLoc = ItemLocation:CreateFromEquipmentSlot(loc)
    local link = GetInventoryItemLink("player", loc)
    return itemLoc, link
  end

  return nil, nil
end

-- Collect and score all weapon-like candidates (equipped + bags)
local function collectCandidates(comparer)
  local list = {}

  local function consider(loc)
    local itemLoc, link = normalizeLoc(loc)
    if not (itemLoc and link) then return end

    local equipLoc = getEquipLocFromLink(link)
    if not (equipLoc and WEAPON_EQUIPLOCS[equipLoc]) then return end

    local score = comparer and comparer.ScoreItem and comparer.ScoreItem(itemLoc, INVSLOT_MAINHAND) or nil
    if not score or score <= 0 then return end

    list[#list+1] = { loc = itemLoc, equipLoc = equipLoc, score = score, link = link }
  end

  -- Currently equipped MH/OH
  consider(INVSLOT_MAINHAND)
  consider(INVSLOT_OFFHAND)

  -- Bags
  for bag = 0, NUM_BAG_SLOTS do
    local n = C_Container.GetContainerNumSlots(bag) or 0
    for i = 1, n do
      consider({ bagID = bag, slotIndex = i })
    end
  end

  Log.Debug("Weapons: collected candidates =", #list)
  return list
end

local function sortDesc(a, b) return (a.score or 0) > (b.score or 0) end
local function tset(list) local s={} for _,k in ipairs(list) do s[k]=true end return s end

-- === Combo kinds (no public SOLO_1H mode) ===
local K = {
  TWOHAND     = "TWOHAND",
  DUAL_1H     = "DUAL_1H",
  DUAL_2H     = "DUAL_2H",     -- Fury Titan’s Grip only
  MH_SHIELD   = "MH_SHIELD",
  MH_OFFHAND  = "MH_OFFHAND",
}

-- Allowed combos for this character, filtered by user setting
local function allowedCombos()
  local mode = (XIVEquip_Settings and XIVEquip_Settings.Weapons and XIVEquip_Settings.Weapons.Mode) or "AUTO"
  local sIdx = GetSpecialization()
  local spec = sIdx and GetSpecializationInfo(sIdx)
  local flags = classFlags()

  local function want(kind) return (mode == "AUTO" or mode == kind) end
  local combos = {}

  if want(K.TWOHAND) then table.insert(combos, K.TWOHAND) end
  if want(K.DUAL_1H) and flags.dw then table.insert(combos, K.DUAL_1H) end
  if want(K.DUAL_2H) and spec == 72 and hasSpell(TG_SPELL_ID) then
    table.insert(combos, K.DUAL_2H)
  end

  local shieldSpecs = { [65]=true,[66]=true,[73]=true,[262]=true,[264]=true }
  if want(K.MH_SHIELD) and shieldSpecs[spec] and flags.shield then
    table.insert(combos, K.MH_SHIELD)
  end

  local frillSpecs = {
    [62]=true,[63]=true,[64]=true,[256]=true,[257]=true,[258]=true,
    [265]=true,[266]=true,[267]=true,[102]=true,[105]=true,
    [262]=true,[264]=true,[1467]=true,[1468]=true,[1473]=true,[65]=true,[270]=true,
  }
  if want(K.MH_OFFHAND) and frillSpecs[spec] and flags.frill then
    table.insert(combos, K.MH_OFFHAND)
  end

  local seen, out = {}, {}
  for _, k in ipairs(combos) do if not seen[k] then seen[k]=true; table.insert(out, k) end end

  Log.Debug("Weapons: allowed combos =", table.concat(out, ", "))
  return out
end

-- Bias: tiny bonus to break ties based on settings/talents
local function biasBonus(kind)
  local bias = (XIVEquip_Settings and XIVEquip_Settings.Weapons and XIVEquip_Settings.Weapons.Bias) or "AUTO"
  local sID = specID()
  if bias == "AUTO" then
    if sID == 72 then -- Fury: SMF vs TG
      if hasSpell(SMF_SPELL_ID) and (kind == "DUAL_1H") then return 0.001 end
      if hasSpell(TG_SPELL_ID)  and (kind == "DUAL_2H" or kind == "DUAL_1H") then return 0.001 end
    elseif sID == 251 then -- Frost DK
      if hasSpell(DK_2H_ID) and (kind == "TWOHAND") then return 0.001 end
      if hasSpell(DK_DW_ID) and (kind == "DUAL_1H") then return 0.001 end
    end
    return 0
  end
  if bias == "PREF_2H" and (kind == "TWOHAND" or kind == "DUAL_2H") then return 0.001 end
  if bias == "PREF_DW"  and (kind == "DUAL_1H" or kind == "DUAL_2H") then return 0.001 end
  if bias == "PREF_1H"  and (kind == "MH_SHIELD" or kind == "MH_OFFHAND") then return 0.001 end
  return 0
end

-- === Main selection: compute best MH/OH pair for all legal combos ===
function Weapons:FindBestLoadout(comparer)
  local all = collectCandidates(comparer)
  if #all == 0 then
    Log.Debug("Weapons: no candidates to score")
    return { mh = nil, oh = nil, total = -1, kind = nil }
  end

  local flags = classFlags()
  local pools = {
    twoH       = {},
    eitherHand = {},
    mainOnly   = {},
    ohWeapon   = {},
    ohShield   = {},
    ohFrill    = {},
  }
  for _, c in ipairs(all) do
    local t = c.equipLoc
    if t == "INVTYPE_2HWEAPON" or t == "INVTYPE_RANGED" then
      table.insert(pools.twoH, c)
    elseif t == "INVTYPE_RANGEDRIGHT" then
      if flags.class == "HUNTER" then
        table.insert(pools.twoH, c)
      else
        table.insert(pools.mainOnly, c) -- wand
      end
    elseif t == "INVTYPE_WEAPON" then
      table.insert(pools.eitherHand, c)
    elseif t == "INVTYPE_WEAPONMAINHAND" then
      table.insert(pools.mainOnly, c)
    elseif t == "INVTYPE_WEAPONOFFHAND" then
      table.insert(pools.ohWeapon, c)
    elseif t == "INVTYPE_SHIELD" then
      table.insert(pools.ohShield, c)
    elseif t == "INVTYPE_HOLDABLE" then
      table.insert(pools.ohFrill, c)
    end
  end
  for _, arr in pairs(pools) do table.sort(arr, sortDesc) end

  local combos = tset(allowedCombos())
  local best = { mh=nil, oh=nil, total=-1, kind=nil }
  local function consider(kind, mh, oh)
    local total = 0
    if mh then total = total + (mh.score or 0) end
    if oh then total = total + (oh.score or 0) end
    total = total + biasBonus(kind)
    if total > best.total then best = { mh=mh, oh=oh, total=total, kind=kind } end
  end

  -- TWOHAND
  if combos["TWOHAND"] then
    local a = pools.twoH[1]
    if a then consider("TWOHAND", a, nil) end
  end

  -- DUAL_2H (Fury TG)
  if combos["DUAL_2H"] then
    local a, b = pools.twoH[1], pools.twoH[2]
    if a and b then consider("DUAL_2H", a, b) end
  end

  -- DUAL_1H
  if combos["DUAL_1H"] and flags.dw then
    local mh = pools.eitherHand[1] or pools.mainOnly[1]
    if mh then
      local oh = nil
      for _, c in ipairs(pools.eitherHand) do if c ~= mh then oh = c break end end
      if not oh then oh = pools.ohWeapon[1] end
      if oh then consider("DUAL_1H", mh, oh) end
    end
  end

  -- MH + SHIELD
  if combos["MH_SHIELD"] and flags.shield then
    local mh = pools.eitherHand[1] or pools.mainOnly[1]
    local oh = pools.ohShield[1]
    if mh and oh then consider("MH_SHIELD", mh, oh) end
  end

  -- MH + FRILL
  if combos["MH_OFFHAND"] and flags.frill then
    local mh = pools.eitherHand[1] or pools.mainOnly[1]
    local oh = pools.ohFrill[1]
    if mh and oh then consider("MH_OFFHAND", mh, oh) end
  end

  if best.total < 0 then
    local mh = pools.eitherHand[1] or pools.mainOnly[1]
    if mh then best = { mh=mh, oh=nil, total=(mh.score or 0), kind="FALLBACK" } end
  end

  Log.Debug("Weapons: best =", best.kind or "nil", "total=", best.total,
            best.mh and ("MH:"..(best.mh.equipLoc or "?")) or "MH:nil",
            best.oh and ("OH:"..(best.oh.equipLoc or "?")) or "OH:nil")

  return best
end

-- Equip a provided loadout (legacy signature)
function Weapons:EquipLoadout(loadout, showEquip)
  if not loadout then return false end
  local function linkFromSlot(slotID) return GetInventoryItemLink("player", slotID) end

  local changed = false
  local noneText = "|cff888888(None)|r"
  local oldMH, oldOH = linkFromSlot(INVSLOT_MAINHAND), linkFromSlot(INVSLOT_OFFHAND)

  if loadout.mh then
    local newMH = loadout.mh.link or GetInventoryItemLink("player", INVSLOT_MAINHAND) or C_Item.GetItemLink(loadout.mh.loc) or C_Item.GetItemName(loadout.mh.loc)
    if newMH and newMH ~= oldMH then
      Log.Debug("Equip MH:", newMH)
      EquipItemByName(newMH, INVSLOT_MAINHAND)
      changed = true
      if showEquip then print((L.AddonPrefix or "XIVEquip: ") .. string.format(L.ReplacedWith or "Replaced %s with %s.", oldMH or noneText, newMH)) end
    end
  end

  if loadout.mh and (loadout.mh.equipLoc == "INVTYPE_2HWEAPON" or loadout.mh.equipLoc == "INVTYPE_RANGED") and loadout.kind ~= "DUAL_2H" then
    return changed
  end

  if loadout.oh then
    local currentOH = linkFromSlot(INVSLOT_OFFHAND)
    local newOH = loadout.oh.link or C_Item.GetItemLink(loadout.oh.loc) or C_Item.GetItemName(loadout.oh.loc)
    if newOH and newOH ~= currentOH then
      Log.Debug("Equip OH:", newOH)
      EquipItemByName(newOH, INVSLOT_OFFHAND)
      changed = true
      if showEquip then print((L.AddonPrefix or "XIVEquip: ") .. string.format(L.ReplacedWith or "Replaced %s with %s.", currentOH or noneText, newOH)) end
    end
  end

  return changed
end

-- Newer signature kept for convenience
function XIVEquip.Weapons:EquipBestLoadout(comparer, showEquip)
  local best = self:FindBestLoadout(comparer)
  return self:EquipLoadout(best, showEquip)
end
