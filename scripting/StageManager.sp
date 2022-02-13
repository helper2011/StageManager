#include <sourcemod>
#include <sdkhooks>
#include <StageManager>
#include <sdktools_entoutput>

#pragma newdecls required

#define DEBUG 0
#define DEBUG_ADMINS 0

const int MAX_STAGES = 15;
	
Handle	
	TriggersTimer[MAX_STAGES];
	
GlobalForward	
	OnStageChanged,
	OnMapBeaten;
	
int
	Stages,
	RealStages,
	MathCounter,
	MathCounterExtreme,
	MathCounterExtremeValue,
	Extreme,
	ChangeTime,
	CurrentStage,
	LastStage,
	CountTypes[2],
	StageDataInt[INT_DATA_TOTAL][MAX_STAGES];
char	

	StageDataChar[CHAR_DATA_TOTAL][MAX_STAGES][64], 
	TargetCounterExtreme[64],
	TargetCounter[64],
	TargetExtreme[64],
	TargetExtremeOutput[64];
	
bool	
	Toggle,
	IsExtreme,
	StageIsBeaten[MAX_STAGES],
	TriggerIsActivated[MAX_STAGES];

float	
	TriggersCD[MAX_STAGES];

#if DEBUG 1
char DebugLogFile[PLATFORM_MAX_PATH];

void DebugMsg(const char[] sMsg, any ...)
{
	static char szBuffer[512];
	VFormat(szBuffer, 512, sMsg, 2);
	LogToFile(DebugLogFile, szBuffer);
	
	#if DEBUG_ADMINS 1
	static int iFlags;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			iFlags = GetUserFlagBits(i);
			
			if(iFlags & ADMFLAG_RCON || iFlags & ADMFLAG_ROOT)
			{
				PrintToConsole(i, szBuffer);
			}
		}
	}
	#endif
}

#define DebugMessage(%0) DebugMsg(%0)

#else
#define DebugMessage(%0)
#endif

public Plugin myinfo = 
{
	name		= "Stage Manager",
	version		= "1.0",
	description	= "",
	author		= "hEl",
	url			= ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("StageManager_GetStages",				Native_GetStages);
	CreateNative("StageManager_GetCurrentStage",		Native_GetCurrentStage);
	CreateNative("StageManager_GetStageName",			Native_GetStageName);
	CreateNative("StageManager_GetCurrentStageName",	Native_GetCurrentStageName);
	CreateNative("StageManager_IsLegitWin",				Native_IsLegitWin);

	RegPluginLibrary("StageManager");
	return APLRes_Success;
}

public int Native_GetStages(Handle hPlugin, int numParams)
{
	return Toggle ? RealStages:-1;
}

public int Native_GetCurrentStage(Handle hPlugin, int numParams)
{
	if(Toggle && CurrentStage != -1)
	{
		return (0 < StageDataInt[OTHER_STAGE][CurrentStage] < 20) ? StageDataInt[OTHER_STAGE][CurrentStage]:(CurrentStage + 1);
	}
	return -1;
}

public int Native_GetCurrentStageName(Handle hPlugin, int numParams)
{
	if(Toggle && CurrentStage != -1)
	{
		SetNativeString(1, StageDataChar[STAGE_NAME][CurrentStage], GetNativeCell(2));
	}
	
}


public int Native_GetStageName(Handle hPlugin, int numParams)
{
	if(Toggle)
	{
		SetNativeString(2, StageDataChar[STAGE_NAME][GetNativeCell(1) - 1], GetNativeCell(3));
	}
}

public int Native_IsLegitWin(Handle hPlugin, int numParams)
{
	return IsLegitWin();
}

public Plugin myinfo = 
{
	name		= "Stage Manager",
	version		= "1.0",
	description	= "Level management on the map",
	author		= "hEl"
}

public void OnPluginStart()
{
	#if DEBUG 1
	BuildPath(Path_SM, DebugLogFile, 256, "logs/StageManager_debug.log");
	#endif
	
	RegAdminCmd("sm_gt",	CMD_GetToggle,			ADMFLAG_RCON);
	RegAdminCmd("sm_gmv",	CMD_GetMathValue,		ADMFLAG_RCON);
	RegAdminCmd("sm_gmv2",	CMD_GetMathValue2,		ADMFLAG_RCON);
	RegAdminCmd("sm_gcs",	CMD_GetCurrentStage,	ADMFLAG_RCON);
	
	HookEvent("round_end",		OnRoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",	OnRoundStart,	EventHookMode_PostNoCopy);
	OnMapBeaten = new GlobalForward("StageManager_OnMapBeaten", ET_Ignore);
	OnStageChanged = new GlobalForward("StageManager_OnStageChanged", ET_Ignore, Param_Cell, Param_Cell, Param_String);
}

public Action CMD_GetToggle(int iC, int iA)
{
	PrintToChat(iC, "%b", Toggle);
}

public Action CMD_GetCurrentStage(int iC, int iA)
{
	if(CurrentStage != -1)
	{
		PrintToChat(iC, "Stage %i [%s] [Legit = %i]", CurrentStage + 1, StageDataChar[STAGE_NAME][CurrentStage], IsLegitWin());
		
	}
	else
	{
		PrintToChat(iC, "Stage not defined");
	}
}


public Action CMD_GetMathValue(int iClient, int iArgs)
{
	if(iClient && !IsFakeClient(iClient))
	{
		PrintToChat(iClient, "[Stage Manager] Current math value = %i", GetCurrentStageValue());
	}
	return Plugin_Handled;
}

public Action CMD_GetMathValue2(int iClient, int iArgs)
{
	if(iClient && !IsFakeClient(iClient) && MathCounterExtreme && IsValidEntity(MathCounterExtreme))
	{
		PrintToChat(iClient, "[Stage Manager] Current math value = %i", GetMathValue(MathCounterExtreme));
	}
	return Plugin_Handled;
}



public void OnRoundStart(Event hEvent, const char[] event, bool bDontBroadcast)
{
	if(Toggle)
	{
		DebugMessage("OnRoundStart")
		ChangeTime = GetTime();
		ClearTriggers();
		SetCurrentStage(0, false, false);
	}
}

public void OnRoundEnd(Event hEvent, const char[] event, bool bDontBroadcast)
{
	DebugMessage("OnRoundEnd")
	ClearEntities();
	CheckBeatMap();
}

public void OnMapStart()
{
	DebugMessage("OnMapStart")
	SetCurrentStage(-1);
	ClearEntities();
	ClearTriggers();
	ClearConfigData();
	char szBuffer[256], szBuffers[3][64];
	GetCurrentMap(szBuffer, 256);
	BuildPath(Path_SM, szBuffer, 256, "configs/stagemanager/%s.cfg", szBuffer);
	KeyValues hKeyValues = new KeyValues("StageManager");
	
	if(!hKeyValues.ImportFromFile(szBuffer))
	{
		delete hKeyValues;
		LogMessage("Config file \"%s\" doesnt exists", szBuffer);
		return;
	}
	
	hKeyValues.GetString("counter", TargetCounter, 64);
	hKeyValues.GetString("counterex", TargetCounterExtreme, 64);
	MathCounterExtremeValue = hKeyValues.GetNum("counterex_value");

	hKeyValues.GetString("extreme", szBuffer, 256);
	ExplodeString(szBuffer, ":", szBuffers, 2, 64);
	TargetExtreme = szBuffers[0];
	TargetExtremeOutput = szBuffers[1];
	
	if(!hKeyValues.GotoFirstSubKey())
	{
		delete hKeyValues;
		return;
	}
	
	do
	{
		StageDataInt[OTHER_STAGE][Stages] = hKeyValues.GetNum("stage");
		StageDataInt[MATH_STAGE_VALUE][Stages] = hKeyValues.GetNum("math_value");
		hKeyValues.GetString("end", szBuffer, 256);
		hKeyValues.GetString("name", StageDataChar[STAGE_NAME][Stages], 256);
		
		if(szBuffer[0])
		{
			
			int iExplodes = ExplodeString(szBuffer, ":", szBuffers, 3, 64);
			if(iExplodes > 1)
			{
				StageDataChar[TARGET_TRIGGER][Stages] = szBuffers[0];
				StageDataChar[TARGET_TRIGGER_OUTPUT][Stages] = szBuffers[1];
				TriggersCD[Stages] = iExplodes > 2 ? StringToFloat(szBuffers[2]):0.0;
			}
			
			
		}
		
		hKeyValues.GetString("start", szBuffer, 256);
		if(szBuffer[0])
		{
			int iExplodes = ExplodeString(szBuffer, ":", szBuffers, 2, 64);
			if(iExplodes > 1)
			{
				StageDataChar[TARGET_TRIGGER_LEVEL][Stages] = szBuffers[0];
				StageDataChar[TARGET_TRIGGER_LEVEL_OUTPUT][Stages] = szBuffers[1];
			}
		}
		if(!StageDataInt[OTHER_STAGE][Stages])
		{
			RealStages++;
		}
		Stages++;
		CountTypes[hKeyValues.GetNum("extreme") ? 1:0]++;
		
	}
	while(hKeyValues.GotoNextKey() && Stages < MAX_STAGES);
	
	delete hKeyValues;
	
	if((Toggle = (Stages > 0)))
	{
		SetCurrentStage(0, false);
	}
	
	ClearEntities();
}

public void OnEntityCreated(int iEntity, const char[] entity)
{
	if(Toggle && IsValidEntity(iEntity))
	{
		SDKHook(iEntity, SDKHook_Spawn, OnEntitySpawned2);
	}
}

public void OnEntitySpawned2(int iEntity)
{
	if(!Toggle || !IsValidEntity(iEntity))
		return;
	
	if(!MathCounter && IsValidTrigger(iEntity, TargetCounter))
	{
		DebugMessage("Math counter #%i spawned.", iEntity)
		MathCounter = iEntity;
		HookSingleEntityOutput(iEntity, "OutValue", OnEntityMathOutput, false);
		GetCurrentStageByMath(false);
		return;
	}
	else if(!MathCounterExtreme && IsValidTrigger(iEntity, TargetCounterExtreme))
	{
		DebugMessage("Math counter extreme #%i spawned.", iEntity)
		MathCounterExtreme = iEntity;
		HookSingleEntityOutput(iEntity, "OutValue", OnEntityMathExOutput, false);
		//GetCurrentStageByMath(false);
		return;
	}
	else if(!Extreme && IsValidTrigger(iEntity, TargetExtreme))
	{
		DebugMessage("Extreme #%i spawned.", iEntity)
		Extreme = iEntity;
		HookSingleEntityOutput(iEntity, TargetExtremeOutput, OnExtremeTriggerOutput, true);
		return;
	}

	
	for(int i; i < Stages; i++)
	{

		if(!StageDataInt[TRIGGER][i] && StageDataChar[TARGET_TRIGGER][i][0] && StageDataChar[TARGET_TRIGGER_OUTPUT][i][0] && IsValidTrigger(iEntity, StageDataChar[TARGET_TRIGGER][i]))
		{
			StageDataInt[TRIGGER][i] = iEntity;
			
			bool bAlready;
			
			for(int j; j < i; j++)
			{
				if(StageDataInt[TRIGGER][j] == iEntity)
				{
					bAlready = true;
					break;
				}
			}
			
			if(!bAlready)
				HookSingleEntityOutput(iEntity, StageDataChar[TARGET_TRIGGER_OUTPUT][i], OnTriggerOutput, true);
			
			DebugMessage("END #%i spawned (S: %i, O: %s). [Current Stage %i]", iEntity, i + 1, StageDataChar[TARGET_TRIGGER_OUTPUT][i], CurrentStage + 1)
		}
		if(!StageDataInt[TRIGGER_LEVEL][i] && StageDataChar[TARGET_TRIGGER_LEVEL][i][0] && StageDataChar[TARGET_TRIGGER_LEVEL_OUTPUT][i][0] && IsValidTrigger(iEntity, StageDataChar[TARGET_TRIGGER_LEVEL][i]))
		{
			StageDataInt[TRIGGER_LEVEL][i] = iEntity;
			HookSingleEntityOutput(iEntity, StageDataChar[TARGET_TRIGGER_LEVEL_OUTPUT][i], OnTriggerLevelOutput, true);
			
			DebugMessage("START #%i spawned (S: %i, O: %s). [Current Stage %i]", iEntity, i + 1, StageDataChar[TARGET_TRIGGER_LEVEL_OUTPUT][i], CurrentStage + 1)
		}
	}
}

public void OnEntityDestroyed(int iEntity)
{
	if(!Toggle)
		return;
	
	if(MathCounter == iEntity)
	{
		DebugMessage("Math #%i removed", iEntity)
		MathCounter = 0;
		return;
	}
	else if(Extreme == iEntity)
	{
		DebugMessage("Extreme #%i removed", iEntity)
		Extreme = 0;
		return;
		
	}
	else if(MathCounterExtreme == iEntity)
	{
		DebugMessage("Math extreme #%i removed", iEntity)
		MathCounterExtreme = 0;
		return;
	}

	for(int i; i < Stages; i++)
	{
		if(StageDataInt[TRIGGER][i] == iEntity)
		{
			StageDataInt[TRIGGER][i] = 0;
		}
		if(StageDataInt[TRIGGER_LEVEL][i] == iEntity)
		{
			StageDataInt[TRIGGER_LEVEL][i] = 0;
		}
	}
}

public void OnTriggerOutput(const char[] output, int caller, int activator, float delay)
{
	DebugMessage("OnTriggerOutput: %s (Caller = %i, Activator = %i, Delay = %f)", output, caller, activator, delay)
	int iStage;
	for(int i; i < Stages; i++)
	{
		if(StageDataInt[TRIGGER][i] != caller || (iStage = (0 < StageDataInt[OTHER_STAGE][i] <= MAX_STAGES) ? (StageDataInt[OTHER_STAGE][i] - 1):i) != CurrentStage)
			continue;
		
		DebugMessage("Trigger #%i activated. [Stage %i]", caller, i + 1)
		if(TriggersCD[i] > 0.0)
		{
			delete TriggersTimer[iStage];
			TriggersTimer[iStage] = CreateTimer(TriggersCD[i], Timer_OnTrigger, iStage);
		}
		else
		{
			StageIsBeaten[iStage] = true;
			TriggerIsActivated[iStage] = true;
		}
	}
}

public void OnExtremeTriggerOutput(const char[] output, int caller, int activator, float delay)
{
	DebugMessage("OnExtremeTriggerOutput: %s (Caller = %i, Activator = %i, Delay = %f)", output, caller, activator, delay)
	IsExtreme = true;
	SetCurrentStage(CurrentStage);
}

public void OnTriggerLevelOutput(const char[] output, int caller, int activator, float delay)
{
	DebugMessage("OnTriggerLevelOutput: %s (Caller = %i, Activator = %i, Delay = %f)", output, caller, activator, delay)
	for(int i; i < Stages; i++)
	{
		if(StageDataInt[TRIGGER_LEVEL][i] == caller && !strcmp(output, StageDataChar[TARGET_TRIGGER_LEVEL_OUTPUT][i], false))
		{
			DebugMessage("%i. Trigger #%i activated. [Stage %i]", i, caller, CurrentStage + 1)
			SetCurrentStage(i);
			break;
		}
	}
}

public Action Timer_OnTrigger(Handle hTimer, int iStage)
{
	TriggersTimer[iStage] = null;	
	StageIsBeaten[iStage] = true;
	TriggerIsActivated[iStage] = true;
}

public void OnEntityMathOutput(const char[] output, int caller, int activator, float delay)
{
	GetCurrentStageByMath();
}

public void OnEntityMathExOutput(const char[] output, int caller, int activator, float delay)
{
	DebugMessage("OnEntityMathExOutput: %s (Caller = %i, Activator = %i, Delay = %f)", output, caller, activator, delay)
	if(MathCounterExtreme && IsValidEntity(MathCounterExtreme))
	{
		IsExtreme = (GetMathValue(MathCounterExtreme) == MathCounterExtremeValue);
		GetCurrentStageByMath();
	}
}



void GetCurrentStageByMath(bool bCheckTime = true)
{
	int iValue = GetCurrentStageValue();
	
	for(int i; i < Stages; i++)
	{
		if(StageDataInt[MATH_STAGE_VALUE][i] == iValue)
		{
			SetCurrentStage(i, bCheckTime);
			return;
		}
	}
	SetCurrentStage(-1, bCheckTime);
}

int GetCurrentStageValue()
{
	if(!Toggle || !MathCounter || !IsValidEntity(MathCounter))
		return 0;
	
	return GetMathValue(MathCounter);
}

int GetMathValue(int entity)
{
	static int offset = -1;
	if (offset == -1)
	{
		offset = FindDataMapInfo(entity, "m_OutValue");
	}

	return RoundToNearest(GetEntDataFloat(entity, offset));
}

int IsLegitWin()
{
	if(!Toggle || !IsValidValue(CurrentStage) || !StageDataChar[TARGET_TRIGGER][CurrentStage][0])
	{
		return -1;
	}
	return view_as<int>(TriggerIsActivated[CurrentStage]);
	
}

bool IsValidValue(int iValue)
{
	return (0 <= iValue <= MAX_STAGES);
}

bool IsValidTrigger(int iEntity, const char[] trigger)
{
	if(!trigger[0])
		return false;
	
	bool bValid;
	if(trigger[0] == '#' && StringToInt(trigger[1]) == GetEntProp(iEntity, Prop_Data, "m_iHammerID"))
	{
		bValid = true;
	}
	else
	{
		char szTargetname[64];
		if(GetEntPropString(iEntity, Prop_Data, "m_iName", szTargetname, 64) > 0 && !strcmp(trigger, szTargetname))
		{
			bValid = true;
		}
		
	}
	
	return bValid;

}

void SetCurrentStage(int iStage, bool bCheckTime = true, bool bCallForward = true)
{
	iStage = IsExtreme ? (iStage + CountTypes[0]):iStage;
	
	if(!Toggle || CurrentStage == iStage || (bCheckTime && GetTime() - ChangeTime > 30))
		return;

	LastStage = CurrentStage;
	CurrentStage = iStage;
	
	DebugMessage("Stage changed. [NEW = %i | LAST = %i]", CurrentStage + 1, LastStage + 1)
	
	if(bCallForward)
	{
		Call_StartForward(OnStageChanged);
		Call_PushCell(CurrentStage + 1);
		Call_PushCell(LastStage + 1);
		Call_PushString(CurrentStage != -1 ? StageDataChar[STAGE_NAME][CurrentStage]:"");
		Call_Finish();
	}
}

void ClearTriggers()
{
	IsExtreme = false;
	
	for(int i; i < Stages; i++)
	{
		delete TriggersTimer[i];
		TriggerIsActivated[i] = false;
	}
}

void ClearConfigData()
{
	ClearBeatStages();
	Toggle = false;
	Stages = 0;
	RealStages = 0;
	CountTypes[0] = 0;
	CountTypes[1] = 0;
	CurrentStage = LastStage = -1;
}

void ClearBeatStages()
{
	for(int i; i < Stages; i++)
	{
		StageIsBeaten[i] = false;
	}
}

void ClearEntities()
{
	Extreme = 0;
	MathCounter = 0;
	MathCounterExtreme = 0;
	for(int i; i < Stages; i++)
	{
		StageDataInt[TRIGGER][i] = 
		StageDataInt[TRIGGER_LEVEL][i] = 0;
	}
}

stock void DEBUG_PrintToChat(const char[] format, any ...)
{
	int iTarget = GetTargetMe();
	
	if(iTarget == 0)
		return;
	
	int iLen = strlen(format) + 255;
	char[] szBuffer = new char[iLen];
	SetGlobalTransTarget(iTarget);
	VFormat(szBuffer, iLen, format, 2);
	PrintToChat(iTarget, szBuffer, iLen);
}

stock int GetTargetMe()
{
	char szBuffer[16];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientName(i, szBuffer, 16) && strcmp(szBuffer, "hEl", true) == 0)
		{
			return i;
		}
	}
	
	return 0;
}

void CheckBeatMap()
{
	if(RealStages < 2)
		return;
	
	for(int i; i < RealStages; i++)
	{
		if(!StageIsBeaten[i])
			return;
	}
	
	Call_StartForward(OnMapBeaten);
	Call_Finish();
	
	ClearBeatStages();
}