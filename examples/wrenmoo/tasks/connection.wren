import "lib/time" for Time

import "auth" for Auth
import "task" for Task
import "format" for Fmt
import "world" for Obj, Config
import "log" for Log as Log_

class ConnectionTask is Task {
    construct start(stream) {
        super()
        _stream = stream
        _player = 0

        _sendQueue = ""
        _recvQueue = ""

        _inputLines = []
        _gameOutput = []

        _fmt = Fmt.new()
    }

    info(message) { Log_.info("[%(name)] %(message)") }
    debug(message) { Log_.debug("[%(name)] %(message)") }
    announce(message) { Log_.announce("[%(name)] %(message)") }
    warn(message) { Log_.warn("[%(name)] %(message)") }
    error(message) { Log_.error("[%(name)] %(message)") }

    name {
        var obj = Obj[_player]
        var playerName
        if (obj) {
            playerName = obj.name
        } else {
            playerName = "(unknown)"
        }
        return "%(playerName) @ %(_stream.peerAddress):%(_stream.peerPort)"
    }

    print(message) {
        _sendQueue = _sendQueue + _fmt.format(message)
    }

    cleanUp() {
        if (_stream.isOpen) {
            _stream.close()
        }
    }

    updateStream() {
        if (_stream.isOpen) {
            if (_sendQueue.bytes.count > 0) {
                var sent = _stream.write(_sendQueue[0...4096.min(_sendQueue.bytes.count)])
                if (sent) _sendQueue = _sendQueue[sent..._sendQueue.bytes.count]
            }
            var received = _stream.read(4096)
            if (received) {
                _recvQueue = _recvQueue + received
            }
            if (received && (received.bytes.count == 0)) {
                info("Peer closed connection.")
                finish()
            }
            var newlineIndex = _recvQueue.indexOf("\n")
            if (newlineIndex > -1) {
                _inputLines.add(_recvQueue[0...newlineIndex].trimEnd("\r"))
                _recvQueue = _recvQueue[newlineIndex+1..._recvQueue.bytes.count]
            }
        }
    }

    prompt() {
        while (true) {
            updateStream()
            if (_inputLines.count > 0) return _inputLines.removeAt(0)
            Fiber.yield()
        }
    }

    sleep(time) {
        var rendezvous = Time.now + time
        while (Time.now < rendezvous) Fiber.yield()
    }

    loginLoop() {
        while (1) {
            var line = prompt().trim().upper
            if (line == "LOGIN") {
                while (1) {
                    print("Please enter your user name.")
                    var username = prompt().trim()
                    print("Please enter your password.")
                    var password = prompt()
                    _player = Auth.authenticate(username, password)
                    if (_player) {
                        print("You are %(_player.name).")
                        return
                    } else {
                        print("Either the username or password you entered is incorrect.")
                        sleep(1.5)
                    }
                }
            } else if (line == "GUEST") {
                print("No guest accounts are available at the moment. Please try again in a "+
                        "little while.")
            } else {
                print("I don't know how to '%(line)'.")
            }
        }
    }

    doCommand(command) {
        command = command.trim()
        if (command.startsWith("'") || command.startsWith("\"")) {
            var speech = command[1...command.bytes.count].trim()
            _player.say("%(_player.name): %(speech)")
        } else if (command.startsWith("*") || command.startsWith(":")) {
            var emote = command[1...command.bytes.count].trim()
            if (emote.count > 0) {
                if (!"().!?".contains(emote[-1])) emote = emote + "."
            }
            _player.say("%(_player.name) %(emote)")
        }
    }

    gameLoop() {
        while (1) {
            if (_gameOutput.count > 0) {
                for (elem in _gameOutput) print(elem)
                _gameOutput.clear()
            }
            updateStream()
            if (_inputLines.count > 0) {
                var line = _inputLines.removeAt(0)
                doCommand(line)
            }
            Fiber.yield()
        }
    }

    run() {
        print(Config["welcome"] || "")

        loginLoop()
        gameLoop()
    }
}
