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

var WeekdayAbbr = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
var MonthAbbr = [null, "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

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
    static now { Datetime.fromTimestamp(Time.now) }
    construct fromTimestamp(timestamp) {
        var days = (timestamp / 86400).floor + 719162
        var seconds = timestamp % 86400

        _weekday = (days+1) % 7

        _year = 1
        _year = _year + (days / 146097).floor * 400
        days = days % 146097
        _year = _year + (days / 36524).floor * 100
        days = days % 36524
        _year = _year + (days / 1461).floor * 4
        days = days % 1461
        _year = _year + (days / 365).floor
        days = days % 365

        var isLeap = false
        if ((_year % 4) == 0) isLeap = true
        if ((_year % 100) == 0) isLeap = false
        if ((_year % 400) == 0) isLeap = true

        if (isLeap) {
            _month = LeapMonthByYDay[days]
            _day = LeapDayInMonthByYDay[days]
        } else {
            _month = MonthByYDay[days]
            _day = DayInMonthByYDay[days]
        }
        _hour = (seconds / 3600).floor
        _minute = (seconds / 60).floor % 60
        _second = seconds.floor % 60
        _microsecond = (seconds * 1000000).floor
    }

    weekday { _weekday }
    year { _year }
    month { _month }
    day { _day }
    hour { _hour }
    minute { _minute }
    second { _second }
    microsecond { _microsecond }

    toRFC {
        var result = Buffer.new()
        result.write("%(WeekdayAbbr[_weekday]), %(day) %(MonthAbbr[_month]) %(year) ")
        result.writeByte((_hour / 10).floor % 10 + 48)
        result.writeByte(_hour % 10 + 48)
        result.writeByte(58)
        result.writeByte((_minute / 10).floor % 10 + 48)
        result.writeByte(_minute % 10 + 48)
        result.writeByte(58)
        result.writeByte((_second / 10).floor % 10 + 48)
        result.writeByte(_second % 10 + 48)
        result.write(" UTC")
        return result.toString
    }
    
    toISO {
        var result = Buffer.new()
        result.writeByte((_year / 1000).floor % 10 + 48)
        result.writeByte((_year / 100).floor % 10 + 48)
        result.writeByte((_year / 10).floor % 10 + 48)
        result.writeByte(_year % 10 + 48)
        result.writeByte(45)
        result.writeByte((_month / 10).floor % 10 + 48)
        result.writeByte(_month % 10 + 48)
        result.writeByte(45)
        result.writeByte((_day / 10).floor % 10 + 48)
        result.writeByte(_day % 10 + 48)
        result.writeByte(32)
        result.writeByte((_hour / 10).floor % 10 + 48)
        result.writeByte(_hour % 10 + 48)
        result.writeByte(58)
        result.writeByte((_minute / 10).floor % 10 + 48)
        result.writeByte(_minute % 10 + 48)
        result.writeByte(58)
        result.writeByte((_second / 10).floor % 10 + 48)
        result.writeByte(_second % 10 + 48)
        result.writeByte(46)
        result.writeByte((_microsecond / 100000).floor % 10 + 48)
        result.writeByte((_microsecond / 10000).floor % 10 + 48)
        result.writeByte((_microsecond / 1000).floor % 10 + 48)
        result.writeByte((_microsecond / 100).floor % 10 + 48)
        result.writeByte((_microsecond / 10).floor % 10 + 48)
        result.writeByte(_microsecond.floor % 10 + 48)
        return result.toString
    }


    static isoNow { iso(Time.now) }
    static iso(timestamp) { Datetime.fromTimestamp(timestamp).toISO }
}

class Time {
    foreign static now
    foreign static sleep(seconds)

    foreign static hpc
    foreign static hpcResolution
}

GG.bind(null)
