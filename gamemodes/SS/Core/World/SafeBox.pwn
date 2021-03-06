#include <YSI\y_hooks>


#define DIRECTORY_SAFEBOX	DIRECTORY_MAIN"Safebox/"
#define MAX_SAFEBOX			ITM_MAX
#define MAX_SAFEBOX_TYPE	(8)
#define MAX_SAFEBOX_NAME	(32)


enum E_SAFEBOX_TYPE_DATA
{
ItemType:	box_itemtype,
			box_size
}

enum
{
			E_BOX_LEGACY_NULL,
			E_BOX_CONTAINER_ID,
			E_BOX_GEID
}


static
			box_GEID_Index,
			box_GEID[MAX_SAFEBOX],
			box_SkipGEID,
			box_TypeData[MAX_SAFEBOX_TYPE][E_SAFEBOX_TYPE_DATA],
			box_TypeTotal,
			box_ItemTypeBoxType[ITM_MAX_TYPES] = {-1, ...},
			box_ContainerSafebox[CNT_MAX];

static
			box_CurrentBoxItem[MAX_PLAYERS],
			box_PickUpTick[MAX_PLAYERS],
Timer:		box_PickUpTimer[MAX_PLAYERS];

static
			box_ItemList[ITM_LST_OF_ITEMS(12)];

// Settings: Prefixed camel case here and dashed in settings.json
static
bool:		box_PrintEachLoad,
bool:		box_PrintTotalLoad,
bool:		box_PrintEachSave,
bool:		box_PrintTotalSave,
bool:		box_PrintRemoves;

static HANDLER = -1;


/*==============================================================================

	Zeroing

==============================================================================*/


hook OnScriptInit()
{
	print("\n[OnScriptInit] Initialising 'SafeBox'...");

	if(box_GEID_Index > 0)
	{
		printf("ERROR: box_GEID_Index has been modified prior to loading from "GEID_FILE". This variable can NOT be modified before being assigned a value from this file.");
		for(;;){}
	}

	DirectoryCheck(DIRECTORY_SCRIPTFILES DIRECTORY_SAFEBOX);

	for(new i; i < CNT_MAX; i++)
		box_ContainerSafebox[i] = INVALID_ITEM_ID;

	HANDLER = debug_register_handler("safebox", 4);

	GetSettingInt("safebox/print-each-load", false, box_PrintEachLoad);
	GetSettingInt("safebox/print-total-load", true, box_PrintTotalLoad);
	GetSettingInt("safebox/print-each-save", false, box_PrintEachSave);
	GetSettingInt("safebox/print-total-save", true, box_PrintTotalSave);
	GetSettingInt("safebox/print-removes", false, box_PrintRemoves);
}

hook OnGameModeInit()
{
	print("\n[OnGameModeInit] Initialising 'SafeBox'...");

	LoadSafeBoxes();
}

hook OnPlayerConnect(playerid)
{
	box_CurrentBoxItem[playerid] = INVALID_ITEM_ID;
}


/*==============================================================================

	Core

==============================================================================*/


DefineSafeboxType(ItemType:itemtype, size)
{
	if(box_TypeTotal == MAX_SAFEBOX_TYPE)
		return -1;

	SetItemTypeMaxArrayData(itemtype, 2);

	box_TypeData[box_TypeTotal][box_itemtype]	= itemtype;
	box_TypeData[box_TypeTotal][box_size]		= size;

	box_ItemTypeBoxType[itemtype] = box_TypeTotal;

	return box_TypeTotal++;
}


/*==============================================================================

	Internal

==============================================================================*/


public OnItemCreate(itemid)
{
	new ItemType:itemtype = GetItemType(itemid);

	if(box_ItemTypeBoxType[itemtype] != -1)
	{
		if(itemtype == box_TypeData[box_ItemTypeBoxType[itemtype]][box_itemtype])
		{
			new
				name[ITM_MAX_NAME],
				containerid;

			GetItemTypeName(itemtype, name);

			containerid = CreateContainer(name, box_TypeData[box_ItemTypeBoxType[itemtype]][box_size], .virtual = 1);

			box_ContainerSafebox[containerid] = itemid;

			if(!box_SkipGEID)
			{
				box_GEID[itemid] = box_GEID_Index;
				box_GEID_Index++;
			}

			SetItemArrayDataSize(itemid, 3);
			SetItemArrayDataAtCell(itemid, containerid, E_BOX_CONTAINER_ID);
			SetItemArrayDataAtCell(itemid, box_GEID[itemid], E_BOX_GEID);
		}
	}

	#if defined box_OnItemCreate
		return box_OnItemCreate(itemid);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnItemCreate
	#undef OnItemCreate
#else
	#define _ALS_OnItemCreate
#endif
 
#define OnItemCreate box_OnItemCreate
#if defined box_OnItemCreate
	forward box_OnItemCreate(itemid);
#endif

public OnItemCreateInWorld(itemid)
{
	new ItemType:itemtype = GetItemType(itemid);

	if(box_ItemTypeBoxType[itemtype] != -1)
	{
		if(itemtype == box_TypeData[box_ItemTypeBoxType[itemtype]][box_itemtype])
			SetButtonText(GetItemButtonID(itemid), "Hold "KEYTEXT_INTERACT" to pick up~n~Press "KEYTEXT_INTERACT" to open");
	}

	#if defined box_OnItemCreateInWorld
		return box_OnItemCreateInWorld(itemid);
	#else
		return 0;
	#endif
}
#if defined _ALS_OnItemCreateInWorld
	#undef OnItemCreateInWorld
#else
	#define _ALS_OnItemCreateInWorld
#endif
#define OnItemCreateInWorld box_OnItemCreateInWorld
#if defined box_OnItemCreateInWorld
	forward box_OnItemCreateInWorld(itemid);
#endif

public OnItemDestroy(itemid)
{
	new ItemType:itemtype = GetItemType(itemid);

	if(box_ItemTypeBoxType[itemtype] != -1)
	{
		if(itemtype == box_TypeData[box_ItemTypeBoxType[itemtype]][box_itemtype])
		{
			new containerid = GetItemArrayDataAtCell(itemid, E_BOX_CONTAINER_ID);

			DestroyContainer(containerid);
			box_ContainerSafebox[containerid] = INVALID_ITEM_ID;

			RemoveSafeboxItem(itemid);
		}
	}

	#if defined box_OnItemDestroy
		return box_OnItemDestroy(itemid);
	#else
		return 0;
	#endif
}
#if defined _ALS_OnItemDestroy
	#undef OnItemDestroy
#else
	#define _ALS_OnItemDestroy
#endif
#define OnItemDestroy box_OnItemDestroy
#if defined box_OnItemDestroy
	forward box_OnItemDestroy(itemid);
#endif


/*==============================================================================

	Player interaction

==============================================================================*/


public OnPlayerPickUpItem(playerid, itemid)
{
	if(SafeBoxInteractionCheck(playerid, itemid))
		return 1;

	#if defined box_OnPlayerPickUpItem
		return box_OnPlayerPickUpItem(playerid, itemid);
	#else
		return 0;
	#endif
}
#if defined _ALS_OnPlayerPickUpItem
	#undef OnPlayerPickUpItem
#else
	#define _ALS_OnPlayerPickUpItem
#endif
#define OnPlayerPickUpItem box_OnPlayerPickUpItem
#if defined box_OnPlayerPickUpItem
	forward box_OnPlayerPickUpItem(playerid, itemid);
#endif

public OnPlayerUseItemWithItem(playerid, itemid, withitemid)
{
	if(SafeBoxInteractionCheck(playerid, withitemid))
		return 1;

	#if defined box_OnPlayerUseItemWithItem
		return box_OnPlayerUseItemWithItem(playerid, itemid, withitemid);
	#else
		return 0;
	#endif
}
#if defined _ALS_OnPlayerUseItemWithItem
	#undef OnPlayerUseItemWithItem
#else
	#define _ALS_OnPlayerUseItemWithItem
#endif
#define OnPlayerUseItemWithItem box_OnPlayerUseItemWithItem
#if defined box_OnPlayerUseItemWithItem
	forward box_OnPlayerUseItemWithItem(playerid, itemid, withitemid);
#endif

SafeBoxInteractionCheck(playerid, itemid)
{
	new ItemType:itemtype = GetItemType(itemid);

	if(!IsValidItemType(itemtype))
		return 0;

	if(box_ItemTypeBoxType[itemtype] == -1)
		return 0;

	if(itemtype != box_TypeData[box_ItemTypeBoxType[itemtype]][box_itemtype])
		return 0;

	box_PickUpTick[playerid] = GetTickCount();
	box_CurrentBoxItem[playerid] = itemid;
	stop box_PickUpTimer[playerid];

	if(!IsValidItem(GetPlayerItem(playerid)) && GetPlayerWeapon(playerid) == 0)
		box_PickUpTimer[playerid] = defer box_PickUp(playerid, itemid);

	return 1;
}

hook OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if(GetPlayerSpecialAction(playerid) == SPECIAL_ACTION_CUFFED)
		return 1;

	if(oldkeys & 16)
	{
		if(GetTickCountDifference(GetTickCount(), box_PickUpTick[playerid]) < 200)
		{
			if(IsValidItem(box_CurrentBoxItem[playerid]))
			{
				DisplayContainerInventory(playerid, GetItemArrayDataAtCell(box_CurrentBoxItem[playerid], 1));
				ApplyAnimation(playerid, "BOMBER", "BOM_PLANT_IN", 4.0, 0, 0, 0, 1, 0);
				stop box_PickUpTimer[playerid];
				box_PickUpTick[playerid] = 0;
			}
		}
	}

	return 1;
}

timer box_PickUp[250](playerid, itemid)
{
	if(IsValidItem(GetPlayerItem(playerid)) || GetPlayerWeapon(playerid) != 0)
		return;

	if(!IsItemInWorld(itemid))
		return;

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid, x, y, z);
	d:1:HANDLER("[box_PickUp] Player %p picked up container %d GEID: %d at %f %f %f", playerid, itemid, box_GEID[itemid], x, y, z);

	PlayerPickUpItem(playerid, itemid);
	RemoveSafeboxItem(itemid);

	box_CurrentBoxItem[playerid] = INVALID_ITEM_ID;

	return;
}

public OnPlayerDroppedItem(playerid, itemid)
{
	if(IsItemTypeSafebox(GetItemType(itemid)))
	{
		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid, x, y, z);
		d:1:HANDLER("[OnPlayerDroppedItem] Player %p dropping and saving container %d (GEID: %d item %d) at %f %f %f", playerid, GetItemArrayDataAtCell(itemid, 1), box_GEID[itemid], itemid, x, y, z);

		SafeboxSaveCheck(playerid, itemid);
	}

	#if defined box_OnPlayerDroppedItem
		return box_OnPlayerDroppedItem(playerid, itemid);
	#else
		return 0;
	#endif
}
#if defined _ALS_OnPlayerDroppedItem
	#undef OnPlayerDroppedItem
#else
	#define _ALS_OnPlayerDroppedItem
#endif
#define OnPlayerDroppedItem box_OnPlayerDroppedItem
#if defined box_OnPlayerDroppedItem
	forward box_OnPlayerDroppedItem(playerid, itemid);
#endif

public OnPlayerCloseContainer(playerid, containerid)
{
	if(IsValidItem(box_CurrentBoxItem[playerid]))
	{
		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid, x, y, z);
		d:1:HANDLER("[OnPlayerCloseContainer] Player %p closing and saving container %d (box GEID: %d, itemid: %d) at %f %f %f", playerid, containerid, box_GEID[box_CurrentBoxItem[playerid]], box_CurrentBoxItem[playerid], x, y, z);

		SafeboxSaveCheck(playerid, box_CurrentBoxItem[playerid]);
		ClearAnimations(playerid);
		box_CurrentBoxItem[playerid] = INVALID_ITEM_ID;
	}

	#if defined box_OnPlayerCloseContainer
		return box_OnPlayerCloseContainer(playerid, containerid);
	#else
		return 0;
	#endif
}
#if defined _ALS_OnPlayerCloseContainer
	#undef OnPlayerCloseContainer
#else
	#define _ALS_OnPlayerCloseContainer
#endif
#define OnPlayerCloseContainer box_OnPlayerCloseContainer
#if defined box_OnPlayerCloseContainer
	forward box_OnPlayerCloseContainer(playerid, containerid);
#endif

SafeboxSaveCheck(playerid, itemid)
{
	new ret = SaveSafeboxItem(itemid);

	if(ret == 0)
	{
		SetItemLabel(itemid, sprintf("SAVED (GEID: %d, itemid: %d)", box_GEID[itemid], itemid), 0xFFFF00FF, 2.0);
	}
	else
	{
		SetItemLabel(itemid, sprintf("NOT SAVED (GEID: %d, itemid: %d)", box_GEID[itemid], itemid), 0xFF0000FF, 2.0);

		if(ret == 1)
			MsgF(playerid, YELLOW, "ERROR: Can't save safebox %d GEID: %d: Not valid item. (Please show Southclaw)", itemid, box_GEID[itemid]);

		if(ret == 2)
			MsgF(playerid, YELLOW, "ERROR: Can't save safebox %d GEID: %d: Item isn't a safebox. (Please show Southclaw)", itemid, box_GEID[itemid]);

		if(ret == 3)
			MsgF(playerid, YELLOW, "ERROR: Can't save safebox %d GEID: %d: Item not in world. (Please show Southclaw)", itemid, box_GEID[itemid]);

		if(ret == 4)
			MsgF(playerid, YELLOW, "ERROR: Container is empty, removing file (GEID: %d itemid: %d) (If the container was NOT empty, please show Southclaw)", box_GEID[itemid], itemid);

		if(ret == 5)
			MsgF(playerid, YELLOW, "ERROR: Can't save safebox %d GEID: %d: Not valid container (%d). (Please show Southclaw)", itemid, box_GEID[itemid], GetItemArrayDataAtCell(itemid, 1));
	}
}


/*==============================================================================

	Load All

==============================================================================*/


LoadSafeBoxes()
{
	new
		dir:direc = dir_open(DIRECTORY_SCRIPTFILES DIRECTORY_SAFEBOX),
		item[46],
		type,
		filename[64],
		count;

	while(dir_list(direc, item, type))
	{
		if(type == FM_FILE)
		{
			filename = DIRECTORY_SAFEBOX;
			strcat(filename, item);

			count += LoadSafeboxItem(filename);
		}
	}

	dir_close(direc);

	if(box_PrintTotalLoad)
		printf("Loaded %d Safeboxes", count);
}


/*==============================================================================

	Save and Load Individual

==============================================================================*/


SaveSafeboxItem(itemid, active = 1)
{
	if(!IsValidItem(itemid))
	{
		printf("[SaveSafeboxItem] ERROR: Can't save safebox %d GEID: %d: Not valid item.", itemid, box_GEID[itemid]);
		return 1;
	}

	if(!IsItemTypeSafebox(GetItemType(itemid)))
	{
		printf("[SaveSafeboxItem] ERROR: Can't save safebox %d GEID: %d: Item isn't a safebox, type: %d", itemid, box_GEID[itemid], _:GetItemType(itemid));
		return 2;
	}

	if(!IsItemInWorld(itemid))
	{
		d:1:HANDLER("[SaveSafeboxItem] ERROR: Can't save safebox %d GEID: %d: Item not in world.", itemid, box_GEID[itemid]);
		return 3;
	}

	new
		type[2],
		data[6],
		containerid,
		filename[64];

	format(filename, sizeof(filename), ""DIRECTORY_SAFEBOX"box_%010d.dat", box_GEID[itemid]);

	containerid = GetItemArrayDataAtCell(itemid, 1);

	if(IsContainerEmpty(containerid))
	{
		d:1:HANDLER("[SaveSafeboxItem] ERROR: Container is empty, removing file '%s' (GEID: %d itemid: %d)", filename, box_GEID[itemid], itemid);
		fremove(filename);
		return 4;
	}

	if(!IsValidContainer(containerid))
	{
		printf("[SaveSafeboxItem] ERROR: Can't save safebox %d GEID: %d: Not valid container (%d).", itemid, box_GEID[itemid], containerid);
		fremove(filename);
		return 5;
	}

	type[0] = _:GetItemType(itemid);
	type[1] = active;

	modio_push(filename, _T<T,Y,P,E>, 2, type);

	GetItemPos(itemid, Float:data[0], Float:data[1], Float:data[2]);
	GetItemRot(itemid, Float:data[3], Float:data[3], Float:data[3]);
	data[4] = GetItemWorld(itemid);
	data[5] = GetItemInterior(itemid);

	modio_push(filename, _T<W,P,O,S>, 6, data);

	if(active)
	{
		if(box_PrintEachSave)
			printf("\t[SAVE] Safebox GEID %d, type %d at %f, %f, %f, %f", box_GEID[itemid], _:GetItemType(itemid), data[0], data[1], data[2], data[3]);
	}
	else
	{
		if(box_PrintRemoves)
			printf("\t[DELT] Safebox: GEID %d itemid %d", box_GEID[itemid], itemid);
	}

	new
		items[12],
		itemcount,
		itemlist;

	for(new i, j = GetContainerSize(containerid); i < j; i++)
	{
		items[i] = GetContainerSlotItem(containerid, i);

		if(!IsValidItem(items[i]))
			break;

		itemcount++;
	}

	itemlist = CreateItemList(items, itemcount);
	GetItemList(itemlist, box_ItemList);

	modio_push(filename, _T<I,T,E,M>, GetItemListSize(itemlist), box_ItemList);

	DestroyItemList(itemlist);

	return 0;
}

LoadSafeboxItem(filename[])
{
	new
		geid,
		length,
		type[2],
		data[6],
		itemid,
		containerid;

	if(sscanf(filename, "'"DIRECTORY_SAFEBOX"box_'p<.>d{s[5]}", geid))
	{
		printf("[LoadSafeboxItem] ERROR: Rogue file detected ('%s') in safebox directory.", filename);
		return 0;
	}

	length = modio_read(filename, _T<T,Y,P,E>, 2, type, false, false);

	if(length == 0)
	{
		printf("[LoadSafeboxItem] ERROR: Safebox data length is 0 (file: %s)", filename);
		return 0;
	}

	if(length == 2)
	{
		if(type[1] == 0)
		{
			d:1:HANDLER("[LoadSafeboxItem] ERROR: Safebox set to inactive (file: %s)", filename);
			return 0;
		}
	}

	if(!IsItemTypeSafebox(ItemType:type[0]))
	{
		printf("[LoadSafeboxItem] ERROR: Safebox type (%d) is invalid (file: %s)", type[0], filename);
		return 0;
	}

	modio_read(filename, _T<W,P,O,S>, sizeof(data), _:data, false, false);

	if(Float:data[0] == 0.0 && Float:data[1] == 0.0 && Float:data[2] == 0.0)
	{
		printf("[LoadSafeboxItem] ERROR: Safebox position is %f %f %f (file: %s)", data[0], data[1], data[2], filename);
		return 0;
	}

	box_SkipGEID = true;
	itemid = CreateItem(ItemType:type[0], Float:data[0], Float:data[1], Float:data[2], .rz = Float:data[3], .world = data[4], .interior = data[5], .zoffset = FLOOR_OFFSET);
	box_SkipGEID = false;

	box_GEID[itemid] = geid;

	containerid = GetItemArrayDataAtCell(itemid, 1);

	if(box_GEID[itemid] > box_GEID_Index)
		box_GEID_Index = box_GEID[itemid] + 1;

	if(box_PrintEachLoad)
		printf("\t[LOAD] Safebox: GEID %d, type %d, at %f, %f, %f", box_GEID[itemid], type[0], data[0], data[1], data[2]);

	new
		ItemType:itemtype,
		itemlist;

	length = modio_read(filename, _T<I,T,E,M>, sizeof(box_ItemList), box_ItemList, true);

	itemlist = ExtractItemList(box_ItemList, length);

	for(new i, j = GetItemListItemCount(itemlist); i < j; i++)
	{
		itemtype = GetItemListItem(itemlist, i);

		if(length == 0)
			break;

		if(itemtype == INVALID_ITEM_TYPE)
			break;

		if(itemtype == ItemType:0)
			break;

		itemid = CreateItem(itemtype);

		if(!IsItemTypeSafebox(itemtype) && !IsItemTypeBag(itemtype))
			SetItemArrayDataFromListItem(itemid, itemlist, i);

		AddItemToContainer(containerid, itemid);
	}

	DestroyItemList(itemlist);

	return 1;
}

RemoveSafeboxItem(itemid)
{
	new filename[64];

	format(filename, sizeof(filename), ""DIRECTORY_SAFEBOX"box_%010d.dat", box_GEID[itemid]);

	SaveSafeboxItem(itemid, 0);

	return 1;
}


/*==============================================================================

	Interface

==============================================================================*/


stock IsItemTypeSafebox(ItemType:itemtype)
{
	if(!IsValidItemType(itemtype))
		return 0;

	if(box_ItemTypeBoxType[itemtype] != -1)
		return 1;

	return 0;
}

stock GetContainerSafeboxItem(containerid)
{
	if(!IsValidContainer(containerid))
		return INVALID_ITEM_ID;

	return box_ContainerSafebox[containerid];
}

stock IsItemTypeExtraDataDependent(ItemType:itemtype)
{
	if(IsItemTypeBag(itemtype))
		return 1;

	if(IsItemTypeSafebox(itemtype))
		return 1;

	if(itemtype == item_Campfire)
		return 1;

	return 0;
}
