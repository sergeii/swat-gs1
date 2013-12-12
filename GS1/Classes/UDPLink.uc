class UDPLink extends IpDrv.UdpLink 
  implements Link;

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
 * Reference to the listener
 * @type class'Listener'
 */
var protected Listener Listener;

/**
 * @see Link.Bind
 */
public function Bind(int Port, Listener Listener)
{
    self.Listener = Listener;

    if (self.BindPort(Port, false) > 0)
    {
        log(self $ " is now listening on " $ Port);
        return;
    }

    self.Listener.OnLinkFailure(self, "failed to bind port");
    self.Destroy();
}

/**
 * @see Link.Reply
 */
public function Reply(IpAddr Addr, coerce string Text)
{
    self.SendText(Addr, Text);
}

/**
 * Call delegate whenever plain text data is received
 * 
 * @param   IpAddr Addr
 *          Source address
 * @param   string Text
 *          Received plain text data
 */
event ReceivedText(IpAddr Addr, string Text)
{
    self.Listener.OnTextReceived(self, Addr, Text);
}

event Destroyed()
{
    self.Listener = None;
    Super.Destroyed();
}

/* vim: set ft=java: */