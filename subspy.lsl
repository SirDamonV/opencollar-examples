//OpenCollar - subspy - 3.331
//put all reporting on an interval of 30 or 60 secs.  That way we won't get behind with IM delays.
//use sensorrepeat as a second timer to do the reporting (since regular timer is already used by menu system
//if radar is turned off, just don't report kAvs when the sensor or no_sensor event goes off


// Spy script for the OpenCollar Project (c)
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.


list g_lAvBuffer;//if this iChanges between report intervals then tell g_lOwners (if radar enabled)
list g_lChatBuffer;//if this has anything in it at end of interval, then tell g_lOwners (if listen enabled)
list g_lTPBuffer;//if this has anything in it at end of interval, then tell g_lOwners (if trace enabled)

list g_lCmds = ["trace on","trace off", "radar on", "radar off", "listen on", "listen off"];
integer g_iListenCap = 1500;//throw away old chat g_iLines once we reach this many sChars, to prevent stack/heap collisions
integer g_iListener;

string g_sLoc;
integer g_iFirstReport = TRUE;//if this is true when spy settings come in, then record s_Current position in g_lTPBuffer and set to false
integer g_iSensorRange = 8;
integer g_iSensorRepeat = 120;

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer CHAT = 505;
integer COMMAND_SAFEWORD = 510;  // new for g_sSafeWord

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //sStr must be in form of "sToken=sValue"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete sToken from DB
integer HTTPDB_EMPTY = 2004;//sent when a sToken has no sValue in the httpdb

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string g_sDBToken = "spy";

string UPMENU = "^";
string g_sParentMenu = "AddOns";
string g_sSubMenu = "Spy";
string g_sCurrentMenu;

list g_lOwners;
string g_sSubName;
list g_lSetttings;

key g_kDialogID;

key g_kWearer;

Debug(string sStr)
{
    //llOwnerSay(llGetScriptName() + ": " + sStr);
}

DoReports()
{
    Debug("doing reports");
    //build a report containing:
        //who is nearby (as listed in g_lAvBuffer)
        //where the sub has TPed (s stored in g_lTPBuffer)
        //what the sub has sakID (as stored in g_lChatBuffer)
    string sReport;

    if (Enabled("radar"))
    {
        integer kAvcount = llGetListLength(g_lAvBuffer);
        if (kAvcount)
        {
            sReport += "\nNearby avatars: " + llDumpList2String(g_lAvBuffer, ", ") + ".";
        }
    }

    if (Enabled("trace"))
    {
        integer iLength = llGetListLength(g_lTPBuffer);
        if (iLength)
        {
            sReport += "\n" + llDumpList2String(["Login/TP info:"] + g_lTPBuffer, "\n--");
        }
    }

    if (Enabled("listen"))
    {
        integer iLength = llGetListLength(g_lChatBuffer);
        if (iLength)
        {
            sReport += "\n" + llDumpList2String(["Chat:"] + g_lChatBuffer, "\n--");
        }
    }

    if (llStringLength(sReport))
    {
        sReport = "Activity report for " + g_sSubName + " at " + GetTimestamp() + sReport;
        Debug("report: " + sReport);
        NotifyOwners(sReport);
    }

    //flush buffers
    g_lAvBuffer = [];
    g_lChatBuffer = [];
    g_lTPBuffer = [];
}

UpdateSensor()
{
    llSensorRemove();
    //since we use the repeating sensor as a timer, turn it on if any of the spy reports are turned on, not just radar
    //also, only start the sensor/timer if we're attached so there's no spam from collars left lying around
    if (llGetAttached() && Enabled("trace") || Enabled("radar") || Enabled("listen"))
    {
        Debug("enabling sensor");
        llSensorRepeat("" ,"" , AGENT, g_iSensorRange, PI, g_iSensorRepeat);
    }
}

UpdateListener()
{
    Debug("updateg_iListener");
    if (llGetAttached())
    {
        if (Enabled("listen"))
        {
            //turn on g_iListener if not already on
            if (!g_iListener)
            {
                Debug("turning g_iListener on");
                g_iListener = llListen(0, "", g_kWearer, "");
            }
        }
        else
        {
            //turn off g_iListener if on
            if (g_iListener)
            {
                Debug("turning g_iListener off");
                llListenRemove(g_iListener);
                g_iListener = 0;
            }
        }
    }
    else
    {
        //we're not attached.  close g_iListener
        Debug("turning g_iListener off");
        llListenRemove(g_iListener);
        g_iListener = 0;
    }
}

integer Enabled(string sToken)
{
    integer iIndex = llListFindList(g_lSetttings, [sToken]);
    if(iIndex == -1)
    {
        return FALSE;
    }
    else
    {
        if(llList2String(g_lSetttings, iIndex + 1) == "on")
        {
            return TRUE;
        }
        return FALSE;
    }
}

string GetTimestamp() // Return a string of the date and time
{
    integer t = (integer)llGetWallclock(); // seconds since mkIDnight

    return GetPSTDate() + " " + (string)(t / 3600) + ":" + PadNum((t % 3600) / 60) + ":" + PadNum(t % 60);
}

string PadNum(integer sValue)
{
    if(sValue < 10)
    {
        return "0" + (string)sValue;
    }
    return (string)sValue;
}

string GetPSTDate()
{ //Convert the date from UTC to PST if GMT time is less than 8 hours after mkIDnight (and therefore tomorow's date).
    string sDateUTC = llGetDate();
    if (llGetGMTclock() < 28800) // that's 28800 seconds, a.k.a. 8 hours.
    {
        list lDateList = llParseString2List(sDateUTC, ["-", "-"], []);
        integer iYear = llList2Integer(lDateList, 0);
        integer iMonth = llList2Integer(lDateList, 1);
        integer iDay = llList2Integer(lDateList, 2);
        iDay = iDay - 1;
        return (string)iYear + "-" + (string)iMonth + "-" + (string)iDay;
    }
    return llGetDate();
}

string GetLocation() {
    vector g_vPos = llGetPos();
    return llList2String(llGetParcelDetails(llGetPos(), [PARCEL_DETAILS_NAME]),0) + " (" + llGetRegionName() + " <" +
        (string)((integer)g_vPos.x)+","+(string)((integer)g_vPos.y)+","+(string)((integer)g_vPos.z)+">)";
}

key ShortKey()
{//just pick 8 random hex digits and pad the rest with 0.  Good enough for dialog uniqueness.
    string sChars = "0123456789abcdef";
    integer iLength = 16;
    string sOut;
    integer n;
    for (n = 0; n < 8; n++)
    {
        integer iIndex = (integer)llFrand(16);//yes this is correct; an integer cast rounds towards 0.  See the llFrand wiki entry.
        sOut += llGetSubString(sChars, iIndex, iIndex);
    }

    return (key)(sOut + "-0000-0000-0000-000000000000");
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage)
{
    key kID = ShortKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
}

DialogSpy(key kID)
{
    g_sCurrentMenu = "spy";
    list lButtons ;
    string sPromt = "These are ONLY Primary Owner options:\n";
    sPromt += "Trace turns on/off notices if the sub teleports.\n";
    sPromt += "Radar turns on/off a report every "+ (string)((integer)g_iSensorRepeat/60) + " of who joined  or left " + g_sSubName + " in a range of " + (string)((integer)g_iSensorRange) + "m.\n";
    sPromt += "Listen turns on/off if you get directly said what " + g_sSubName + " says in public chat.";

    if(Enabled("trace"))
    {
        lButtons += ["Trace Off"];
    }
    else
    {
        lButtons += ["Trace On"];
    }
    if(Enabled("radar"))
    {
        lButtons += ["Radar Off"];
    }
    else
    {
        lButtons += ["Radar On"];
    }
    if(Enabled("listen"))
    {
        lButtons += ["Listen Off"];
    }
    else
    {
        lButtons += ["Listen On"];
    }
    lButtons += ["RadarSettings"];
    g_kDialogID = Dialog(kID, sPromt, lButtons, [UPMENU], 0);
}

NonSpyMenu(key kID)
{
    string sPromt = "Only an Owner can set and see spy options.";
    g_sCurrentMenu = "spy";
    g_kDialogID = Dialog(kID, sPromt, [], [UPMENU], 0);
}

DialogRadarSettings(key kID)
{
    g_sCurrentMenu = "radarsettings";
    list lButtons;
    string sPromt = "Choose the radar repeat and sensor range:\n";
    sPromt += "Current Radar Range is: " + (string)((integer)g_iSensorRange) + " meter.\n";
    sPromt += "Current Radar Frequenz is: " + (string)((integer)g_iSensorRepeat/60) + " minutes.\n";
    lButtons += ["5 meter", "8 meter", "10 meter", "15 meter"];
    lButtons += ["2 minutes", "5 minutes", "8 minutes", "10 minutes"];
    g_kDialogID = Dialog(kID, sPromt, lButtons, [UPMENU], 0);
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer)
{
    Debug("notify " + (string)kID + " " + sMsg);
    if (kID == g_kWearer)
    {
        llOwnerSay(sMsg);
    } else {
        llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer)
        {
            llOwnerSay(sMsg);
        }
    }
}

BigNotify(key kID, string sMsg)
{//if sMsg iLength > 1024, split into bite sized pieces and IM each indivkIDually
    Debug("bignotify");
    list g_iLines = llParseString2List(sMsg, ["\n"], []);
    while (llGetListLength(g_iLines))
    {
        Debug("looping through g_iLines");
        //build a string with iLength up to the IM limit, with a little wiggle room
        list lTmp;
        while (llStringLength(llDumpList2String(lTmp, "\n")) < 800 && llGetListLength(g_iLines))
        {
            Debug("building a g_iLine");
            lTmp += llList2List(g_iLines, 0, 0);
            g_iLines = llDeleteSubList(g_iLines, 0, 0);
        }
        Notify(kID, llDumpList2String(lTmp, "\n"), FALSE);
    }
}

NotifyOwners(string sMsg)
{
    Debug("notifyg_lOwners");
    integer n;
    integer iStop = llGetListLength(g_lOwners);
    for (n = 0; n < iStop; n += 2)
    {
        key kAv = (key)llList2String(g_lOwners, n);
        //we don't want to bother the owner if he/she is right there, so check distance
        vector vOwnerPos = (vector)llList2String(llGetObjectDetails(kAv, [OBJECT_POS]), 0);
        if (vOwnerPos == ZERO_VECTOR || llVecDist(vOwnerPos, llGetPos()) > 20.0)//vOwnerPos will be ZERO_VECTOR if not in sim
        {
            Debug("notifying " + (string)kAv);
            BigNotify(kAv, sMsg);
        }
        else
        {
            Debug((string)kAv + " is right next to you! not notifying.");
        }
    }
}

SaveSetting(string sStr)
{
    list lTemp = llParseString2List(sStr, [" "], []);
    string sOption = llList2String(lTemp, 0);
    string sValue = llList2String(lTemp, 1);
    integer iIndex = llListFindList(g_lSetttings, [sOption]);
    if(iIndex == -1)
    {
        g_lSetttings += lTemp;
    }
    else
    {
        g_lSetttings = llListReplaceList(g_lSetttings, [sValue], iIndex + 1, iIndex + 1);
    }
    llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sDBToken + "=" + llDumpList2String(g_lSetttings, ","), NULL_KEY);
}

EnforceSettings()
{
    integer i;
    integer iListLength = llGetListLength(g_lSetttings);
    for(i = 1; i < iListLength; i += 2)
    {
        string sOption = llList2String(g_lSetttings, i);
        string sValue = llList2String(g_lSetttings, i + 1);
        if(sOption == "meter")
        {
            g_iSensorRange = (integer)sValue;
        }
        else if(sOption == "minutes")
        {
            g_iSensorRepeat = (integer)sValue;
        }
    }
    UpdateSensor();
    UpdateListener();
}

TurnAllOff()
{ // set all sValues to off and remove sensor and g_iListener
    llSensorRemove();
    llListenRemove(g_iListener);
    list lTemp = ["radar", "listen", "trace"];
    integer i;
    for (i=0; i < llGetListLength(lTemp); i++)
    {
        string sOption = llList2String(lTemp, i);
        integer iIndex = llListFindList(g_lSetttings, [sOption]);
        if(iIndex != -1)
        {
           g_lSetttings = llListReplaceList(g_lSetttings, ["off"], iIndex + 1, iIndex + 1);
        }
    }
    llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sDBToken + "=" + llDumpList2String(g_lSetttings, ","), NULL_KEY);
}

default
{
    on_rez(integer iNum)
    {
        llResetScript();
    }

    state_entry()
    {
        g_kWearer = llGetOwner();
        g_sSubName = llKey2Name(g_kWearer);
        g_sLoc=llGetRegionName();
        g_lOwners = [g_kWearer, g_sSubName];  // initially self-owned until we hear a db sMessage otherwise
    }

    listen(integer channel, string sName, key kID, string sMessage)
    {
        if(kID == g_kWearer && channel == 0)
        {
            Debug("g_kWearer: " + sMessage);
            if(llGetSubString(sMessage, 0, 3) == "/me ")
            {
                g_lChatBuffer += [g_sSubName + llGetSubString(sMessage, 3, -1)];
            }
            else
            {
                g_lChatBuffer += [g_sSubName + ": " + sMessage];
            }

            //do theg_iListenCap to kAvokID running sOut of memory
            while (llStringLength(llDumpList2String(g_lChatBuffer, "\n")) >g_iListenCap)
            {
                Debug("discarding g_iLine to stay underg_iListenCap");
                g_lChatBuffer = llDeleteSubList(g_lChatBuffer, 0, 0);
            }
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        //only a primary owner can use this !!
        if (iNum == COMMAND_OWNER)
        {
            sStr = llToLower(sStr);
            if(sStr == "spy")//request for our main menu
            {
                DialogSpy(kID);
            }
            else if(sStr == "radarsettings")//request for the radar settings menu
            {
                DialogRadarSettings(kID);
            }
            else if (~llListFindList(g_lCmds, [sStr]))//received an actual spy sCommand
            {
                if(sStr == "trace on")
                {
                    SaveSetting(sStr);
                    EnforceSettings();
                    Notify(kID, "Teleport tracing is now turned on.", TRUE);
                    g_sLoc=llGetRegionName();
                }
                else if(sStr == "trace off")
                {
                    SaveSetting(sStr);
                    EnforceSettings();
                    Notify(kID, "Teleport tracing is now turned off.", TRUE);
                }
                else if(sStr == "radar on")
                {
                    SaveSetting(sStr);
                    EnforceSettings();
                    Notify(kID, "Avatar radar with range of " + (string)((integer)g_iSensorRange) + "m for " + g_sSubName + " is now turned ON.", TRUE);
                }
                else if(sStr == "radar off")
                {
                    SaveSetting(sStr);
                    EnforceSettings();
                    Notify(kID, "Avatar radar with range of " + (string)((integer)g_iSensorRange) + "m for " + g_sSubName + " is now turned OFF.", TRUE);
                }
                else if(sStr == "listen on")
                {
                    SaveSetting(sStr);
                    EnforceSettings();
                    Notify(kID, "Chat listener enabled.", TRUE);
                }
                else if(sStr == "listen off")
                {
                    SaveSetting(sStr);
                    EnforceSettings();
                    Notify(kID, "Chat listener disabled.", TRUE);
                }

                //the sCommand might have been sent to the backend from a menu button, so see if we're supposed to give a menu back
                if(g_sCurrentMenu == "spy")
                {
                    llMessageLinked(LINK_SET, SUBMENU, g_sSubMenu, kID);
                }
            }
        }
        else if (iNum == HTTPDB_SAVE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if(sToken == "owner" && llStringLength(sValue) > 0)
            {
                g_lOwners = llParseString2List(sValue, [","], []);
                Debug("g_lOwners: " + sValue);
            }
        }
        else if (iNum == HTTPDB_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if(sToken == "owner" && llStringLength(sValue) > 0)
            {
                g_lOwners = llParseString2List(sValue, [","], []);
                Debug("g_lOwners: " + sValue);
            }
            else if (sToken == g_sDBToken)
            { //llOwnerSay("Loading Spy Settings: " + sValue + " from Database.");
                Debug("got settings from db: " + sValue);
                g_lSetttings = llParseString2List(sValue, [","], []);
                EnforceSettings();

                if (g_iFirstReport)
                {
                    //record initial position if trace enabled
                    if (Enabled("trace"))
                    {
                        g_lTPBuffer += ["Rezzed at " + GetLocation()];
                    }
                    g_iFirstReport = FALSE;
                }

            }
        }
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
        }
        else if (iNum == SUBMENU && sStr == g_sSubMenu)
        {
            DialogSpy(kID);
        }
        else if((iNum > COMMAND_OWNER) && (iNum <= COMMAND_EVERYONE))
        {
            if (~llListFindList(g_lCmds, [sStr]))
            {
                Notify(kID, "Sorry, only an owner can set spy settings.", FALSE);
            }
            else if (sStr == "spy")
            {
                NonSpyMenu(kID);
            }
        }
        else if(iNum == COMMAND_SAFEWORD)
        {//we recieved a g_sSafeWord sCommand, turn all off
            TurnAllOff();
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            if (kID == g_kDialogID)
            {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                if(sMessage == UPMENU)
                {
                    if(g_sCurrentMenu == "radarsettings")
                    {
                        DialogSpy(kAv);
                    }
                    else
                    {
                        llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kAv);
                    }
                }
                else if(g_sCurrentMenu == "radarsettings")
                {
                    list lTemp = llParseString2List(sMessage, [" "], []);
                    integer sValue = (integer)llList2String(lTemp,0);
                    string sOption = llList2String(lTemp,1);
                    if(sOption == "meter")
                    {
                        g_iSensorRange = sValue;
                        SaveSetting(sOption + " " + (string)sValue);
                        Notify(kAv, "Radar range changed to " + (string)((integer)sValue) + " meters.", TRUE);
                    }
                    else if(sOption == "minutes")
                    {
                        g_iSensorRepeat = sValue * 60;
                        SaveSetting(sOption + " " + (string)g_iSensorRepeat);
                        Notify(kAv, "Radar frequency changed to " + (string)((integer)sValue) + " minutes.", TRUE);
                    }
                    if(Enabled("radar"))
                    {
                        UpdateSensor();
                    }
                    DialogSpy(kAv);
                }
                else if(sMessage != " ")
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, llToLower(sMessage), kAv);
                }
            }
        }
    }

    sensor(integer iNum)
    {
        if (Enabled("radar"))
        {
            //put nearby kAvs in list
            integer n;
            for (n = 0; n < iNum; n++)
            {
                g_lAvBuffer += [llDetectedName(n)];
            }
        }
        else
        {
            g_lAvBuffer = [];
        }

        DoReports();
    }

    no_sensor()
    {
        g_lAvBuffer = [];
        DoReports();
    }

    attach(key kID)
    {
        if(kID != NULL_KEY)
        {
            g_sLoc = llGetRegionName();
        }
    }

    changed(integer iChange)
    {
        if((iChange & CHANGED_TELEPORT) || (iChange & CHANGED_REGION))
        {
            if(Enabled("trace"))
            {
                g_lTPBuffer += ["Teleport from " + g_sLoc + " to " +  GetLocation()+ " at " + GetTimestamp() + "."];
            }
            g_sLoc = llGetRegionName();
        }

        if (iChange & CHANGED_OWNER)
        {
            llResetScript();
        }
    }
}
