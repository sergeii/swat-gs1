class Response extends SwatGame.SwatMutator;

/**
 * Copyright (c) 2014 Sergei Khoroshilov <kh.sergei@gmail.com>
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

/**
 * This class handles response objects that expose simple public API:
 * 
 *     AddInfo() - populates object with server information
 *     AddPlayers() - populates object with player details
 *     Read() - read a piece of response formed off previously populated data
 *     IsEmpty() - tell whether response object is out of data
 *
 * Every single packet read with a Read() call contains 
 * a \queryid\%N% fragment with a 1-based number indicating current packet count.
 * The last response packet is also provided with a \final\ fragment.
 * 
 * Read more about Gamespy protocol at <http://int64.org/docs/gamestat-protocols/gamespy.html>
 */

/**
 * Although the most reliable udp packet size is believed to be 508,
 * the final packet does also contain the extra \final\ string
 * @type int
 */
const MAX_PACKET_SIZE = 500;

/**
 * Array of fragments awaiting of being split and read chunk by chunk
 * @type array<string>
 */
var protected array<string> Fragments;

/**
 * Current packet count
 * @type int
 */
var protected int PacketCount;

/**
 * Indicate whether the response instance is occupied by listener
 * @type bool
 */
var protected bool bOccupied;

/**
 * Tell whether the fragments array is out of elements
 * 
 * @return  bool
 */
public function bool IsEmpty()
{
    return self.Fragments.Length == 0;
}

/**
 * Return the next piece of response text
 * 
 * @return  string
 */
public function string Read()
{
    local int FragmentCount;
    local array<string> Packet;

    if (self.IsEmpty())
    {
        return "";
    }
    // Prepopulate the array with packet information fragments
    Packet[Packet.Length] = "queryid";
    Packet[Packet.Length] = string(++self.PacketCount);
    // Only pack new fragments if they dont break the limit
    while (true)
    {
        // Stop when exhausted
        if (self.IsEmpty())
        {
            break;
        }
        // Dont let the next pair of fragments to pass if the two break the limit
        if (++FragmentCount % 2 != 0)
        {
            if (self.GetPacketSize(Packet) + (Len(self.Fragments[0]) + Len(self.Fragments[1]) + 2) > class'Response'.const.MAX_PACKET_SIZE)
            {
                break;
            }
        }
        Packet[Packet.Length] = self.Fragments[0];
        // Keep removing acquired fragments untill the array is empty..
        self.Fragments.Remove(0, 1);
    }
    // Rearrange packet array elements so the queryid token
    // and it's value are at the end of the packet
    Packet[Packet.Length] = Packet[0];
    Packet[Packet.Length] = Packet[1];
    // Shift the original queryid elements
    Packet.Remove(0, 2);
    // Add final token in case the array is out of fragments
    if (self.IsEmpty())
    {
        Packet[Packet.Length] = "final";
        Packet[Packet.Length] = "";;
    }
    // Split packets always begin with a backslash
    return "\\" $ class'Utils.ArrayUtils'.static.Join(Packet, "\\");;
}

/**
 * Extend response with server details
 * 
 * @return  void
 */
public function AddInfo()
{
    self.AddPair("hostname", ServerSettings(Level.CurrentServerSettings).ServerName);
    self.AddPair("numplayers", SwatGameInfo(Level.Game).NumberOfPlayersForServerBrowser());
    self.AddPair("maxplayers", ServerSettings(Level.CurrentServerSettings).MaxPlayers);
    self.AddPair("gametype", SwatGameInfo(Level.Game).GetGameModeName());
    self.AddPair("gamevariant", Level.ModName);
    self.AddPair("mapname", Level.Title);
    self.AddPair("hostport", SwatGameInfo(Level.Game).GetServerPort());
    self.AddPair("password", Lower(string(Level.Game.GameIsPasswordProtected())));
    self.AddPair("gamever", Level.BuildVersion);
    self.AddPair("round", ServerSettings(Level.CurrentServerSettings).RoundNumber+1);
    self.AddPair("numrounds", ServerSettings(Level.CurrentServerSettings).NumRounds);
    self.AddPair("timeleft", SwatGameReplicationInfo(Level.Game.GameReplicationInfo).RoundTime);

    switch (ServerSettings(Level.CurrentServerSettings).GameType)
    {
        #if IG_SPEECH_RECOGNITION
        case MPM_COOPQMM:
        #endif
        case MPM_COOP:
        case MPM_RapidDeployment:
        case MPM_VIPEscort:
            self.AddPair("timespecial", SwatGameReplicationInfo(Level.Game.GameReplicationInfo).SpecialTime);
            break;
    }

    switch (ServerSettings(Level.CurrentServerSettings).GameType)
    {
        #if IG_SPEECH_RECOGNITION
        case MPM_COOPQMM:
        #endif
        case MPM_COOP:
            self.AddCOOPInfo();
            break;
        case MPM_RapidDeployment:
            self.AddPair("bombsdefused", SwatGameReplicationInfo(Level.Game.GameReplicationInfo).DiffusedBombs);
            self.AddPair("bombstotal", SwatGameReplicationInfo(Level.Game.GameReplicationInfo).TotalNumberOfBombs);
            // no break
        default:
            self.AddPair("swatscore", SwatGameInfo(Level.Game).GetTeamFromID(0).NetScoreInfo.GetScore());
            self.AddPair("suspectsscore", SwatGameInfo(Level.Game).GetTeamFromID(1).NetScoreInfo.GetScore());
            self.AddPair("swatwon", SwatGameInfo(Level.Game).GetTeamFromID(0).NetScoreInfo.GetRoundsWon());
            self.AddPair("suspectswon", SwatGameInfo(Level.Game).GetTeamFromID(1).NetScoreInfo.GetRoundsWon());
            break;
    }
}

/**
 * Add 
 * 
 * @return  void
 */
public function AddCOOPInfo()
{
    local int i;
    local MissionObjectives Objectives;
    local Procedures Procedures;

    Objectives = SwatRepo(Level.GetRepo()).MissionObjectives;

    // "obj_"Objective name => Objective status pair
    for (i = 0; i < Objectives.Objectives.Length; i++)
    {
        // Skip the hidden objective
        if (Objectives.Objectives[i].name == 'Automatic_DoNot_Die')
        {
            continue;
        }
        self.AddPair("obj_" $ Objectives.Objectives[i].name, SwatGameReplicationInfo(Level.Game.GameReplicationInfo).ObjectiveStatus[i]);
    }

    // Add the params "tocreports" and "weaponssecured"
    Procedures = SwatRepo(Level.GetRepo()).Procedures;

    for (i = 0; i < Procedures.Procedures.Length; i++)
    {
        switch (Procedures.Procedures[i].class.name)
        {
            case 'Procedure_SecureAllWeapons':
                self.AddPair("tocreports", Procedures.Procedures[i].Status());
                break;
            case 'Procedure_ReportCharactersToTOC':
                self.AddPair("weaponssecured", Procedures.Procedures[i].Status());
                break;
        }
    }
}

/**
 * Append player details to response
 * 
 * @return  void
 */
public function AddPlayers()
{
    local int i;
    local PlayerController PC;

    foreach DynamicActors(class'PlayerController', PC)
    {
        self.AddPair("player_" $ i, PC.PlayerReplicationInfo.PlayerName);
        self.AddPair("score_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetScore());
        self.AddPair("ping_" $ i, Min(999, PC.PlayerReplicationInfo.Ping));
        self.AddPair("team_" $ i, NetTeam(PC.PlayerReplicationInfo.Team).GetTeamNumber());

        // COOP status
        if (Level.IsCOOPServer)
        {
            self.AddPair("coopstatus_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).COOPPlayerStatus);
        }

        // Kills
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetEnemyKills() > 0)
        {
            self.AddPair("kills_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetEnemyKills());
        }

        // Deaths
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetTimesDied() > 0)
        {
            self.AddPair("deaths_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetTimesDied());
        }

        // Team Kills
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetFriendlyKills() > 0)
        {
            self.AddPair("tkills_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetFriendlyKills());
        }

        // Arrests
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetArrests() > 0)
        {
            self.AddPair("arrests_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetArrests());
        }

        // Arrested
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetTimesArrested() > 0)
        {
            self.AddPair("arrested_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetTimesArrested());
        }

        // The VIP
        if (SwatGamePlayerController(PC).ThisPlayerIsTheVIP)
        {
            self.AddPair("vip_" $ i, 1);
        }

        // VIP Escapes
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetVIPPlayerEscaped() > 0)
        {
            self.AddPair("vescaped_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetVIPPlayerEscaped());
        }

        // VIP Captures
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetArrestedVIP() > 0)
        {
            self.AddPair("arrestedvip_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetArrestedVIP());
        }

        // VIP Rescues
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetUnarrestedVIP() > 0)
        {
            self.AddPair("unarrestedvip_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetUnarrestedVIP());
        }

        // VIP Kills Valid
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetKilledVIPValid() > 0)
        {
            self.AddPair("validvipkills_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetKilledVIPValid());
        }

        // VIP Kills Invalid
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetKilledVIPInvalid() > 0)
        {
            self.AddPair("invalidvipkills_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetKilledVIPInvalid());
        }

        // Bombs Disarmed
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetBombsDiffused() > 0)
        {
            self.AddPair("bombsdiffused_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetBombsDiffused());
        }

        // RD Crybaby
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetRDCrybaby() > 0)
        {
            self.AddPair("rdcrybaby_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetRDCrybaby());
        }

        #if IG_SPEECH_RECOGNITION
        // SG Crybaby
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetSGCrybaby() > 0)
        {
            self.AddPair("sgcrybaby_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetSGCrybaby());
        }
        
        // Case Escapes
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetEscapedSG() > 0)
        {
            self.AddPair("escapedcase_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetEscapedSG());
        }

        // Case Kills
        if (SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetKilledSG() > 0)
        {
            self.AddPair("killedcase_" $ i, SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetKilledSG());
        }
        #endif

        i++;
    }
}

/**
 * Add a new key-value pair
 * 
 * @param   string Key
 * @param   string Value
 * @return  void
 */
public function AddPair(coerce string Key, coerce string Value)
{
    self.AddFragment(Key);
    self.AddFragment(Value);
}

/**
 * Append a new fragment to the list of fragments
 * 
 * @param   string Fragment
 * @return  void
 */
protected function AddFragment(coerce string Fragment)
{
    // Trim long fragments
    self.Fragments[self.Fragments.Length] = Left(Fragment, class'Response'.const.MAX_PACKET_SIZE/3);
}

/**
 * Compute and return the length of given packet fragments 
 * as if they were formed up into a packet using a backslash as the delimiter
 * 
 * @param   array<string> Packet
 * @return  int
 */
static function int GetPacketSize(array<string> Packet)
{
    local int i, Size;

    for (i = 0; i < Packet.Length; i++)
    {
        Size += Len(Packet[i]);
    }
    return Size + Packet.Length;
}

/**
 * Tell whether the response instance has been occupied
 * 
 * @return  bool
 */
public function bool IsOccupied()
{
    return self.bOccupied;
}

/**
 * Occupy the instance
 * 
 * @return  void
 */
public function Occupy()
{
    self.bOccupied = true;
}

/**
 * Free the instance
 * 
 * @return  void
 */
public function Free()
{
    self.Fragments.Remove(0, self.Fragments.Length);
    self.PacketCount = 0;
    self.bOccupied = false;
}

event Destroyed()
{
    self.Free();
    Super.Destroyed();
}

/* vim: set ft=java: */