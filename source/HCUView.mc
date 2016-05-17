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
    hidden var distance = 0;
    hidden var elapsedTime = "00:00";
    hidden var gpsSignal = 0; //Signal 0 not avail ... 4 good
    hidden var x;
    hidden var y;
    hidden var y1;
    hidden var y2;

	hidden var paceStr, avgPaceStr;    
    hidden var paceData = new DataQueue(10);
    
    //Configuration of control stations
    hidden var controlstationName = ["Kopmannaholmen","Skuleberget","Nordingra","Fjardbotten","Horno"];
    hidden var controlstationDistance = [30000,54000,84000,109000,129000]; //distance in meters
    hidden var controlstationMaxTime = [18000000,37800000,55800000,75600000,93600000]; //max time in milliseconds
    hidden var currentControlStation = 0;
    hidden var lastControlStation = 4;	
    hidden var distanceNextControlStation = 0;
    hidden var distanceEnd = 0;
    hidden var calculatedCurrentTime = 0; // calculated curent time at current position using controlstationPace in milliseconds
    hidden var controlstationPace;
  

    function initialize() {
        DataField.initialize();
        controlstationPace = new[lastControlStation + 1];
        for (var i = 0; i < lastControlStation + 1; i++) {
        	if (i == 0) {
           		controlstationPace[i] = controlstationDistance[i].toFloat() / controlstationMaxTime[i].toFloat();
   			}
       		else {
       			controlstationPace[i] = (controlstationDistance[i].toFloat() - controlstationDistance[i - 1].toFloat()) / (controlstationMaxTime[i].toFloat() - controlstationMaxTime[i - 1].toFloat()); 
   			}
        }
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
        currentControlStation = calcCurrentControlStation(info);
		calcDistanceNextControlStation(info);
		calcDistanceEnd(info);
//		calcCalculatedCurrentTime(info);
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
        //isDistanceUnitsMetric = System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
        //isSpeedUnitsMetric = System.getDeviceSettings().paceUnits == System.UNIT_METRIC;
        //is24Hour = System.getDeviceSettings().is24Hour;
    }
    //! API functions
    
    //! function setLayout(layout) {}
    //! function onShow() {}
    //! function onHide() {}

    //Functionality for ControlStations and distance, pace calculations
	function calcCurrentControlStation(info) {
        if (info.elapsedDistance != null && info.elapsedDistance > 0) {
            if (info.elapsedDistance > controlstationDistance[currentControlStation] and currentControlStation < lastControlStation) {
            	currentControlStation += 1;
        	}        
        }
        return currentControlStation;   
    }
    
    function calculatedCurrentTime(info) {
        if (info.elapsedDistance != null && info.elapsedDistance > 0) {
 //           if currentControlStation = 0 {
 //           	var paceCurrentControlstation = controlstationDistance[currentControlStation] / controlstationMaxTime[currentControlStation]
 //           }
		}  	      	
    }  
      
    function calcDistanceNextControlStation(info) {
        if (info.elapsedDistance != null && info.elapsedDistance > 0) {
            if ((controlstationDistance[currentControlStation] - info.elapsedDistance)>0) {
            	var distanceNCSInUnit = (controlstationDistance[currentControlStation] - info.elapsedDistance) / 1000;
	            var distanceNCSHigh = distanceNCSInUnit >= 10.0;
    	        var distanceNCSVHigh = distanceNCSInUnit >= 100.0;
        	    var distanceNCSFullString = distanceNCSInUnit.toString();
	            var commaPos = distanceNCSFullString.find(".");
    	        var floatNumber = 3;
        	    if (distanceNCSHigh) {
            		floatNumber = 2;
	            }
    	        if (distanceNCSVHigh) {
        	    	floatNumber = 0;
	        	}
    	        distanceNextControlStation = distanceNCSFullString.substring(0, commaPos + floatNumber);
  	      	}
			else {
  	      		distanceNextControlStation = " ";
  	      	}
		}  	      	
    }
    
    function calcDistanceEnd(info) {
        if (info.elapsedDistance != null && info.elapsedDistance > 0) {
            if ((controlstationDistance[lastControlStation] - info.elapsedDistance)>0) {
            	var distanceEndInUnit = (controlstationDistance[lastControlStation] - info.elapsedDistance) / 1000;
	            var distanceEndHigh = distanceEndInUnit >= 10.0;
    	        var distanceEndVHigh = distanceEndInUnit >= 100.0;
        	    var distanceEndFullString = distanceEndInUnit.toString();
	            var commaPos = distanceEndFullString.find(".");
    	        var floatNumber = 3;
        	    if (distanceEndHigh) {
            		floatNumber = 2;
	            }
    	        if (distanceEndVHigh) {
        	    	floatNumber = 0;
	        	}
    	        distanceEnd = distanceEndFullString.substring(0, commaPos + floatNumber);
  	      	}
			else {
  	      		distanceEnd = " ";
  	      	}
		}  	      	
    }
    

    function drawGrid(dc) {
        setColor(dc, Gfx.COLOR_YELLOW);
        dc.setPenWidth(1);
		dc.drawLine(0, 35, dc.getWidth(), 35);
		dc.drawLine(0, 95, dc.getWidth(), 95);
		dc.drawLine(0, 160, dc.getWidth(), 160);  
        dc.setPenWidth(1);    
    }
    function draw(dc) {
        setColor(dc, Gfx.COLOR_DK_GRAY);

        dc.drawText(60, 43, HEADER_FONT, "NC Dist", CENTER);
        dc.drawText(150, 43, HEADER_FONT, "NC Pace", CENTER);
        
        dc.drawText(30, 103, HEADER_FONT, "HR", CENTER);
        dc.drawText(100, 103, HEADER_FONT, "AHD/BHD", CENTER);
        dc.drawText(172,103, HEADER_FONT, "Cur Pace", CENTER);

        dc.drawText(60, 168, HEADER_FONT, "ETF", CENTER);
        dc.drawText(162,168, HEADER_FONT, "Dist Rem", CENTER);
        
        setColor(dc, Gfx.COLOR_BLACK);

        dc.drawText(110, 20, VALUE_FONT, controlstationName[currentControlStation], CENTER);

        txtVsOutline(60, 65, VALUE_FONT, distanceNextControlStation, CENTER, Gfx.COLOR_BLACK, dc, 1);
        txtVsOutline(150, 65, VALUE_FONT, hr.format("%d"), CENTER, Gfx.COLOR_BLACK, dc, 1);

   		txtVsOutline(30, 130, VALUE_FONT, hr.format("%d"), CENTER, Gfx.COLOR_BLACK, dc, 1);
		txtVsOutline(100, 130, VALUE_FONT, getMinutesPerKmOrMile(avgSpeed), CENTER, Gfx.COLOR_BLACK, dc, 1);
		txtVsOutline(162,130, VALUE_FONT, getMinutesPerKmOrMile(computeAverageSpeed()), CENTER, Gfx.COLOR_DK_GREEN, dc, 1);
		
        txtVsOutline(60, 190, VALUE_FONT, distance, CENTER, Gfx.COLOR_BLACK, dc, 1);
        txtVsOutline(105,190, VALUE_FONT, elapsedTime, CENTER, Gfx.COLOR_BLUE, dc, 1); //temporary for debug
        txtVsOutline(150,190, VALUE_FONT, distanceEnd, CENTER, Gfx.COLOR_BLACK, dc, 1);
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
        var yStart = 34;
        var xStart = 20;

       setColor(dc, Gfx.COLOR_DK_GREEN);
		dc.fillRectangle(xStart, yStart , 170 * gpsSignal / 4, 3); 
		
   }
    
    function drawBattery(dc) {
        var yStart = 94;
        var xStart = 1;

       setColor(dc, Gfx.COLOR_DK_GREEN);
		dc.fillRectangle(xStart, yStart , 216 * System.getSystemStats().battery / 100, 3);        
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
            var distanceInUnit = info.elapsedDistance / 1000;
            var distanceHigh = distanceInUnit >= 10.0;
            var distanceVHigh = distanceInUnit >= 100.0;
            var distanceFullString = distanceInUnit.toString();
            var commaPos = distanceFullString.find(".");
            var floatNumber = 3;
            if (distanceHigh) {
            	floatNumber = 2;
            }
            if (distanceVHigh) {
            	floatNumber = 0;
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
