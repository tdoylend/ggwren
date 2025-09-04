/*
* GGWren
* Copyright (C) 2025 Thomas Doylend
* 
* This software is provided ‘as-is’, without any express or implied
* warranty. In no event will the authors be held liable for any damages
* arising from the use of this software.
* 
* Permission is granted to anyone to use this software for any purpose,
* including commercial applications, and to alter it and redistribute it
* freely, subject to the following restrictions:
* 
* 1. The origin of this software must not be misrepresented; you must not
*    claim that you wrote the original software. If you use this software
*    in a product, an acknowledgment in the product documentation would be
*    appreciated but is not required.
* 
* 2. Altered source versions must be plainly marked as such, and must not be
*    misrepresented as being the original software.
* 
* 3. This notice may not be removed or altered from any source
*    distribution.
*/

/**************************************************************************************************/

import "gg" for GG
import "lib/io/stream" for Stream

GG.bind("builtins")

foreign class TcpStream is Stream {
    // Instantiate a client socket connected to a remote address.
    // construct connect(peer) { } @todo

    foreign static acceptFrom_(listener)

    // Get the address of whatever is connected to the other end of
    // the socket.
    foreign peerAddress
    foreign peerPort

    // Set or get the blocking status of the socket.
    foreign blocking
    foreign blocking=(enabled)

    // Attempt to read up to `size` bytes from the socket. Less than
    // size may be returned, and if the socket is in non-blocking mode
    // null will be returned instead of a string. read(..) returns an
    // empty string when the other side has closed the connection.
    foreign read(size)

    // Attempt to write at least some of `bytes` to the socket's
    // send queue; returns the number of bytes actually written.
    foreign write(bytes)

    // Close the socket (also shutting down in the process if that has
    // not already occurred.
    foreign close()

    foreign isOpen

    // Shut down one or both sides of the socket. `mode` must be either
    // "r", "w", or "rw" to shut down the read, write, or both sides of
    // the socket, respectively. Attempts to use the shut-down side of
    // the socket will fail.
    // foreign shutdown(mode)
}

foreign class TcpListener {
    construct bind(address, port) { }

    foreign blocking
    foreign blocking=(enabled)

    accept() { TcpStream.acceptFrom_(this) }
    foreign close()
}

GG.bind(null)
