#include <YSI\y_hooks>


hook OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if(GetPlayerWeapon(playerid) != 0 && IsValidItem(GetPlayerItem(playerid)))
		return 1;

	if(GetPlayerSpecialAction(playerid) == SPECIAL_ACTION_CUFFED || bPlayerGameSettings[playerid] & AdminDuty || bPlayerGameSettings[playerid] & KnockedOut || GetPlayerAnimationIndex(playerid) == 1381)
		return 1;

	if(newkeys & 16)
	{
		foreach(new i : Player)
		{
			if(IsPlayerInPlayerArea(playerid, i))
			{
				if(bPlayerGameSettings[i] & KnockedOut || GetPlayerAnimationIndex(i) == 1381)
				{
					DisarmPlayer(playerid, i);
				}
			}
		}
	}

	return 1;
}

DisarmPlayer(playerid, i)
{
	new
		weaponid = GetPlayerWeapon(i),
		itemid = GetPlayerItem(i);

	if(weaponid != 0)
	{
		new
			ammo = GetPlayerAmmo(i);

		RemovePlayerWeapon(i);
		SetPlayerWeapon(playerid, weaponid, ammo);

		return 1;
	}
	else
	{
		weaponid = GetPlayerHolsteredWeapon(i);

		if(weaponid != 0)
		{
			new
				ammo = GetPlayerHolsteredWeaponAmmo(i);

			RemovePlayerHolsterWeapon(i);
			SetPlayerWeapon(playerid, weaponid, ammo);

			return 1;
		}
		else if(IsValidItem(itemid))
		{
			RemoveCurrentItem(i);
			GiveWorldItemToPlayer(playerid, itemid);

			return 1;
		}
	}

	return 0;
}