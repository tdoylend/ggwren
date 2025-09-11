import "lib/io/fs" for Fs
import "gg" for GG

class Config {
    static host { "localhost" }
    static port { "9999" }
    static debugMode { true }
    static showDebugOutput { true }
    static idleFrameTime { 0.2 }

    static dbPath { Fs.join(GG.scriptDir, "main.db") }

    static version { "0.0.1" }
}
