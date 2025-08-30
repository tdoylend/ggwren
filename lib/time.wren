import "gg" for GG

GG.bind("builtins")

class Time {
    foreign static now
    foreign static sleep(seconds)

    foreign static hpc
    foreign static hpcResolution
}

GG.bind(null)
