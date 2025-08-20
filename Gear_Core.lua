-- Gear_Core.lua
local addonName, XIVEquip = ...
local Core = {}
XIVEquip.Gear_Core = Core

-- =========================
-- Public constants/lookups (unchanged)
-- =========================

Core.ARMOR_SLOTS = { 1,2,3,5,6,7,8,9,10,15, 11,12, 13,14 } -- head..cloak, rings x2, trinkets x2
Core.JEWELRY     = { [2]=true, [15]=true, [11]=true, [12]=true, [13]=true, [14]=true }

Core.LOWER_ILVL_ARMOR   = 20
Core.LOWER_ILVL_JEWELRY = 40

Core.INV_BY_EQUIPLOC = {
  INVTYPE_HEAD=1, INVTYPE_NECK=2, INVTYPE_SHOULDER=3, INVTYPE_BODY=4, INVTYPE_CHEST=5, INVTYPE_ROBE=5,
  INVTYPE_WAIST=6, INVTYPE_LEGS=7, INVTYPE_FEET=8, INVTYPE_WRIST=9, INVTYPE_HAND=10,
  INVTYPE_FINGER=11, INVTYPE_TRINKET=13, INVTYPE_CLOAK=15, INVTYPE_HOLDABLE=17, INVTYPE_SHIELD=17,
}

Core.SLOT_EQUIPLOCS = {
  [1]  = { INVTYPE_HEAD=true },   [2]  = { INVTYPE_NECK=true },   [3]  = { INVTYPE_SHOULDER=true },
  [5]  = { INVTYPE_CHEST=true, INVTYPE_ROBE=true },              [6]  = { INVTYPE_WAIST=true },
  [7]  = { INVTYPE_LEGS=true },   [8]  = { INVTYPE_FEET=true },   [9]  = { INVTYPE_WRIST=true },
  [10] = { INVTYPE_HAND=true },   [15] = { INVTYPE_CLOAK=true },
  [11] = { INVTYPE_FINGER=true }, [12] = { INVTYPE_FINGER=true },
  [13] = { INVTYPE_TRINKET=true },[14] = { INVTYPE_TRINKET=true },
}

Core.ITEMCLASS_ARMOR = 4

Core.SLOT_LABEL = {
  [1]="Head", [2]="Neck", [3]="Shoulder", [5]="Chest", [6]="Waist",
  [7]="Legs", [8]="Feet", [9]="Wrist", [10]="Hands", [11]="Ring 1",
  [12]="Ring 2", [13]="Trinket 1", [14]="Trinket 2", [15]="Back",
  [16] = "Main Hand", [17] = "Off Hand"
}

-- =========================
-- Public helpers (logic unchanged)
-- =========================

function Core.ItemInstanceKey(itemLoc)
  if C_Item and C_Item.GetItemGUID and itemLoc then
    local ok, guid = pcall(C_Item.GetItemGUID, itemLoc)
    if ok and guid and guid ~= "" then return guid end
  end
  local link = C_Item and C_Item.GetItemLink and C_Item.GetItemLink(itemLoc)
  local id = link and tonumber(link:match("|Hitem:(%d+)"))
  local bag, slot = itemLoc and itemLoc.bagID, itemLoc and itemLoc.slotIndex
  return table.concat({id or 0, bag or -1, slot or -1}, ":")
end

function Core.itemGUID(loc)
  if C_Item and C_Item.GetItemGUID and loc then
    local ok, guid = pcall(C_Item.GetItemGUID, loc)
    if ok then return guid end
  end
  return nil
end

function Core.getItemLevelFromLink(link)
  if not link then return 0 end
  local il = select(4, GetItemInfo(link))
  if il and il > 0 then return il end
  local _, _, _, iLvl = GetItemInfoInstant(link)
  return iLvl or 0
end

-- Read currently equipped for a slot (unchanged logic)
function Core.equippedBasics(slotID, comparer)
  local loc = ItemLocation:CreateFromEquipmentSlot(slotID)
  if not (loc and C_Item.DoesItemExist and C_Item.DoesItemExist(loc)) then return nil end

  local link = GetInventoryItemLink("player", slotID)
  if not link and C_Item.GetItemLink then link = C_Item.GetItemLink(loc) end

  local ilvl = 0
  if C_Item.GetCurrentItemLevel then ilvl = C_Item.GetCurrentItemLevel(loc) or 0 end
  if ilvl == 0 then ilvl = Core.getItemLevelFromLink(link) end

  local equipLoc = link and select(9, GetItemInfo(link)) or nil

  local score = nil
  if comparer and comparer.ScoreItem then
    local ok, v = pcall(comparer.ScoreItem, loc, slotID)
    if ok and type(v)=="number" then score = v end
  end

  return { loc=loc, slot=slotID, link=link, ilvl=ilvl, score=score, equipLoc=equipLoc }
end

-- Equip a bag item into a specific slot (unchanged logic)
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

function Core.equipLocMatchesSlot(equipLoc, slotID)
  local allowed = Core.SLOT_EQUIPLOCS[slotID]
  return allowed and allowed[equipLoc] or false
end

function Core.playerArmorSubclass()
  local class = select(2, UnitClass("player"))
  local map = {
    WARRIOR=4, PALADIN=4, DEATHKNIGHT=4,
    HUNTER=3, SHAMAN=3, EVOKER=3,
    ROGUE=2, MONK=2, DEMONHUNTER=2, DRUID=2,
    MAGE=1, PRIEST=1, WARLOCK=1,
  }
  return map[class]
end

-- =========================
-- Selection primitive
-- =========================

do
  -- Local aliases
  local equippedBasics       = Core.equippedBasics
  local equipLocMatchesSlot  = Core.equipLocMatchesSlot
  local getItemLevelFromLink = Core.getItemLevelFromLink
  local itemGUID             = Core.itemGUID
  local JEWELRY              = Core.JEWELRY
  local LOWER_ILVL_ARMOR     = Core.LOWER_ILVL_ARMOR
  local LOWER_ILVL_JEWELRY   = Core.LOWER_ILVL_JEWELRY

  local EPS = 1e-6

  -- Exported: Core.chooseForSlot (slot-agnostic; works for jewelry as-is)
  function Core.chooseForSlot(comparer, slotID, expectedArmorSubclass, used)
    local equipped = equippedBasics(slotID, comparer)
    local equippedIlvl   = (equipped and equipped.ilvl) or 0
    local equippedScore  = (equipped and equipped.score) or nil
    local lowerBound     = JEWELRY[slotID] and LOWER_ILVL_JEWELRY or LOWER_ILVL_ARMOR

    local best = nil

    for bag = 0, NUM_BAG_SLOTS do
      local num = C_Container.GetContainerNumSlots(bag) or 0
      for slot = 1, num do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID then
          local _, _, _, equipLoc, _, classID, subclassID = GetItemInfoInstant(info.itemID)
          if equipLoc and equipLocMatchesSlot(equipLoc, slotID) then
            local link = info.hyperlink or C_Container.GetContainerItemLink(bag, slot)
            local ilvl = getItemLevelFromLink(link)
            if ilvl >= (equippedIlvl - lowerBound) then
              local itemLoc = ItemLocation:CreateFromBagAndSlot(bag, slot)
              local guid = itemGUID(itemLoc)
              if not (used and guid and used[guid]) then
                local score = nil
                if comparer and comparer.ScoreItem then
                  local ok, v = pcall(comparer.ScoreItem, itemLoc, slotID)
                  if ok and type(v) == "number" then score = v end
                end
                if score and (not best or score > best.score) then
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
          return nil, equipped
        end
      else
        if best.ilvl <= equippedIlvl then
          return nil, equipped
        end
      end
    end

    return best, equipped
  end
end

-- =========================
-- shared helper to append to plan + build a change row
-- =========================
function Core.appendPlanAndChange(plan, changes, slotID, pick, equipped)
  -- Add to plan
  table.insert(plan, pick)

  -- Build the UI change row (exactly the same fields you’re using)
  local oldLink   = (equipped and equipped.link) or "|cff888888(None)|r"
  local newLink   = pick.link or oldLink
  local newScore  = (pick and pick.score) or 0
  local oldScore  = (equipped and equipped.score) or 0
  local newIlvl   = (pick and pick.ilvl) or 0
  local oldIlvl   = (equipped and equipped.ilvl) or 0

  local row = {
    slot        = slotID,
    slotName    = Core.SLOT_LABEL[slotID] or ("Slot "..slotID),
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
function Core.tryChooseAppend(plan, changes, slotID, comparer, expectedArmorSubclass, used)
  local pick, equipped = Core.chooseForSlot(comparer, slotID, expectedArmorSubclass, used)
  if pick then
    Core.appendPlanAndChange(plan, changes, slotID, pick, equipped)
    if pick.guid and used then used[pick.guid] = true end
    return pick, equipped, true
  end
  return nil, equipped, false
end
