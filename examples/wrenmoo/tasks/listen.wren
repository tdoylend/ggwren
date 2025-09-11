import "task" for Task
import "log" for Log
import "lib/io/net" for TcpListener

import "tasks/connection" for ConnectionTask

class ListenTask is Task {
    construct start(host, port) {
        super()
        _socket = TcpListener.bind(host, port)
        _socket.blocking = false
        Log.info("Listening on %(host):%(port)")
    }

    cleanUp() {
        _socket.close()
    }

    run() {
        while (true) {
            var socket = _socket.accept()
            if (socket) {
                socket.blocking = false
                Log.info("New connection from %(socket.peerAddress):%(socket.peerPort)!")
                ConnectionTask.start(socket)
            }
            Fiber.yield()
        }
    }
}
