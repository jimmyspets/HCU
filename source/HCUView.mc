using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Calendar;
using Toybox.System as System;

var model;

class HCUView extends Ui.DataField {
    hidden const CENTER = Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER;
    hidden const HEADER_FONT = Gfx.FONT_XTINY;
    hidden const VALUE_FONT = Gfx.FONT_NUMBER_MILD;
	//hidden const VALUE_FONT = Gfx.FONT_MEDIUM;
    hidden const ZERO_TIME = "0:00";

    // Config
    hidden var is24Hour = true;
    hidden var isDistanceUnitsMetric = true;
    hidden var isSpeedUnitsMetric = true;
    hidden var cad = 0;
    hidden var cal = 0;
    hidden var temp = 0;
    hidden var speed = 0.0;
    hidden var avgSpeed = 0.0;
    hidden var pace = 0;
    hidden var avgPace = 0;
    hidden var alt = 0;
    hidden var totalAsc = 0;
    hidden var totalDes = 0;
    hidden var hr = 0;
    hidden var distance = "0:00";
    hidden var elapsedTime = "00:00";
    hidden var gpsSignal = 0; //Signal 0 not avail ... 4 good
    hidden var x;
    hidden var y;
    hidden var y1;
    hidden var y2;

	hidden var paceStr, avgPaceStr;    
    hidden var paceData = new DataQueue(10);

    function initialize() {
        DataField.initialize();
    }

    //hidden var mValue;

    //! Set your layout here. Anytime the size of obscurity of
    //! the draw context is changed this will be called.
    function onLayout(dc) {
    	populateConfigFromDeviceSettings();
        // calculate values for grid
        y = dc.getHeight() / 2 + 5;
        y1 = dc.getHeight() / 4.7 + 5;
        y2 = dc.getHeight() - y1 + 10;
        x = dc.getWidth() / 2;
        return true;
    }

    //! The given info object contains all the current workout
    //! information. Calculate a value and save it locally in this method.
    function compute(info) {
        // See Activity.Info in the documentation for available information.
    	if (info.currentSpeed != null) {
            paceData.add(info.currentSpeed);
        } else {
            paceData.reset();
        }
        
    	speed = calcNullable(info.currentSpeed, 0.0);
    	avgSpeed = calcNullable(info.averageSpeed, 0.0);
    	cad = calcNullable(info.currentCadence, 0);
    	cal = calcNullable(info.calories, 0);
    	hr = calcNullable(info.currentHeartRate, 0);
    	alt = calcNullable(info.altitude, 0);
    	totalAsc = calcNullable(info.totalAscent, 0);
    	totalDes = calcNullable(info.totalDescent, 0);
        calculateDistance(info);
        calculateElapsedTime(info);
        gpsSignal = info.currentLocationAccuracy;
    }

    //! Display the value you computed here. This will be called
    //! once a second when the data field is visible.
    function onUpdate(dc) {
        draw(dc);
        drawGrid(dc);
        drawGps(dc);
        drawBattery(dc);    
    }
    function populateConfigFromDeviceSettings() {
        isDistanceUnitsMetric = System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
        isSpeedUnitsMetric = System.getDeviceSettings().paceUnits == System.UNIT_METRIC;
        is24Hour = System.getDeviceSettings().is24Hour;
    }
    //! API functions
    
    //! function setLayout(layout) {}
    //! function onShow() {}
    //! function onHide() {}

    function drawGrid(dc) {
        setColor(dc, Gfx.COLOR_YELLOW);
        dc.setPenWidth(1);
		dc.drawLine(0, 22, dc.getWidth(), 22);
		dc.drawLine(0, 64, dc.getWidth(), 64);
		dc.drawLine(0, 106, dc.getWidth(), 106);  
        dc.setPenWidth(1);    
    }
    function draw(dc) {
        setColor(dc, Gfx.COLOR_DK_GRAY);
        dc.drawText(30, 28, HEADER_FONT, "CAD", CENTER);
        dc.drawText(90, 28, HEADER_FONT, "AVG PACE", CENTER);
        dc.drawText(162, 28, HEADER_FONT, "DIST (" + (isDistanceUnitsMetric ? "km" : "mi") + ")", CENTER);
        
        dc.drawText(30, 70, HEADER_FONT, "HR", CENTER);
        dc.drawText(90, 70, HEADER_FONT, "PACE", CENTER);
        dc.drawText(162, 70, HEADER_FONT, "TIME", CENTER);

        dc.drawText(30, 112, HEADER_FONT, "T.ASC", CENTER);
        dc.drawText(90, 112, HEADER_FONT, "T.DES", CENTER);
        dc.drawText(162, 112, HEADER_FONT, "ALT", CENTER);
        
        setColor(dc, Gfx.COLOR_BLACK);

        var clockTime = System.getClockTime();
        var time, ampm, timeX;
        if (is24Hour) {
            time = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%.2d")]);
            ampm = "";
            timeX = x;
        } else {
            time = Lang.format("$1$:$2$", [calculateAmPmHour(clockTime.hour), clockTime.min.format("%.2d")]);
            ampm = (clockTime.hour < 12) ? "am" : "pm";
            timeX = x;
        }
        dc.drawText(timeX, 8, Gfx.FONT_MEDIUM, time, CENTER);
        dc.drawText(timeX + 28, 8, HEADER_FONT, ampm, CENTER);
        
		txtVsOutline(30, 50, VALUE_FONT, cad.format("%d"), CENTER, Gfx.COLOR_BLACK, dc, 1);
		txtVsOutline(90, 50, VALUE_FONT, getMinutesPerKmOrMile(avgSpeed), CENTER, Gfx.COLOR_BLACK, dc, 1);
		txtVsOutline(162, 50, VALUE_FONT, distance, CENTER, Gfx.COLOR_DK_GREEN, dc, 1);
		
        txtVsOutline(30, 92, VALUE_FONT, hr.format("%d"), CENTER, Gfx.COLOR_BLACK, dc, 1);
        txtVsOutline(90, 92, VALUE_FONT, getMinutesPerKmOrMile(computeAverageSpeed()), CENTER, Gfx.COLOR_BLACK, dc, 1);
        txtVsOutline(162,92, VALUE_FONT, elapsedTime, CENTER, Gfx.COLOR_BLUE, dc, 1);
        
        txtVsOutline(30, 134, VALUE_FONT, totalAsc.format("%.4d"), CENTER, Gfx.COLOR_ORANGE, dc, 1);
        txtVsOutline(90, 134, VALUE_FONT, totalDes.format("%.4d"), CENTER, Gfx.COLOR_BLACK, dc, 1);
        txtVsOutline(162, 134, VALUE_FONT, alt.format("%.4d"), CENTER, Gfx.COLOR_BLACK, dc, 1);
    }

    function txtVsOutline(x, y, font, text, pos, color, dc, delta) {
        setColor(dc, Gfx.COLOR_WHITE);
        dc.drawText(x + delta, y, font, text, pos);
        dc.drawText(x - delta, y, font, text, pos);
        dc.drawText(x, y + delta, font, text, pos);
        dc.drawText(x, y - delta, font, text, pos);
        setColor(dc, color);
        dc.drawText(x, y, font, text, pos);
    }

    function setColor(dc, color) {
    	dc.setColor(color, Gfx.COLOR_TRANSPARENT);
    }

    function drawGps(dc) {
//        if (gpsSignal == 3 || gpsSignal == 4) {
//            setColor(dc, Gfx.COLOR_DK_GREEN);
//        } else {
//            setColor(dc, Gfx.COLOR_DK_RED);
//        }
//        dc.drawText(x + 63, 43, HEADER_FONT, "GPS", CENTER);
//        setColor(dc, Gfx.COLOR_BLACK);
       // gps
        if (gpsSignal < 2) {
            drawGpsSign(dc, 180, 0, Gfx.COLOR_LT_GRAY, Gfx.COLOR_LT_GRAY, Gfx.COLOR_LT_GRAY);
        } else if (gpsSignal == 2) {
            drawGpsSign(dc, 180, 0, Gfx.COLOR_DK_GREEN, Gfx.COLOR_LT_GRAY, Gfx.COLOR_LT_GRAY);
        } else if (gpsSignal == 3) {
            drawGpsSign(dc, 180, 0, Gfx.COLOR_DK_GREEN, Gfx.COLOR_DK_GREEN, Gfx.COLOR_LT_GRAY);
        } else {
            drawGpsSign(dc, 180, 0, Gfx.COLOR_DK_GREEN, Gfx.COLOR_DK_GREEN, Gfx.COLOR_DK_GREEN);
        }
    }

    function drawGpsSign(dc, xStart, yStart, color1, color2, color3) {
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart - 1, yStart + 11, 8, 10);
        dc.setColor(color1, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(xStart, yStart + 12, 6, 8);

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart + 6, yStart + 7, 8, 14);
        dc.setColor(color2, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(xStart + 7, yStart + 8, 6, 12);

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart + 13, yStart + 3, 8, 18);
        dc.setColor(color3, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(xStart + 14, yStart + 4, 6, 16);
    }
    
    function drawBattery(dc) {
        var yStart = 3;
        var xStart = 2;

        setColor(dc, Gfx.COLOR_BLACK);
        dc.drawRectangle(xStart, yStart, 29, 15);
        dc.drawRectangle(xStart + 1, yStart + 1, 27, 13);
        dc.fillRectangle(xStart + 29, yStart + 3, 2, 9);
        setColor(dc, Gfx.COLOR_DK_GREEN);
        for (var i = 0; i < (24 * System.getSystemStats().battery / 100); i = i + 3) {
            dc.fillRectangle(xStart + 3 + i, yStart + 3, 2, 9);    
        }
        
     //   setColor(dc, Gfx.COLOR_DK_GREEN);
     //   dc.drawText(xStart+18, yStart+6, HEADER_FONT, format("$1$%", [battery.format("%d")]), CENTER);
             
     //   setColor(dc, Gfx.COLOR_BLACK);
    }

	function calcNullable(nullableValue, defaultValue) {
	   if (nullableValue != null) {
	   	return nullableValue;
	   } else {
	   	return defaultValue;
   	   }	
	}

    function calculateDistance(info) {
        if (info.elapsedDistance != null && info.elapsedDistance > 0) {
            var distanceInUnit = info.elapsedDistance / (isDistanceUnitsMetric ? 1000 : 1610);
            var distanceHigh = distanceInUnit >= 100.0;
            var distanceFullString = distanceInUnit.toString();
            var commaPos = distanceFullString.find(".");
            var floatNumber = 3;
            if (distanceHigh) {
            	floatNumber = 2;
            }
            distance = distanceFullString.substring(0, commaPos + floatNumber);
        }
    }
    
    function calculateElapsedTime(info) {
        if (info.elapsedTime != null && info.elapsedTime > 0) {
            var hours = null;
            var minutes = info.elapsedTime / 1000 / 60;
            var seconds = info.elapsedTime / 1000 % 60;
            
            if (minutes >= 60) {
                hours = minutes / 60;
                minutes = minutes % 60;
            }
            
            if (hours == null) {
                elapsedTime = minutes.format("%02d") + ":" + seconds.format("%02d");
            } else {
                elapsedTime = hours.format("%02d") + ":" + minutes.format("%02d");// + ":" + seconds.format("%02d");
            }
//            var options = {:seconds => (info.elapsedTime / 1000)};
        }
    }

    function calculateSpeed(speedMetersPerSecond) {
        var kmOrMilesPerHour = speedMetersPerSecond * 3600.0 / (isSpeedUnitsMetric ? 1000 : 1610);
        return kmOrMilesPerHour;
    }

	function computeAverageSpeed() {
        var size = 0;
        var data = paceData.getData();
        var sumOfData = 0.0;
        for (var i = 0; i < data.size(); i++) {
            if (data[i] != null) {
                sumOfData = sumOfData + data[i];
                size++;
            }
        }
        if (sumOfData > 0) {
            return sumOfData / size;
        }
        return 0.0;
    }

	function compureAverageOneMinuteSpeed() {
        var size = 0;
        var data = paceDataOneMinute.getData();
        var sumOfData = 0.0;
        for (var i = 0; i < data.size(); i++) {
            if (data[i] != null) {
                sumOfData = sumOfData + data[i];
                size++;
            }
        }
        if (sumOfData > 0) {
            return sumOfData / size;
        }
        return 0.0;
    }

    function getMinutesPerKmOrMile(speedMetersPerSecond) {
        if (speedMetersPerSecond != null && speedMetersPerSecond > 0.2) {
            var metersPerMinute = speedMetersPerSecond * 60.0;
            var minutesPerKmOrMilesDecimal = (isDistanceUnitsMetric ? 1000 : 1610) / metersPerMinute;
            var minutesPerKmOrMilesFloor = minutesPerKmOrMilesDecimal.toNumber();
            var seconds = (minutesPerKmOrMilesDecimal - minutesPerKmOrMilesFloor) * 60;
            return minutesPerKmOrMilesDecimal.format("%02d") + ":" + seconds.format("%02d");
        }
        return ZERO_TIME;
    }

    function calculateAsc(ascMeters) {
        //return ascMeters / 1000;
		return ascMeters;
    }

    function calculateAmPmHour(hour) {
        if (hour == 0) {
            return 12;
        } else if (hour > 12) {
            return hour - 12;
        }
        return hour;
    }
}
//! A circular queue implementation.
//! @author Konrad Paumann
class DataQueue {

    //! the data array.
    hidden var data;
    hidden var maxSize = 0;
    hidden var pos = 0;

    //! precondition: size has to be >= 2
    function initialize(arraySize) {
        data = new[arraySize];
        maxSize = arraySize;
    }
    
    //! Add an element to the queue.
    function add(element) {
        data[pos] = element;
        pos = (pos + 1) % maxSize;
    }
    
    //! Reset the queue to its initial state.
    function reset() {
        for (var i = 0; i < data.size(); i++) {
            data[i] = null;
        }
        pos = 0;
    }
    
    //! Get the underlying data array.
    function getData() {
        return data;
    }

}
