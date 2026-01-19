-- Gear_Core.lua
local addonName, XIVEquip = ...
local Core                = {}
local Log                 = XIVEquip.Log
local Const               = XIVEquip.Const
XIVEquip.Gear_Core        = Core

-- =========================
-- Public constants/lookups (unchanged)
-- =========================

Core.ARMOR                = Const.ARMOR
Core.ARMOR_SLOTS          = Const.ARMOR_SLOTS
Core.JEWELRY              = Const.JEWELRY
Core.JEWELRY_SLOTS        = Const.JEWELRY_SLOTS
Core.LOWER_ILVL_ARMOR     = Const.LOWER_ILVL_ARMOR
Core.LOWER_ILVL_JEWELRY   = Const.LOWER_ILVL_JEWELRY
Core.INV_BY_EQUIPLOC      = Const.INV_BY_EQUIPLOC
Core.SLOT_EQUIPLOCS       = Const.SLOT_EQUIPLOCS
Core.ITEMCLASS_ARMOR      = Const.ITEMCLASS_ARMOR
Core.SLOT_LABEL           = Const.SLOT_LABEL

local ARMOR_SLOTS         = Core.ARMOR_SLOTS

-- debugf: Core addon plumbing: debugf.
local function debugf(slotID, fmt, ...)
  if Log and Log.Debugf then
    return Log.Debugf(slotID, fmt, ...)
  end
end

-- =========================
-- Public helpers
-- =========================

-- guarded comparer call used by planners (returns 0 on error)
-- [XIVEquip-AUTO] Core.scoreItem: Computes a score used to compare candidate items.
function Core.scoreItem(cmp, itemLoc, slotID)
  if not (cmp and cmp.ScoreItem) then return 0 end
  local ok, v = pcall(cmp.ScoreItem, itemLoc, slotID)
  return (ok and type(v) == "number") and v or 0
end

-- Core.ItemInstanceKey: Core addon plumbing: item instance key.
function Core.ItemInstanceKey(itemLoc)
  if C_Item and C_Item.GetItemGUID and itemLoc then
    local ok, guid = pcall(C_Item.GetItemGUID, itemLoc)
    if ok and guid and guid ~= "" then return guid end
  end
  local link = C_Item and C_Item.GetItemLink and C_Item.GetItemLink(itemLoc)
  local id = link and tonumber(link:match("|Hitem:(%d+)"))
  local bag, slot = itemLoc and itemLoc.bagID, itemLoc and itemLoc.slotIndex
  return table.concat({ id or 0, bag or -1, slot or -1 }, ":")
end

-- Core.itemGUID: Core addon plumbing: item guid.
function Core.itemGUID(loc)
  if C_Item and C_Item.GetItemGUID and loc then
    local ok, guid = pcall(C_Item.GetItemGUID, loc)
    if ok then return guid end
  end
  return nil
end

-- Core.getItemLevel: Core addon plumbing: get item level.
function Core.getItemLevel(link, itemLoc)
  -- 1) Prefer ItemLocation if present (most accurate for current ilvl)
  if itemLoc and C_Item and C_Item.DoesItemExist and C_Item.DoesItemExist(itemLoc) then
    local ok, cur = pcall(C_Item.GetCurrentItemLevel, itemLoc)
    if ok and type(cur) == "number" and cur > 0 then
      return cur
    end
  end

  -- 2) Try cached API by link
  if link then
    local il = select(4, GetItemInfo(link)) -- item level here is 4th
    if type(il) == "number" and il > 0 then
      return il
    end

    -- 3) Fallback: detailed API (works even when not fully cached yet)
    local ok, det = pcall(GetDetailedItemLevelInfo, link)
    if ok and type(det) == "number" and det > 0 then
      return det
    end
  end

  return 0
end

-- Core.getItemLevelFromLink: Core addon plumbing: get item level from link.
function Core.getItemLevelFromLink(link)
  return Core.getItemLevel(link, nil)
end

-- Core.getItemLevelFromLocation: Core addon plumbing: get item level from location.
function Core.getItemLevelFromLocation(loc)
  return Core.getItemLevel(nil, loc)
end

-- Read currently equipped for a slot (unchanged logic)
-- [XIVEquip-AUTO] Core.equippedBasics: Helper for Core module.
function Core.equippedBasics(slotID, comparer)
  local loc = ItemLocation:CreateFromEquipmentSlot(slotID)
  if not (loc and C_Item.DoesItemExist and C_Item.DoesItemExist(loc)) then return nil end

  local link = GetInventoryItemLink("player", slotID)
  if not link and C_Item.GetItemLink then link = C_Item.GetItemLink(loc) end

  local ilvl = Core.getItemLevelFromLink(link)

  local equipLoc = link and select(9, GetItemInfo(link)) or nil

  local score = nil
  if comparer and comparer.ScoreItem then
    local ok, v = pcall(comparer.ScoreItem, loc, slotID)
    if ok and type(v) == "number" then score = v end
  end

  return { loc = loc, slot = slotID, link = link, ilvl = ilvl, score = score, equipLoc = equipLoc }
end

-- Equip a bag item into a specific slot (unchanged logic)
-- [XIVEquip-AUTO] Core.equipByBasics: Applies equipment changes (gear/weapons) for the addon.
function Core.equipByBasics(pick)
  if not pick then return nil end

  local loc = pick.loc or pick.itemLoc
  local bag, slot = nil, nil

  if loc and loc.GetEquipmentSlot then
    local inv = loc:GetEquipmentSlot()
    if inv then
      return GetInventoryItemLink("player", inv) or pick.link
    end
    if loc.GetBagAndSlot then
      bag, slot = loc:GetBagAndSlot()
    end
  end

  if not bag then
    bag, slot = pick.bagID, pick.slotIndex
  end
  if not bag or not slot then
    return pick.link
  end

  local invSlot = pick.targetSlot or (pick.equipLoc and Core.INV_BY_EQUIPLOC[pick.equipLoc]) or nil

  ClearCursor()
  C_Container.PickupContainerItem(bag, slot)
  if invSlot then
    EquipCursorItem(invSlot)
  else
    EquipCursorItem()
  end
  ClearCursor()

  return (invSlot and GetInventoryItemLink("player", invSlot)) or pick.link
end

-- Core.equipLocMatchesSlot: Core addon plumbing: equip loc matches slot.
function Core.equipLocMatchesSlot(equipLoc, slotID)
  local allowed = Core.SLOT_EQUIPLOCS[slotID]
  return allowed and allowed[equipLoc] or false
end

-- Core.playerArmorSubclass: Core addon plumbing: player armor subclass.
function Core.playerArmorSubclass()
  local class = select(2, UnitClass("player"))
  local map = {
    WARRIOR = 4,
    PALADIN = 4,
    DEATHKNIGHT = 4,
    HUNTER = 3,
    SHAMAN = 3,
    EVOKER = 3,
    ROGUE = 2,
    MONK = 2,
    DEMONHUNTER = 2,
    DRUID = 2,
    MAGE = 1,
    PRIEST = 1,
    WARLOCK = 1,
  }
  return map[class]
end

-- Checks if the given item is valid armor type for the player’s class
-- jewelry and cloaks are always valid
-- [XIVEquip-AUTO] Core.equipIsValidArmorType: Applies equipment changes (gear/weapons) for the addon.
function Core.equipIsValidArmorType(itemID, slotID, expectedArmorSubclass)
  if not itemID then return false end
  -- If this slot isn't restricted armor, always allow
  if not Core.ARMOR[slotID] then
    return true
  end

  local _, _, _, _, _, classID, subclassID = GetItemInfoInstant(itemID)
  if not classID or not subclassID then
    -- Be conservative on missing data for armor slots
    return false
  end

  if classID ~= Core.ITEMCLASS_ARMOR then
    return true -- not an armor item, don’t restrict
  end

  expectedArmorSubclass = expectedArmorSubclass or (Core.playerArmorSubclass and Core.playerArmorSubclass())
  if not expectedArmorSubclass then
    -- If we can't determine the player's proficiency, fail safe.
    return false
  end

  return subclassID == expectedArmorSubclass
end

-- =========================
-- Selection primitive
-- =========================

do
  -- Local aliases
  local equippedBasics        = Core.equippedBasics
  local equipLocMatchesSlot   = Core.equipLocMatchesSlot
  local equipIsValidArmorType = Core.equipIsValidArmorType
  local getItemLevelFromLink  = Core.getItemLevelFromLink
  local itemGUID              = Core.itemGUID
  local JEWELRY               = Core.JEWELRY
  local LOWER_ILVL_ARMOR      = Core.LOWER_ILVL_ARMOR
  local LOWER_ILVL_JEWELRY    = Core.LOWER_ILVL_JEWELRY

  local EPS                   = 1e-6

  -- Exported: Core.chooseForSlot (slot-agnostic; works for jewelry as-is)
  function Core.chooseForSlot(comparer, slotID, expectedArmorSubclass, used)
    local dbg           = debugf
    local equipped      = equippedBasics(slotID, comparer)
    local equippedIlvl  = (equipped and equipped.ilvl) or 0
    local equippedScore = (equipped and equipped.score) or nil
    local lowerBound    = JEWELRY[slotID] and LOWER_ILVL_JEWELRY or LOWER_ILVL_ARMOR

    local best          = nil

    for bag = 0, NUM_BAG_SLOTS do
      local num = C_Container.GetContainerNumSlots(bag) or 0
      for slot = 1, num do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID then
          local _, _, _, equipLoc, _, classID, subclassID = GetItemInfoInstant(info.itemID)
          if equipLoc
              and equipLocMatchesSlot(equipLoc, slotID)
              and equipIsValidArmorType(info.itemID, slotID, expectedArmorSubclass)
          then
            if dbg then dbg(slotID, "consider itemID=%s equipLoc=%s", tostring(info.itemID), tostring(equipLoc)) end

            local link = info.hyperlink or C_Container.GetContainerItemLink(bag, slot)
            -- Prefer the runtime/current item level for bag items when available (handles heirlooms)
            local itemLoc = nil
            if type(ItemLocation) == "table" and type(ItemLocation.CreateFromBagAndSlot) == "function" then
              itemLoc = ItemLocation:CreateFromBagAndSlot(bag, slot)
            end
            local ilvl = Core.getItemLevelFromLink(link)
            -- if itemLoc and C_Item and C_Item.GetCurrentItemLevel then
            --   local ok, cur = pcall(C_Item.GetCurrentItemLevel, itemLoc)
            --   if ok and type(cur) == "number" and cur > 0 then ilvl = cur end
            -- end
            if dbg then dbg(slotID, "candidate ilvl=%s link=%s", tostring(ilvl or "nil"), tostring(link or "nil")) end

            -- Treat ilvl == 1 (heirloom reported as level 1) as "unknown" and don't reject it
            local passesLowerBound = (type(ilvl) == "number") and ((ilvl == 1) or ilvl >= (equippedIlvl - lowerBound))
            if passesLowerBound then
              local itemLoc = (type(ItemLocation) == "table" and type(ItemLocation.CreateFromBagAndSlot) == "function") and
                  ItemLocation:CreateFromBagAndSlot(bag, slot) or nil
              local guid = itemGUID(itemLoc)
              if not (used and guid and used[guid]) then
                local score = nil
                if itemLoc and C_Item and C_Item.RequestLoadItemData then
                  pcall(C_Item.RequestLoadItemData, itemLoc)
                end
                if comparer and comparer.ScoreItem then
                  local ok, v = pcall(comparer.ScoreItem, itemLoc, slotID)
                  if ok and type(v) == "number" then score = v end
                end
                if dbg then
                  if score then
                    dbg(slotID, "scored: %s", tostring(score))
                  else
                    dbg(slotID, "skip: no score from comparer")
                  end
                end
                if score and (not best or score > best.score) then
                  if dbg then
                    dbg(slotID, "new best: score=%s ilvl=%s link=%s (prev=%s)",
                      tostring(score), tostring(ilvl), tostring(link or "nil"),
                      tostring(best and best.score or "nil"))
                  end
                  best = {
                    loc        = itemLoc,
                    guid       = guid,
                    link       = link,
                    score      = score,
                    ilvl       = ilvl,
                    equipLoc   = equipLoc,
                    targetSlot = slotID,
                  }
                end
              else
                if dbg then dbg(slotID, "skip: already used guid=%s link=%s", tostring(guid), tostring(link or "nil")) end
              end
            else
              if dbg then
                dbg(slotID, "skip: below lower bound (cand=%s, equipped=%s, bound=%s)",
                  tostring(ilvl or "nil"), tostring(equippedIlvl or "nil"), tostring(lowerBound))
              end
            end
          end
        end
      end
    end

    -- Guard: only upgrade if strictly better than what’s on the character.
    if best then
      if equippedScore ~= nil then
        if best.score <= (equippedScore + EPS) then
          if dbg then
            dbg(slotID, "reject: score-not-better (best=%s, equipped=%s)",
              tostring(best.score), tostring(equippedScore))
          end
          return nil, equipped
        end
      else
        if best.ilvl <= equippedIlvl then
          if dbg then
            dbg(slotID, "reject: ilvl-not-better (best=%s, equipped=%s)",
              tostring(best.ilvl), tostring(equippedIlvl))
          end
          return nil, equipped
        end
      end
    else
      if dbg then dbg(slotID, "no candidate passed filters") end
    end

    return best, equipped
  end
end

-- =========================
-- shared helper to append to plan + build a change row
-- =========================
-- [XIVEquip-AUTO] Core.appendPlanAndChange: Helper for Core module.
function Core.appendPlanAndChange(plan, changes, slotID, pick, equipped)
  -- Add to plan
  table.insert(plan, pick)

  -- Build the UI change row (exactly the same fields you’re using)
  local oldLink  = (equipped and equipped.link) or "|cff888888(None)|r"
  local newLink  = pick.link or oldLink
  local newScore = tonumber((pick and pick.score)) or 0
  local oldScore = tonumber((equipped and equipped.score)) or 0
  local newIlvl  = tonumber((pick and pick.ilvl) or 0) or 0
  local oldIlvl  = tonumber((equipped and equipped.ilvl) or 0) or 0

  local row      = {
    slot        = slotID,
    slotName    = Core.SLOT_LABEL[slotID] or ("Slot " .. slotID),
    oldLink     = oldLink,
    newLink     = newLink,
    deltaScore  = newScore - oldScore,
    deltaIlvl   = newIlvl - oldIlvl,
    newLoc      = pick.loc,
    oldLoc      = equipped and equipped.loc or nil,
    scaleValues = pick.scaleValues,
  }

  table.insert(changes, row)
  return row
end

-- try-pick helper that runs chooseForSlot, appends outputs, and marks `used`.
-- Returns pick, equipped, chosen (boolean).
-- [XIVEquip-AUTO] Core.tryChooseAppend: Helper for Core module.
function Core.tryChooseAppend(plan, changes, slotID, comparer, expectedArmorSubclass, used)
  local pick, equipped = Core.chooseForSlot(comparer, slotID, expectedArmorSubclass, used)

  -- No pick: log and return
  if not pick then
    if debugf then
      debugf(slotID, "no pick; equipped ilvl=%s score=%s link=%s",
        tostring(equipped and equipped.ilvl or "nil"),
        tostring(equipped and equipped.score or "nil"),
        tostring(equipped and equipped.link or "nil"))
    end
    return nil, equipped, false
  end

  -- We have a pick: log, append, mark used
  if debugf then
    debugf(slotID, "picked ilvl=%s score=%s link=%s  vs equipped ilvl=%s score=%s",
      tostring(pick.ilvl or "nil"),
      tostring(pick.score or "nil"),
      tostring(pick.link or "nil"),
      tostring(equipped and equipped.ilvl or "nil"),
      tostring(equipped and equipped.score or "nil"))
  end

  Core.appendPlanAndChange(plan, changes, slotID, pick, equipped)
  if pick.guid and used then used[pick.guid] = true end
  return pick, equipped, true
end

-- Resolve an item link from an ItemLocation or slotID (unchanged logic)
-- [XIVEquip-AUTO] Core.linkFromLocation: Helper for Core module.
function Core.linkFromLocation(location)
  if not location then return nil end

  -- 1) Try the modern API directly (works for ItemLocation userdata/tables)
  if C_Item and C_Item.GetItemLink then
    local ok, link = pcall(C_Item.GetItemLink, location)
    if ok and link then return link end
  end

  -- 2) If it's an equipment slot id, use the legacy inventory API
  if type(location) == "number" and GetInventoryItemLink then
    local ok, link = pcall(GetInventoryItemLink, "player", location)
    if ok and link then return link end
  end

  -- 3) If it's a bag location (either our table or an ItemLocation with accessors), use container API
  local bag, slot = nil, nil
  if type(location) == "table" then
    bag, slot = location.bagID, location.slotIndex
    if (not bag or not slot) and type(location.GetBagAndSlot) == "function" then
      local ok, b, s = pcall(location.GetBagAndSlot, location)
      if ok then bag, slot = b, s end
    end
    if bag ~= nil and slot ~= nil and C_Container and C_Container.GetContainerItemLink then
      local ok, link = pcall(C_Container.GetContainerItemLink, bag, slot)
      if ok and link then return link end
    end
  end

  -- 4) As a last resort, request a load then retry C_Item.GetItemLink once more
  if C_Item and C_Item.RequestLoadItemData and C_Item.DoesItemExist and C_Item.GetItemLink then
    local okExist = pcall(C_Item.DoesItemExist, location)
    if okExist then pcall(C_Item.RequestLoadItemData, location) end
    local ok, link = pcall(C_Item.GetItemLink, location)
    if ok and link then return link end
  end

  return nil
end
