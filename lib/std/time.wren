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

import "std.buffer" for Buffer

import "gg" for GG

GG.bind("builtins")

var MonthLengths     = [31,28,31,30,31,30,31,31,30,31,30,31]
var LeapMonthLengths = [31,29,31,30,31,30,31,31,30,31,30,31]

var MonthByYDay     = []
var LeapMonthByYDay = []

var DayInMonthByYDay     = []
var LeapDayInMonthByYDay = []

for (month in 1..MonthLengths.count) {
    for (day in 1..MonthLengths[month - 1]) {
        MonthByYDay.add(month)
        DayInMonthByYDay.add(day)
    }
    for (day in 1..LeapMonthLengths[month - 1]) {
        LeapMonthByYDay.add(month)
        LeapDayInMonthByYDay.add(day)
    }
}

class Datetime {
    static isoNow {
        var now = Time.now
        var days = (now / 86400).floor + 719162
        var seconds = now % 86400

        var year = 1
        year = year + (days / 146097).floor * 400
        days = days % 146097
        year = year + (days / 36524).floor * 100
        days = days % 36524
        year = year + (days / 1461).floor * 4
        days = days % 1461
        year = year + (days / 365).floor
        days = days % 365

        var isLeap = false
        if ((year % 4) == 0) isLeap = true
        if ((year % 100) == 0) isLeap = false
        if ((year % 400) == 0) isLeap = true

        var month
        var day
        if (isLeap) {
            month = LeapMonthByYDay[days]
            day = LeapDayInMonthByYDay[days]
        } else {
            month = MonthByYDay[days]
            day = DayInMonthByYDay[days]
        }

        var result = Buffer.new()
        result.writeByte((year / 1000).floor % 10 + 48)
        result.writeByte((year / 100).floor % 10 + 48)
        result.writeByte((year / 10).floor % 10 + 48)
        result.writeByte(year % 10 + 48)
        result.writeByte(45)
        result.writeByte((month / 10).floor % 10 + 48)
        result.writeByte(month % 10 + 48)
        result.writeByte(45)
        result.writeByte((day / 10).floor % 10 + 48)
        result.writeByte(day % 10 + 48)
        result.writeByte(32)

        var hour = (seconds / 3600).floor
        var minute = (seconds / 60).floor % 60
        var second = seconds.floor % 60
        var microsecond = (seconds * 1000000).floor
        
        result.writeByte((hour / 10).floor % 10 + 48)
        result.writeByte(hour % 10 + 48)
        result.writeByte(58)
        result.writeByte((minute / 10).floor % 10 + 48)
        result.writeByte(minute % 10 + 48)
        result.writeByte(58)
        result.writeByte((second / 10).floor % 10 + 48)
        result.writeByte(second % 10 + 48)
        result.writeByte(46)
        result.writeByte((microsecond / 100000).floor % 10 + 48)
        result.writeByte((microsecond / 10000).floor % 10 + 48)
        result.writeByte((microsecond / 1000).floor % 10 + 48)
        result.writeByte((microsecond / 100).floor % 10 + 48)
        result.writeByte((microsecond / 10).floor % 10 + 48)
        result.writeByte(microsecond.floor % 10 + 48)


        return result.toString
    }
}

class Time {
    foreign static now
    foreign static sleep(seconds)

    foreign static hpc
    foreign static hpcResolution
}

GG.bind(null)
