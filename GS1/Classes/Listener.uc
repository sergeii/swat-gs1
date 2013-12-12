class Listener extends SwatGame.SwatMutator;

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
 * The purpose of this class is to initialize instances of 
 * Link interface implementing classes that that provide unified API
 * to their protocol-specific operations (i.e. UDP and TCP).
 * 
 * Listener is able to listen on both UDP and TCP ports simultaneously.
 */

/**
 * Indicate whether listener is enabled
 * @default False
 * @type bool
 */
var config bool Enabled;

/**
 * Port number to listen on (1-65535)
 * @default Join Port + 1
 * @type int
 */
var config int Port;

/**
 * Listener protocol (can be either UDP, TCP or both)
 * @default UDP
 * @type enum'eProtocol'
 */
var config enum eProtocol
{
    UDP,
    TCP,
    ALL
} Protocol;

/**
 * Reference to listening links
 * @type array<interface'Link'>
 */
var protected array<Link> Links;

/**
 * Response instance
 * @type class'Response'
 */
var protected Response Response;

/**
 * Check whether mod is enabled
 * If it's not, destroy the instance
 * 
 * @return  void
 */
public function PreBeginPlay()
{
    Super.PreBeginPlay();

    if (!self.Enabled)
    {
        self.Destroy();
    }
}

/**
 * Initialize the multiprotocol listener
 *
 * @return  void
 */
public function BeginPlay()
{
    Super.BeginPlay();
    // Avoid being initialized on the Entry level
    if (Level.Game == None || SwatGameInfo(Level.Game) == None)
    {
        self.Destroy();
        return;
    }
    // Listen on the join port +1 if none specified
    if (self.Port == 0)
    {
        self.Port = SwatGameInfo(Level.Game).GetServerPort() + 1;
    }
    switch (self.Protocol)
    {
        case UDP:
            self.AddLink(Spawn(class'UDPLink'));
            break;
        case TCP:
            self.AddLink(Spawn(class'TCPLink'));
            break;
        case ALL:
            self.AddLink(Spawn(class'UDPLink'));
            self.AddLink(Spawn(class'TCPLink'));
            break;
        default:
            self.Destroy();
            return;
    }
    self.Response = Spawn(class'Response');
    self.Listen();
}

/**
 * Add a new instance of a Link interface implementing class
 * 
 * @param   interface'Link' Link
 * @return  void
 */
protected function AddLink(Link Link)
{
    self.Links[self.Links.Length] = Link;
}

/**
 * Attempt to listen on the query port on all initialized links
 * 
 * @return  void
 */
protected function Listen()
{
    local int i;

    for (i = 0; i < self.Links.Length; i++)
    {
        self.Links[i].Bind(self.Port, self);
    }
}

/**
 * Handle a request
 * 
 * @param   interface'Link' Link
 *          Reference to the interacted link 
 * @param   struct'IpAddr' Addr
 *          Source address
 * @param   string Text
 *          Plain text request data
 * @return  void
 */
public function OnTextReceived(Link Link, IpDrv.InternetLink.IpAddr Addr, string Text)
{
    // Check whether listener is busy with another request
    if (self.Response.IsOccupied())
    {
        return;
    }
    self.Response.Occupy();
    // Parse the request query text..
    switch (class'Utils.StringUtils'.static.Replace(Text, "\\", ""))
    {
        // ..although, only status is currently supported
        case "status":
            Response.AddInfo();
            Response.AddPlayers();
            break;
        default:
            break;
    }
    // Read one packet a time
    while (!self.Response.IsEmpty())
    {
        // Return a UTF-8 encoded string
        Link.Reply(Addr, class'Utils.UnicodeUtils'.static.EncodeUTF8(self.Response.Read()));
    }
    // Free the response instance for further use
    self.Response.Free();
}

/**
 * Perform a shutdown whenever a referenced link encounters a failure
 *
 * @param   interface'Link' Link
 * @param   string Message (optional)
 * @return  void
 */
public function OnLinkFailure(Link Link, optional string Message)
{
    log(Link $ " failed to listen on " $ self.Port $ " (" $ Message $ ")");

    self.Destroy();
}

/**
 * Destroy instances of referenced links
 */
event Destroyed()
{
    while (Links.Length > 0)
    {
        if (self.Links[0] != None)
        {
            self.Links[0].Destroy();
        }
        self.Links.Remove(0, 1);
    }

    if (self.Response != None)
    {
        self.Response.Destroy();
        self.Response = None;
    }

    Super.Destroyed();
}

defaultproperties
{
    Enabled=false;
    Port=0;
    Protocol=UDP;
}

/* vim: set ft=java: */