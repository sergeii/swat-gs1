swat-gs1
%%%%%%%%

:Version:           1.0.0
:Home page:         https://github.com/sergeii/swat-gs1
:Author:            Sergei Khoroshilov <kh.sergei@gmail.com>
:License:           The MIT License (http://opensource.org/licenses/MIT)

Description
===========
This package provides `Gamespy Query <http://int64.org/docs/gamestat-protocols/gamespy.html>`_ multiprotocol (both UDP and TCP) listen support for SWAT 4 servers.

Inspiration
===========
Initially this package was developed with an intention to provide 
an ability for a SWAT 4 server to respond to Gamespy queries utilizing TCP networking,
which has been a major relief for webmasters willing to set up their own server monitoring
software that would avoid using UDP transmission, since it's almost never available on a shared website hosting.

It has later been tweaked, in order to replace the native query listener 
that has gone obsolete due to SWAT 4 Gamespy support shutdown, as there are no other solutions
had been available that the author of this package had been familiar with. 
The widespread AMServerQuery listener from the `AMMod package <http://gezmods.co.uk/index.php?ms=view_mod&mod_id=106>`_ that has been meant to replace 
the native listener since the shutdown, does not comply with the 
`Gamespy Protocol standard <http://int64.org/docs/gamestat-protocols/gamespy.html>`_,
hence is helpless to a variety of server monitoring software (GameQ, HLSW, etc) that expect a properly formatted buffered UDP response.

Dependencies
============
* `Utils <https://github.com/sergeii/swat-utils>`_ *>=1.0.0*

Installation
============

0. Install required packages listed above in the **Dependencies** section.

1. Download compiled binaries or compile the ``GS1`` package yourself.

   Every release is accompanied by two tar files, each containing a compiled package for a specific game version::

      swat-gs1.X.Y.Z.swat4.tar.gz
      swat-gs1.X.Y.Z.swat4exp.tar.gz

   with `X.Y.Z` being the package version, followed by a game version identifier::

      swat4 - SWAT 4 1.0-1.1
      swat4exp - SWAT 4: The Stetchkov Syndicate

   Please check the `releases page <https://github.com/sergeii/swat-gs1/releases>`_ to get the latest stable package version appropriate to your server game version.

2. Copy contents of a tar archive into the server's `System` directory.

3. Open ``Swat4DedicatedServer.ini``

4. Navigate to the ``[Engine.GameEngine]`` section.

5. Comment out or remove completely the following line::

    ServerActors=IpDrv.MasterServerUplink

   This is ought to free the +1 port (e.g. 10481) that has been occupied by the native Gamespy query listener.

6. Insert the following line anywhere in the section::

    ServerActors=GS1.Listener

7. Add the following section at the bottom of the file::

    [GS1.Listener]
    Enabled=True

8. The ``Swat4DedicatedServer.ini`` contents should look like this now::

    [Engine.GameEngine]
    EnableDevTools=False
    InitialMenuClass=SwatGui.SwatMainMenu
    ...
    ;ServerActors=IpDrv.MasterServerUplink
    ServerActors=GS1.Listener
    ...

    [GS1.Listener]
    Enabled=True

9. | Your server is now ready to listen to GameSpy v1 protocol queries on the join port + 1 (e.g. 10481).
   | By default, that would be a UDP port, but it is also possible to use TCP protocol as well.
   | Please refer to the Properties section below.

Properties
==========
The ``[GS1.Listener]`` section of ``Swat4DedicatedServer.ini`` accepts the following properties:

.. list-table::
   :widths: 15 40 10 10
   :header-rows: 1

   * - Property
     - Descripion
     - Options
     - Default
   * - Enabled
     - Toggle listener on and off (requires a server restart).
     - True/False
     - False
   * - Port
     - Port to listen on.

       By default, listener mimics behaviour of the original gamespy query listener
       that binds a port number equals to the join port incremented by 1. 
       For instance, if a join port was 10480 (default value), the query port would be 10481.

       You are free to set up an explicit port number, in order to avoid the default behaviour.
     - 1-65535
     - Join Port+1
   * - Protocol
     - Protocol the listen port should be bound with.

       It is possible to listen to both UDP and TCP ports simultaneously. To achieve that, set this option to `ALL`.
     - UDP, TCP, ALL
     - UDP
