import "world" for Obj
import "log" for Log

class Auth {
    static authenticate(username, password) {
        var player = null
        for (p in Obj.players) {
            player = p
            if (player.answersTo(username)) {
                break
            } else {
                player = null
            }
        }
        var token = player && player.props["password"]
        if (token) {
            if (token.startsWith("plaintext:")) {
                if (token[token.indexOf(":")+1...token.bytes.count] == password) {
                    return player
                } else {
                    return null
                }
            } else {
                Fiber.abort("[internal] Unknown password algorithm: %(token)")
            }
        } else {
            return null
        }
    }
}
