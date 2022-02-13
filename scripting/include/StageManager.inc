#if defined _stagemanager_included
	#endinput
#endif
#define _stagemanager_included

enum
{
	MATH_STAGE_VALUE,
	OTHER_STAGE,
	TRIGGER,
	TRIGGER_LEVEL,
	
	INT_DATA_TOTAL
}
enum
{
	STAGE_NAME,
	TARGET_TRIGGER,
	TARGET_TRIGGER_OUTPUT,
	TARGET_TRIGGER_LEVEL,
	TARGET_TRIGGER_LEVEL_OUTPUT,
	
	CHAR_DATA_TOTAL
}
	
native int StageManager_GetStages();
native int StageManager_GetCurrentStage();
native void StageManager_GetStageName(int iStage, char[] buffer, int size);
native void StageManager_GetCurrentStageName(char[] buffer, int size);
native int StageManager_IsLegitWin();

forward void StageManager_OnMapBeaten()
forward void StageManager_OnStageChanged(int iCurrentStage, int iLastStage, const char[] Name)

public SharedPlugin __pl_StageManager =
{
	name = "StageManager",
	file = "StageManager.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_StageManager_SetNTVOptional()
{
	MarkNativeAsOptional("StageManager_GetStages");
	MarkNativeAsOptional("StageManager_GetCurrentStage");
	MarkNativeAsOptional("StageManager_GetStageName");
	MarkNativeAsOptional("StageManager_GetCurrentStageName");
	MarkNativeAsOptional("StageManager_IsLegitWin");
}
#endif