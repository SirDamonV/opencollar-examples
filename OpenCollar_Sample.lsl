// This file is part of OpenCollar.
// Copyright (c) 2008 - 2016 Nandana Singh, Lulu Pink, Garvin Twine,    
// Joy Stipe, Cleo Collins, Satomi Ahn, Master Starship, Toy Wylie,    
// Kaori Gray, Sei Lisa, Wendy Starfall, littlemousy, Romka Swallowtail,  
// Sumi Perl, Karo Weirsider, Kurt Burleigh, Marissa Mistwallow, Starverse et al.   
// Licensed under the GPLv2.  See LICENSE for full details. 

//
// This is a sample of how an open collar plugin can be coded. It assumes that you are already
// familiar with coding in general and Linden Scripting Language in particular. If that is not
// the case, this sample will be much less useful to you.
//

//
// General explanation of naming conventions.
//
// Variables can be keys, strings, integers, or lists. By convention, a local variable (meaning
// a variable only available in a specific block of code would be named something like kVar,
// sVar, iVar, or lVar, the leading lower case letter identifying what kind of variable it is.
// Global variables, meaning variables available throughout the entire script, have "g_" prepended,
// so the global equivalents would be g_kVar, g_sVar, g_iVar, or g_lVar. The "Var" part should be
// somehow descriptive, so you can tell later what you were using it for.
//
// Variables with all upper case names don't follow any particular standard. The upper case is
// a clue that their values mostly should not change, they are roughly symbolic constants.
//

//
// TOKEN DEFINITIONS are used to store and retrieve configuration values across login. As an
// example of what that means, if the collar is locked, there will be an entry in the settings
// script that looks like "global_locked=1". "global_" means the value could be applicable to
// any script, "locked=" means the variable "locked" and "1" is the assoGciated value.
//
// TOK_SAMPLE below means that values saved or retrieved by this script will start "sample_".
// This keeps them separate from similar values in other scripts.
// 

// ------ TOKEN DEFINITIONS ------
// ---- Immutable ----
// - Should be constant across collars, so not prefixed
// --- db tokens ---
string TOK_SAMPLE   = "sample";
// --- channel tokens ---

//
// Open Collar scripts communicate with each other via link messages. The integer numeric field
// in a link message serves as a transaction identifier or action code. The MESSAGE MAP below lists
// some of the possible codes. There will be more documentation on the various codes as they are
// used in this sample.
//
//MESSAGE MAP
//integer CMD_ZERO = 0;
integer CMD_OWNER = 500;
//integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
//integer CMD_RLV_RELAY = 507;
integer CMD_SAFEWORD = 510;
//integer CMD_RELAY_SAFEWORD = 511;
//integer CMD_BLOCKED = 520;

integer NOTIFY                = 1002;
//integer SAY                   = 1004;
integer REBOOT                = -1000;
integer LINK_DIALOG           = 3;
integer LINK_RLV              = 4;
integer LINK_SAVE             = 5;
integer LINK_UPDATE = -10;
integer LM_SETTING_SAVE       = 2000;
integer LM_SETTING_REQUEST    = 2001;
integer LM_SETTING_RESPONSE   = 2002;
integer LM_SETTING_DELETE     = 2003;
//integer LM_SETTING_EMPTY            = 2004;
// -- MENU/DIALOG
integer MENUNAME_REQUEST    = 3000;
integer MENUNAME_RESPONSE   = 3001;
//integer MENUNAME_REMOVE     = 3003;

integer RLV_CMD = 6000;

integer RLV_OFF = 6100;
integer RLV_ON = 6101;

integer DIALOG              = -9000;
integer DIALOG_RESPONSE     = -9001;
integer DIALOG_TIMEOUT      = -9002;
//
// These values are used to set up the menu and menu structure; "BACK" is a menu button with
// obvious meaning; "Apps" is the parent menu from which this plugin is accessed; "Sample" is
// the name of the button on that menu that will cause this plugin to run.
//
// --- menu button tokens ---
string BUTTON_UPMENU       = "BACK";
string BUTTON_PARENTMENU   = "Apps";
string BUTTON_SUBMENU      = "Sample";

// ---------------------------------------------
// ------ VARIABLE DEFINITIONS ------
// ----- menu -----

list     g_lMenuIDs;
integer g_iMenuStride = 3;
list g_lButtons;

// ----- collar -----

key g_kWearer;
key g_kCmdGiver;
string g_sSettingToken = "sample_";
//string g_sGlobalToken = "global_";

// ----- application -----
string g_sSample = "n";

// ---------------------------------------------
// ------ FUNCTION DEFINITIONS ------

/*
integer g_iProfiled=TRUE;
Debug(string sStr) {
    //if you delete the first // from the preceeding and following  lines,
    //  profiling is off, debug is off, and the compiler will remind you to
    //  remove the debug calls from the code, we're back to production mode
    if (!g_iProfiled){
        g_iProfiled=1;
        llScriptProfiler(1);
    }
    llOwnerSay(llGetScriptName() + "(min free:"+(string)(llGetMemoryLimit()-llGetSPMaxMemory())+")["+(string)llGetFreeMemory()+"] :\n" + sStr);
}
*/
//
// This function formats a menu and causes it to be presented to the designated recipient.
//
Dialog(key kRCPT, string sPrompt, list lButtons, list lUtilityButtons, integer iPage, integer iAuth, string sMenuID) {
    key kMenuID = llGenerateKey();
    string sPr = sPrompt + "\nSample=" + g_sSample;
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kRCPT + "|" + sPr + "|" + (string)iPage + "|" + llDumpList2String(lButtons, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kRCPT]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kRCPT, kMenuID, sMenuID], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kRCPT, kMenuID, sMenuID];
}

//
// This function confirms that iAuth, in this context the authority level of some avatar, is
// not less than CMD_OWNER (500) nor more than CMD_WEARER (504). The only legal values for
// authority level are 500-504. In this function, a return of "FALSE" means fail, "TRUE" means
// pass.
//
integer CheckCommandAuth(key kCmdGiver, integer iAuth) {
    // Check for invalid auth
    if (iAuth < CMD_OWNER || iAuth > CMD_WEARER) return FALSE;

    return TRUE;
}

//
// This function sets the value ot g_sSample to whatever the input is. If this were a real plugin,
// this value would be useful somehow. Here, it just shows how you might do this. Note that putting
// access to g_sSample here in this function allows you to take action when it changes. In this 
// sample, besides making sure the input value is lower case, the collar wearer gets a notice that
// the value has changed, and the value is saved to the appropriate area in settings. Refer to the
// comments above about TOK_SAMPLE.
// 
integer SetSample(key kCmdGiver, integer iAuth, string sSample) {
    if (!CheckCommandAuth(kCmdGiver, iAuth)) return FALSE;
    g_sSample = llToLower(sSample);
    llMessageLinked(LINK_DIALOG,NOTIFY,"0Sample has been set to "+g_sSample,g_kWearer);
    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + TOK_SAMPLE + "=" + g_sSample, "");
    return TRUE;
}
//
// This function parses through the input provided it to determine if there is a command
// it understands and should do.
//
UserCommand(integer iAuth, string sMessage, key kMessageID, integer bFromMenu) {
    //Debug("Got user comand:\niAuth: "+(string)iAuth+"\nsMessage: "+sMessage+"\nkMessageID: "+(string)kMessageID+"\nbFromMenu: "+(string)bFromMenu);
    g_kCmdGiver = kMessageID;
//
// This breaks the input string into sections, dividing it on space (" "), inserting the
// sections into a list (lParam). It then extracts the first and second items into sComm and sVal,
// respectively. In this simple example, nothing further happens to them. In more complex cases,
// you will have to examine them to decide what you are being asked to do.
//
    list lParam = llParseString2List(sMessage, [" "], []);
    string sComm = llToLower(llList2String(lParam, 0));
    string sVal = llToLower(llList2String(lParam, 1));

    sMessage = llToLower(sMessage);  //convert sMessage to lower case for caseless comparison
    //debug(sMessage);
//
// If the input message is a request for a menu, a prompt and a list of appropriate buttons
// is generated and passed to the Dialog function.
//
    if (sMessage=="samplemenu" || sMessage == "menu sample"){
        list lButtons;
        if (g_sSample == "n") lButtons = ["Sample-yes"]; else lButtons  = ["Sample-no"];

        string sPrompt = "\n[Sample]\n";
        if (g_sSample == "n") sPrompt += "Currently 'No'"; else sPrompt += "Currently 'Yes'";
        Dialog(kMessageID, sPrompt, lButtons, [BUTTON_UPMENU], 0, iAuth, "MainDialog");
//
// If the input message means the value of sample needs to be set, this code will check the
// authorization level, and if approved, change the value and possiblly redisplay the menu.
// In this example, there are no checks on authority level, i.e. CheckCommandAuth will allow 
// anyone access. By changing what CheckCommandAuth returns, you can limit who can perform
// this function. For example, if CheckCommandAuth returns FALSE when iAuth is CMD_WEARER,
// the collar wearer will not be allowed to change the value. It would be nice to issue a
// message in that case, but there's no requirement you be nice.
//
    } else if (sMessage=="sample-yes") {
        if (CheckCommandAuth(kMessageID, iAuth)) SetSample(kMessageID, iAuth, "y");
        if (bFromMenu) UserCommand(iAuth, "samplemenu", kMessageID ,bFromMenu);
    } else if (sMessage=="sample-no") {
        if (CheckCommandAuth(kMessageID, iAuth)) SetSample(kMessageID, iAuth, "n");
        if (bFromMenu) UserCommand(iAuth, "samplemenu", kMessageID ,bFromMenu);
    }
}

default {
    on_rez(integer start_param) {
    }

    state_entry() {
        g_kWearer = llGetOwner();
        //Debug("Starting");
    }

    link_message(integer iSender, integer iNum, string sMessage, key kMessageID){
//
// If iNum is between 500 and 504, inclusively, the input string must be a command to be acted upon.
// See above comments about MESSAGE_MAP and User_Command.
//
        if (iNum >= CMD_OWNER && iNum <= CMD_EVERYONE) UserCommand(iNum, sMessage, kMessageID, FALSE);
//
// If iNum is MENUNAME_REQUEST and the accompanying string text is the name of our parent menu,
// then our parent menu is asking who wants to be included in that menu. We respond with the string
// BUTTON_PARENTMENU + "|" + BUTTON_SUBMENU, which here translates to "Apps|Sample".
//
        else if (iNum == MENUNAME_REQUEST && sMessage == BUTTON_PARENTMENU) {
            g_lButtons = [] ; // flush submenu buttons
            llMessageLinked(iSender, MENUNAME_RESPONSE, BUTTON_PARENTMENU + "|" + BUTTON_SUBMENU, "");
//
// If iNum is MENUNAME_RESPONSE and the first part of the response is our name, meaning the message
// looks like "Sample|Xxxxx", then something named Xxxxx wants to be included in our menu. This will
// never happen with this plugin, because we have no submenus, but in more complex situations, it's
// possible.
//
        } else if (iNum == MENUNAME_RESPONSE) {
            list lParts = llParseString2List(sMessage, ["|"], []);
            if (llList2String(lParts, 0) == BUTTON_SUBMENU) {//someone wants to stick something in our menu
                string button = llList2String(lParts, 1);
                if (llListFindList(g_lButtons, [button]) == -1)
                    g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
            }
//
// CMD_SAFEWORD gets sent if the wearer uses the safeword. If you're inclined to do anything special
// in that instance, here is where the code would go. Use your own judgement.
//
        } else if (iNum == CMD_SAFEWORD) {
//
// LM_SETTING_RESPONSE is how the settings script sends preset values. If g_sSample has previously
// been set, you'll receive this message at startup, extract whatever the preset was, and set this
// instance of g_sSample accordingly.
//
        } else if (iNum == LM_SETTING_RESPONSE) {
            integer iInd = llSubStringIndex(sMessage, "=");
            string sToken = llGetSubString(sMessage, 0, iInd -1);
            string sValue = llGetSubString(sMessage, iInd + 1, -1);
            integer i = llSubStringIndex(sToken, "_");
            if (llGetSubString(sToken, 0, i) == g_sSettingToken) {
                //Debug("got Sample settings:"+sMessage);
                sToken = llGetSubString(sToken, i + 1, -1);
                if (sToken == TOK_SAMPLE) g_sSample = sValue;
            }
//
// When you send a menu using the Dialog function described above, the expected result is a
// DIALOG_RESPONSE link message. This section checks the response against the list of menus
// we have presented to see if it's one of ours (could be a response to a menu from some other
// script, and if it is, breaks the message into its component parts. We only use one menu in
// this example, MainDialog, so the check to see if this is a MainDialog response is useless
// except as an example. More complex scripts issue multiple dialogs, and it's important to 
// know to which one you're responding.
//
// Having decided this is one of ours, we remove it from the list.
//
// In this case, because we know what buttons we have on our menu, we check for BACK (which
// just means to request the parent menu) and ask for that menu, or else just pass the message
// to UserCommand and let that function deal with it.
//
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kMessageID]);
            if (~iMenuIndex) {
                list lMenuParams = llParseString2List(sMessage, ["|"], []);
                key kAV = (key)llList2String(lMenuParams, 0);
                string sButton = llList2String(lMenuParams, 1);
                //integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                string sMenu=llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                if (sMenu == "MainDialog"){
                    if (sButton == BUTTON_UPMENU)
                        llMessageLinked(LINK_ROOT, iAuth, "menu "+BUTTON_PARENTMENU, kAV);
                    else if (~llListFindList(g_lButtons, [sButton]))
                        llMessageLinked(LINK_ROOT, iAuth, "menu "+sButton, kAV);
                    else UserCommand(iAuth, llToLower(sButton), kAV, TRUE);
                }
            }
//
// Could be what you get is nothing (a timeout) in which case just remove the menu information
// from the list and ignore it henceforth.
//
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kMessageID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
//
// LINK_UPDATE messages are important because they tell you where to send certain link messages.
// Instead of blasting every link message to every script, dialog messages are sent directly to the
// prim that contains the dialog script (which you know because LINK_DIALOG tells you.) Similarly,
// RLV commands go to the prim that handles RLV, and setting save commands go to the settings script.
// There are other isolated scripts, but these are the only ones significant here.
//
        } else if (iNum == LINK_UPDATE) {
            if (sMessage == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sMessage == "LINK_RLV") LINK_RLV = iSender;
            else if (sMessage == "LINK_SAVE") LINK_SAVE = iSender;
//
// If you get a REBOOT message, reboot; sorry.
//
        } else if (iNum == REBOOT && sMessage == "reboot") llResetScript();
    }

//
// The g_kWearer variable always needs to contain the key of the actual wearer of the collar. This
// is how that happens.
//
    changed (integer iChange){
        if (iChange & CHANGED_OWNER){
            g_kWearer = llGetOwner();
        }
    }
}
