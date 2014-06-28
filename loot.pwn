#include <a_samp>
#include <a_mysql>
#include <streamer>
#include <YSI\y_iterate>

// =============== Definitions =============== //

#define Callback:%0(%1) \
	forward %0(%1); \
	public %0(%1)

#define MAX_LOOTS (500)
#define MAX_LOOT_DESCRIPTION (32)

// =============== MySQL =============== //
#define SQL_HOST 	"de.linuxthefish.net"
#define SQL_DB		"pds2"
#define SQL_USER	"pds2"
#define SQL_PASS	"faW6LbgriZhmXOtXf4"

// =============== Tables =============== //
#define LOOTS_TABLE "Loots"

#define LOOT_INDEX_ID 		"ID" 			// 00
#define LOOT_MODEL_ID		"ModelID"		// 01
#define LOOT_DESCRIPTION 	"Description"  	// 02
#define LOOT_POSITION_X 	"lootX" 			// 03
#define LOOT_POSITION_Y 	"lootY" 			// 04
#define LOOT_POSITION_Z 	"lootZ" 			// 05
#define LOOT_INTERIOR_ID 	"InteriorID"	// 06
#define LOOT_VIRTUAL_ID		"VirtualID"		// 07


// =============== Declarations =============== //

enum e_lootInfo
{
	lootID,
	lootModelID,
	lootDesc[MAX_LOOT_DESCRIPTION],
	Float:lootPos[3],
	lootIntID,
	lootVWID,

	//Does not save
	lootObjectID,
	Text3D:ObjectLabel
}

new 
	lootInfo[MAX_LOOTS][e_lootInfo],
	Iterator:lootIndex<MAX_LOOTS>,
	SQLHandle;

public OnFilterScriptInit()
{
	mysql_log(LOG_ERROR | LOG_WARNING, LOG_TYPE_HTML);
	SQLHandle = mysql_connect(SQL_HOST, SQL_USER, SQL_DB, SQL_PASS);

	mysql_query(SQLHandle, "CREATE TABLE IF NOT EXISTS "LOOTS_TABLE" (\
		"LOOT_INDEX_ID" SMALLINT(6) NOT NULL DEFAULT '0', \
		"LOOT_MODEL_ID" SMALLINT(6) NOT NULL DEFAULT '0', \
		"LOOT_DESCRIPTION" VARCHAR(32) NOT NULL, \
		"LOOT_POSITION_X" FLOAT NOT NULL DEFAULT '0.0', \
		"LOOT_POSITION_Y" FLOAT NOT NULL DEFAULT '0.0', \
		"LOOT_POSITION_Z" FLOAT NOT NULL DEFAULT '0.0', \
		"LOOT_INTERIOR_ID" INT(11) NOT NULL DEFAULT '0', \
		"LOOT_VIRTUAL_ID"  INT(11) NOT NULL DEFAULT '0')", false);

	mysql_tquery(SQLHandle, "SELECT * FROM "LOOTS_TABLE"", "OnLootsLoad", "");
	return true;
}

public OnFilterScriptExit()
{
	mysql_close(SQLHandle);
	return true;
}

Callback:OnLootsLoad()
{	
	new 
		rows = cache_num_rows(),
		id, 
		objectid,
		Description[MAX_LOOT_DESCRIPTION],
		Float:Pos[3],
		InteriorID,
		WorldID;

	for(new i = 0; i < rows; ++i)
	{
		id = cache_get_field_content_int(i, LOOT_INDEX_ID, SQLHandle);
		objectid = cache_get_field_content_int(i, LOOT_MODEL_ID, SQLHandle);
		cache_get_field_content(i, LOOT_DESCRIPTION, Description, SQLHandle, MAX_LOOT_DESCRIPTION);
		Pos[0] = cache_get_field_content_float(i, LOOT_POSITION_X, SQLHandle);
		Pos[1] = cache_get_field_content_float(i, LOOT_POSITION_Y, SQLHandle);
		Pos[2] = cache_get_field_content_float(i, LOOT_POSITION_Z, SQLHandle);
		InteriorID = cache_get_field_content_int(i, LOOT_INTERIOR_ID, SQLHandle);
		WorldID = cache_get_field_content_int(i, LOOT_VIRTUAL_ID, SQLHandle);

		CreateDynamicLoot(id, objectid, Description, Pos[0], Pos[1], Pos[2], InteriorID, WorldID);
		printf("%i, %i, %s, %.4f, %.4f, %.4f, %i, %i", id, objectid, Description, Pos[0], Pos[1], Pos[2], InteriorID, WorldID);
	}
	return true;
}

AddDynamicLoot(objectid, label[MAX_LOOT_DESCRIPTION], Float:X, Float:Y, Float:Z, InteriorID = -1, WorldID = -1)
{

	new 
		id = Iter_Free(lootIndex),
		string[256];

	if(Iter_Count(lootIndex) == -1)
		return print("ERROR: MAX_LOOTS reached, increase the limit size.");

	mysql_format(SQLHandle, string, sizeof(string), "INSERT INTO "LOOTS_TABLE"\
		("LOOT_INDEX_ID", "LOOT_MODEL_ID", "LOOT_DESCRIPTION", "LOOT_POSITION_X", "LOOT_POSITION_Y", "LOOT_POSITION_Z", "LOOT_INTERIOR_ID", "LOOT_VIRTUAL_ID") \
		VALUES (%i, %i, '%e', %.4f, %.4f, %.4f, %i, %i)", id, objectid, label, X, Y, Z, InteriorID, WorldID);
	mysql_tquery(SQLHandle, string, "", "");

	CreateDynamicLoot(id, objectid, label, X, Y, Z, InteriorID, WorldID);
}

DeleteDynamicLoot(LootID, deleterid = INVALID_PLAYER_ID)
{
	new
		string[128];

	mysql_format(SQLHandle, string, sizeof(string), "SELECT * FROM "LOOTS_TABLE" WHERE "LOOT_INDEX_ID" = %i", LootID);
	mysql_tquery(SQLHandle, string, string, "OnDeleteLoot", LootID, deleterid);
}

Callback:OnDeleteLoot(LootID, deleterid)
{
	new 
		rows = cache_num_rows(),
		string[128];

	if(rows)
	{
		mysql_format(SQLHandle, string, sizeof(string), "DELETE * FROM "LOOTS_TABLE" WHERE "LOOT_INDEX_ID" = %i", lootID);
		mysql_tquery(SQLHandle, string, "", "");

		DestroyDynamicObject(lootInfo[lootID][lootObjectID]);
		DestroyDynamic3DTextLabel(lootInfo[lootID][ObjectLabel]);
		
		Iter_Remove(lootIndex, lootID);
		printf("PlayerID: %i successfully deleted LootID: %i", deleterid, lootID);
	}
	else
	{
		printf("PlayerID: %i tried to delete invalid LootID: %i", deleterid, lootID);
	}
	return true;
}

CreateDynamicLoot(id, objectid, label[MAX_LOOT_DESCRIPTION], Float:X, Float:Y, Float:Z, InteriorID = -1, WorldID = -1)
{

	if(Iter_Count(lootIndex) == -1)
		return print("ERROR: MAX_LOOTS reached, increase the limit size.");

	if(lootInfo[id][lootDesc][0] != EOS)
	{
		lootInfo[id][lootDesc][0] = EOS;
	}

	strcat(lootInfo[id][lootDesc], label, MAX_LOOT_DESCRIPTION);
	lootInfo[id][lootModelID] = objectid;	
	lootInfo[id][lootPos][0] = X;
	lootInfo[id][lootPos][1] = Y;
	lootInfo[id][lootPos][2] = Z;
	lootInfo[id][lootIntID] = InteriorID;
	lootInfo[id][lootVWID] = WorldID;

	lootInfo[id][lootObjectID] = CreateDynamicObject(
			objectid, 
			lootInfo[id][lootPos][0],
			lootInfo[id][lootPos][1],
			lootInfo[id][lootPos][2]-1,
		 	0.0, 
		 	0.0, 
		 	0.0, 
		 	lootInfo[id][lootVWID],
		 	lootInfo[id][lootIntID], 
		 	INVALID_PLAYER_ID, 
		 	200.0, 
		 	0.0
	 	);

	lootInfo[id][ObjectLabel] = CreateDynamic3DTextLabel(
		label, 
		0xFFAA00FF, 
		lootInfo[id][lootPos][0],
		lootInfo[id][lootPos][1],
		lootInfo[id][lootPos][2]-0.50,
		5.0, 
		INVALID_PLAYER_ID, 
		INVALID_VEHICLE_ID, 
		1,
	 	lootInfo[id][lootVWID],
	 	lootInfo[id][lootIntID], 
		INVALID_PLAYER_ID,
		5.0);

	Iter_Add(lootIndex, id);
	return true;
}
