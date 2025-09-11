import "task" for Task
import "format" for Fmt
import "world" for World, Obj

class ConnectionTask is Task {
    construct start(stream) {
        super()
        _stream = stream
        _player = 0

        _sendQueue = ""
        _recvQueue = ""

        _fmt = Fmt.new()
    }

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

    run() {
        print(World.config["welcome"] || "")
    }
}
