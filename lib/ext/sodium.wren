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

// Libsodium bindings for GGWren.
// https://doc.libsodium.org/
//
// DANGER ZONE! THESE ARE CRYPTOGRAPHIC PRIMITIVES! THE DEVELOPERS OF LIBSODIUM ARE
// NOT RESPONSIBLE FOR SECURITY HOLES IN YOUR APPLICATION! THE DEVELOPERS OF GGWREN
// ARE NOT RESPONSIBLE FOR SECURITY HOLES IN YOUR APPLICATION!

import "gg" for GG

GG.bind("sodium")

class PasswordHash {
    //static hash(plaintext, salt, opsLimit, memLimit) { hash(plaintext, salt, opsLimit, memLimit,
    //        ALG_DEFAULT ) }
    // foreign static hash(plaintext, salt, opsLimit, memLimit, algorithm)

    // Calls crypto_pwhash_str.
    foreign static hash(plaintext, opsLimit, memLimit)
    foreign static verify(hashtext, plaintext)
    foreign static needsRehash(hashtext, opsLimit, memLimit)

    /*
    foreign static MEMLIMIT_INTERACTIVE
    foreign static MEMLIMIT_MAX
    foreign static MEMLIMIT_MIN
    foreign static MEMLIMIT_MODERATE
    foreign static MEMLIMIT_SENSITIVE

    foreign static OPSLIMIT_INTERACTIVE
    foreign static OPSLIMIT_MAX
    foreign static OPSLIMIT_MIN
    foreign static OPSLIMIT_MODERATE
    foreign static OPSLIMIT_SENSITIVE

    foreign static PASSWD_MIN
    foreign static PASSWD_MAX
    */
}

GG.bind(null)

