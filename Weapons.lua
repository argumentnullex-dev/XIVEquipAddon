local addon, XIVEquip = ...
XIVEquip = XIVEquip or {}
XIVEquip.Weapons = XIVEquip.Weapons or {}
local W = XIVEquip.Weapons

-- ------------------------------
-- constants / labels
-- ------------------------------
local SLOT_MH, SLOT_OH = 16, 17
local LABEL = {
  [SLOT_MH] = "Main Hand",
  [SLOT_OH] = "Off Hand",
}

-- ------------------------------
-- small utils (safe, cache-free where possible)
-- ------------------------------
local function ItemLocFromSlot(slotID)
  if ItemLocation and ItemLocation.CreateFromEquipmentSlot then
    return ItemLocation:CreateFromEquipmentSlot(slotID)
  end
end

local function GetIlvl(link)
  if type(GetDetailedItemLevelInfo) == "function" then
    local ok, v = pcall(GetDetailedItemLevelInfo, link)
    if ok and type(v) == "number" then return v end
  end
  local _, _, _, ilvl = GetItemInfo(link or "")
  return ilvl
end

local function safeGetItemID(loc)
  if not (C_Item and loc) then return nil end
  local ok, id = pcall(C_Item.GetItemID, loc)
  if ok then return id end
end

local function safeGetLinkFromLoc(loc, fallbackSlotID)
  -- Prefer Retail API
  if C_Item and C_Item.GetItemLink and loc then
    local ok, link = pcall(C_Item.GetItemLink, loc)
    if ok and link then return link end
  end
  -- Equipped fallback
  if fallbackSlotID and GetInventoryItemLink then
    local link = GetInventoryItemLink("player", fallbackSlotID)
    if link then return link end
  end
  -- Bag fallback
  if loc and loc.GetBagAndSlot and C_Container and C_Container.GetContainerItemLink then
    local bag, slot = loc:GetBagAndSlot()
    if bag and slot then
      local link = C_Container.GetContainerItemLink(bag, slot)
      if link then return link end
    end
  end
  return nil
end

local function scoreItem(cmp, loc)
  return (cmp and cmp.ScoreItem and cmp:ScoreItem(loc)) or 0
end

-- equip location helpers (from GetItemInfoInstant)
local function Is2H(equipLoc)
  return equipLoc == "INVTYPE_2HWEAPON"
end
local function Is1HMain(equipLoc)
  return equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND"
end
local function IsOffhandy(equipLoc)
  return equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONOFFHAND"
      or equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE"
end

-- ------------------------------
-- enumerate candidates (NO link/cache requirement)
-- ------------------------------
local function enumerateWeapons(cmp)
  local mh, oh, twos = {}, {}, {}

  -- Equipped MH/OH — classify via itemID (instant), link only for ilvl/pretty
  local function addEquipped(slotID, bucketDecider)
    local loc = ItemLocFromSlot(slotID)
    if not loc then return end
    local id = safeGetItemID(loc)
    if not id then return end
    local _, _, _, equipLoc = GetItemInfoInstant(id)
    if not equipLoc then return end
    local link  = safeGetLinkFromLoc(loc, slotID)
    local item = {
      loc      = loc,
      link     = link,
      equipLoc = equipLoc,
      score    = scoreItem(cmp, loc),
      ilvl     = link and GetIlvl(link) or 0,
    }
    bucketDecider(item)
  end

  addEquipped(SLOT_MH, function(it)
    if Is2H(it.equipLoc) then table.insert(twos, it)
    elseif Is1HMain(it.equipLoc) then table.insert(mh, it) end
  end)
  addEquipped(SLOT_OH, function(it)
    if IsOffhandy(it.equipLoc) then table.insert(oh, it) end
  end)

  -- Bags — classify by itemID + GetItemInfoInstant (never blocks on cache)
  if C_Container and C_Container.GetContainerNumSlots and ItemLocation and ItemLocation.CreateFromBagAndSlot then
    local maxBags = (NUM_BAG_SLOTS or 4)
    for bag = 0, maxBags do
      local slots = C_Container.GetContainerNumSlots(bag) or 0
      for slot = 1, slots do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID then
          local _, _, _, equipLoc = GetItemInfoInstant(info.itemID)
          if equipLoc and (Is2H(equipLoc) or Is1HMain(equipLoc) or IsOffhandy(equipLoc)) then
            local loc  = ItemLocation:CreateFromBagAndSlot(bag, slot)
            local link = info.hyperlink or C_Container.GetContainerItemLink(bag, slot)
            local item = {
              loc      = loc,
              link     = link,
              equipLoc = equipLoc,
              score    = scoreItem(cmp, loc),
              ilvl     = link and GetIlvl(link) or 0,
            }
            if Is2H(equipLoc) then
              table.insert(twos, item)
            elseif Is1HMain(equipLoc) then
              table.insert(mh, item)
            elseif IsOffhandy(equipLoc) then
              table.insert(oh, item)
            end
          end
        end
      end
    end
  end

  return mh, oh, twos
end

-- ------------------------------
-- pick best loadout (2H vs 1H+OH)
-- ------------------------------
local function pickBestLoadout(cmp)
  local mh, oh, twos = enumerateWeapons(cmp)

  table.sort(twos, function(a,b) return (a.score or 0) > (b.score or 0) end)
  local best2H = twos[1]

  table.sort(mh, function(a,b) return (a.score or 0) > (b.score or 0) end)
  table.sort(oh, function(a,b) return (a.score or 0) > (b.score or 0) end)

  local bestPair, bestPairSum
  local TOP = 10
  for i = 1, math.min(#mh, TOP) do
    for j = 1, math.min(#oh, TOP) do
      -- Distinct instances: compare ItemLocation identity (bag/slot differs)
      local sameInstance = false
      if mh[i].loc and oh[j].loc and mh[i].loc.GetBagAndSlot and oh[j].loc.GetBagAndSlot then
        local abag, aslot = mh[i].loc:GetBagAndSlot()
        local bbag, bslot = oh[j].loc:GetBagAndSlot()
        sameInstance = (abag == bbag and aslot == bslot)
      end
      if not sameInstance then
        local sum = (mh[i].score or 0) + (oh[j].score or 0)
        if (not bestPairSum) or sum > bestPairSum then
          bestPairSum = sum
          bestPair = { mh = mh[i], oh = oh[j], sum = sum }
        end
      end
    end
  end

  local twoScore  = best2H and best2H.score or -math.huge
  local pairScore = bestPair and bestPair.sum  or -math.huge

  if twoScore >= pairScore and best2H then
    return { kind = "2H", mh = best2H, oh = nil }
  elseif bestPair then
    return { kind = "1H+OH", mh = bestPair.mh, oh = bestPair.oh }
  end
  return nil
end

-- ------------------------------
-- public: PlanBest
-- Returns: weaponPlan(table or nil), changes(table or nil), pending(bool)
-- ------------------------------
function W:PlanBest(cmp)
  local plan = pickBestLoadout(cmp)
  if not plan then
    return nil, nil, (XIVEquip and XIVEquip._needsItemRetry) == true
  end

  local function rowFor(slotID, newItem)
    local equippedLoc  = ItemLocFromSlot(slotID)
    local equippedLink = safeGetLinkFromLoc(equippedLoc, slotID)
    local equippedScore = equippedLoc and scoreItem(cmp, equippedLoc) or 0
    local equippedIlvl  = equippedLink and (GetIlvl(equippedLink) or 0) or 0

    local newLink   = newItem and newItem.link or equippedLink
    local newScore  = newItem and newItem.score or equippedScore
    local newIlvl   = newItem and newItem.ilvl  or equippedIlvl

    return {
      slot        = slotID,
      slotName    = LABEL[slotID] or ("Slot "..slotID),
      oldLink     = equippedLink or "|cff888888(None)|r",
      newLink     = newLink or equippedLink or "|cff888888(None)|r",
      deltaScore  = (newScore - (equippedScore or 0)),
      deltaIlvl   = (newIlvl - (equippedIlvl or 0)),
      newLoc      = newItem and newItem.loc or nil,
      oldLoc      = equippedLoc,
      scaleValues = nil, -- optional: fill from Pawn if you want weighted deltas
    }
  end

  local changes = {}
  if plan.kind == "2H" then
    table.insert(changes, rowFor(SLOT_MH, plan.mh))
    -- Off-hand will be empty/ignored when equipping a 2H
  else
    table.insert(changes, rowFor(SLOT_MH, plan.mh))
    table.insert(changes, rowFor(SLOT_OH, plan.oh))
  end

  local newText
  if plan.kind == "2H" then
    newText = (plan.mh and plan.mh.link) or "(no 2H)"
  else
    local a = (plan.mh and plan.mh.link) or "(no MH)"
    local b = (plan.oh and plan.oh.link) or "(no OH)"
    newText = a .. "  +  " .. b
  end

  local weaponPlan = { kind = plan.kind, newText = newText }
  local pending = (XIVEquip and XIVEquip._needsItemRetry) == true

  return weaponPlan, changes, pending
end

-- ------------------------------
-- public: EquipBest
-- ------------------------------
function W:EquipBest(cmp, plan, showEquip)
  plan = plan or pickBestLoadout(cmp)
  if not plan then return false end

  local function equipLoc(loc, slotID)
    if not loc then return false end
    -- Prefer bag pickup (reliable, no cache assumptions)
    if loc.GetBagAndSlot and C_Container and EquipCursorItem then
      local bag, slot = loc:GetBagAndSlot()
      if bag and slot then
        ClearCursor()
        C_Container.PickupContainerItem(bag, slot)
        EquipCursorItem(slotID)
        ClearCursor()
        return true
      end
    end
    -- Fallback: equip by link (works for equipped-to-equipped or cached items)
    local link = safeGetLinkFromLoc(loc, slotID)
    if link and EquipItemByName then
      EquipItemByName(link, slotID)
      return true
    end
    return false
  end

  local changed = false
  if plan.kind == "2H" then
    changed = equipLoc(plan.mh.loc, SLOT_MH) or changed
    if showEquip and plan.mh and plan.mh.link then
      print((XIVEquip.L.AddonPrefix or "XIVEquip: "), string.format(XIVEquip.L.ReplacedWith or "Replaced %s with %s.", GetInventoryItemLink("player",SLOT_MH) or "(none)", plan.mh.link))
    end
  else
    if plan.mh then
      changed = equipLoc(plan.mh.loc, SLOT_MH) or changed
      if showEquip and plan.mh.link then
        print((XIVEquip.L.AddonPrefix or "XIVEquip: "), string.format(XIVEquip.L.ReplacedWith or "Replaced %s with %s.", GetInventoryItemLink("player",SLOT_MH) or "(none)", plan.mh.link))
      end
    end
    if plan.oh then
      changed = equipLoc(plan.oh.loc, SLOT_OH) or changed
      if showEquip and plan.oh.link then
        print((XIVEquip.L.AddonPrefix or "XIVEquip: "), string.format(XIVEquip.L.ReplacedWith or "Replaced %s with %s.", GetInventoryItemLink("player",SLOT_OH) or "(none)", plan.oh.link))
      end
    end
  end

  return changed
end
