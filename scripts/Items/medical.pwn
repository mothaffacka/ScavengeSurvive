#include <YSI\y_hooks>


#define HEAL_PROGRESS_MAX (40.0)
#define REVIVE_PROGRESS_MAX (80.0)


new
Timer:		gPlayerHealTimer[MAX_PLAYERS],
Float:		gPlayerHealProgress[MAX_PLAYERS],
			gPlayerHealTarget[MAX_PLAYERS],
Bit1:		gPlayerUsingHeal<MAX_PLAYERS>;


hook OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	new ItemType:itemtype = GetItemType(GetPlayerItem(playerid));

	if(itemtype == item_Medkit || itemtype == item_Bandage || itemtype == item_DoctorBag)
	{
		if(newkeys == 16)
		{
			if(bPlayerGameSettings[playerid] & KnockedOut)
				return 0;

			gPlayerHealTarget[playerid] = playerid;
			foreach(new i : Character)
			{
				if(IsPlayerInPlayerArea(playerid, i) && !IsPlayerInAnyVehicle(i))
					gPlayerHealTarget[playerid] = i;
			}
			PlayerStartHeal(playerid, gPlayerHealTarget[playerid]);
		}
		if(oldkeys == 16)
		{
			PlayerStopHeal(playerid);
		}
	}
	return 1;
}


PlayerStartHeal(playerid, target)
{
	Bit1_Set(gPlayerUsingHeal, playerid, true);
	gPlayerHealProgress[playerid] = 0.0;
	gPlayerHealTarget[playerid] = target;
	SetPlayerProgressBarMaxValue(playerid, ActionBar, HEAL_PROGRESS_MAX);
	SetPlayerProgressBarValue(playerid, ActionBar, 0.0);

	if(target != playerid)
	{
		SetPlayerProgressBarMaxValue(target, ActionBar, HEAL_PROGRESS_MAX);
		SetPlayerProgressBarValue(target, ActionBar, 0.0);

		if(bPlayerGameSettings[target] & KnockedOut)
			ApplyAnimation(playerid, "MEDIC", "CPR", 4.0, 1, 0, 0, 0, 0);

		else
			ApplyAnimation(playerid, "PED", "ATM", 4.0, 1, 0, 0, 0, 0);

		gPlayerHealTimer[playerid] = repeat HealHealUpdate(playerid);
	}
	else
	{
		ApplyAnimation(playerid, "SWEET", "Sweet_injuredloop", 4.0, 1, 0, 0, 0, 0);
		gPlayerHealTimer[playerid] = repeat HealHealUpdate(playerid);
	}
}

PlayerStopHeal(playerid)
{
	stop gPlayerHealTimer[playerid];

	if(Bit1_Get(gPlayerUsingHeal, playerid))
	{
		Bit1_Set(gPlayerUsingHeal, playerid, false);
		HidePlayerProgressBar(playerid, ActionBar);

		if(gPlayerHealTarget[playerid] != playerid)
			HidePlayerProgressBar(gPlayerHealTarget[playerid], ActionBar);

		ClearAnimations(playerid);
	}
}

timer HealHealUpdate[100](playerid)
{
	new	Float:progresscap = HEAL_PROGRESS_MAX;

	gPlayerHealProgress[playerid] += 1.0;
	
	if(gPlayerHealTarget[playerid] != playerid)
	{
		if(bPlayerGameSettings[gPlayerHealTarget[playerid]] & KnockedOut)
			progresscap = REVIVE_PROGRESS_MAX;

		new
			Float:x1,
			Float:y1,
			Float:z1,
			Float:x2,
			Float:y2,
			Float:z2;

		GetPlayerPos(playerid, x1, y1, z1);
		GetPlayerPos(gPlayerHealTarget[playerid], x2, y2, z2);
		SetPlayerFacingAngle(playerid, GetAngleToPoint(x1, y1, x2, y2));

		SetPlayerProgressBarMaxValue(gPlayerHealTarget[playerid], ActionBar, progresscap);
		SetPlayerProgressBarValue(gPlayerHealTarget[playerid], ActionBar, gPlayerHealProgress[playerid]);
		ShowPlayerProgressBar(gPlayerHealTarget[playerid], ActionBar);

	}

	SetPlayerProgressBarMaxValue(playerid, ActionBar, progresscap);
	SetPlayerProgressBarValue(playerid, ActionBar, gPlayerHealProgress[playerid]);
	ShowPlayerProgressBar(playerid, ActionBar);


	if(gPlayerHealProgress[playerid] >= progresscap)
	{
		PlayerStopHeal(playerid);

		if(gPlayerHealTarget[playerid] != playerid)
		{
			if(bPlayerGameSettings[gPlayerHealTarget[playerid]] & KnockedOut)
			{
				WakeUpPlayer(gPlayerHealTarget[playerid]);
			}
		}

		new
			itemid,
			ItemType:itemtype;

		itemid = GetPlayerItem(playerid);
		itemtype = GetItemType(itemid);

		if(itemtype == item_Medkit)
			GivePlayerHP(gPlayerHealTarget[playerid], 40.0);

		if(itemtype == item_Bandage)
			GivePlayerHP(gPlayerHealTarget[playerid], 20.0);

		if(itemtype == item_DoctorBag)
			GivePlayerHP(gPlayerHealTarget[playerid], 70.0);

		f:bPlayerGameSettings[gPlayerHealTarget[playerid]]<Bleeding>;
		DestroyItem(GetPlayerItem(playerid));

		gPlayerHealTarget[playerid] = INVALID_PLAYER_ID;
	}
}