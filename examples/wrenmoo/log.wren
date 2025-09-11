import "config" for Config

class Log {
    static announce(message) {
        System.print("\x1b[1m          * * * * * %(message) * * * * *\x1b[m")
    }

    static info(message) {
        System.print("\x1b[34;1m[INFO]\x1b[m    %(message)")
    }

    static warn(message) {
        System.print("\x1b[33;1m[WARNING]\x1b[m %(message)")
    }

    static error(message) {
        System.print("\x1b[31;1m[ERROR]\x1b[m   %(message)")
    }

    static debug(message) {
        if (Config.showDebugOutput) {
            System.print("\x1b[32m[DEBUG]\x1b[m   %(message)")
        }
    }
}
