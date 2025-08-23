local addonName, XIVEquip = ...
XIVEquip = XIVEquip or {}
local Const = {}
XIVEquip.Const = Const

Const.ARMOR_SLOTS = { 1,2,3,5,6,7,8,9,10,15, 11,12, 13,14 } -- head..cloak, rings x2, trinkets x2
Const.JEWELRY     = { [2]=true, [15]=true, [11]=true, [12]=true, [13]=true, [14]=true }

Const.LOWER_ILVL_ARMOR   = 20
Const.LOWER_ILVL_JEWELRY = 40

Const.INV_BY_EQUIPLOC = {
  INVTYPE_HEAD=1, INVTYPE_NECK=2, INVTYPE_SHOULDER=3, INVTYPE_BODY=4, INVTYPE_CHEST=5, INVTYPE_ROBE=5,
  INVTYPE_WAIST=6, INVTYPE_LEGS=7, INVTYPE_FEET=8, INVTYPE_WRIST=9, INVTYPE_HAND=10,
  INVTYPE_FINGER=11, INVTYPE_TRINKET=13, INVTYPE_CLOAK=15, INVTYPE_HOLDABLE=17, INVTYPE_SHIELD=17,
}

Const.SLOT_EQUIPLOCS = {
  [1]  = { INVTYPE_HEAD=true },   [2]  = { INVTYPE_NECK=true },   [3]  = { INVTYPE_SHOULDER=true },
  [5]  = { INVTYPE_CHEST=true, INVTYPE_ROBE=true },              [6]  = { INVTYPE_WAIST=true },
  [7]  = { INVTYPE_LEGS=true },   [8]  = { INVTYPE_FEET=true },   [9]  = { INVTYPE_WRIST=true },
  [10] = { INVTYPE_HAND=true },   [15] = { INVTYPE_CLOAK=true },
  [11] = { INVTYPE_FINGER=true }, [12] = { INVTYPE_FINGER=true },
  [13] = { INVTYPE_TRINKET=true },[14] = { INVTYPE_TRINKET=true },
}

Const.ITEMCLASS_ARMOR = 4

Const.SLOT_LABEL = {
  [1]="Head", [2]="Neck", [3]="Shoulder", [5]="Chest", [6]="Waist",
  [7]="Legs", [8]="Feet", [9]="Wrist", [10]="Hands", [11]="Ring 1",
  [12]="Ring 2", [13]="Trinket 1", [14]="Trinket 2", [15]="Back",
  [16] = "Main Hand", [17] = "Off Hand"
}
