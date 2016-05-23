using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
//using Toybox.Time as Time;
//using Toybox.Time.Gregorian as Calendar;
using Toybox.System as System;

var model;

class HCUView extends Ui.DataField {
    hidden const CENTER = Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER;
    hidden const HEADER_FONT = Gfx.FONT_XTINY;
    hidden const VALUE_FONT = Gfx.FONT_NUMBER_MEDIUM;
	//hidden const VALUE_FONT = Gfx.FONT_MEDIUM;
    hidden const ZERO_TIME = "0:00";

    // Config
    hidden var avgPace = 0;
    hidden var hr = 0;
    hidden var distance = 0;
    hidden var elapsedTime = "00:00";
    hidden var gpsSignal = 0; //Signal 0 not avail ... 4 good
    hidden var x;
    hidden var y;
    hidden var y1;
    hidden var y2;

    
    //Configuration of control stations
    hidden var controlstationName = ["Kopmannaholmen","Skuleberget","Nordingra","Fjardbotten","Horno"];
    hidden var controlstationDistance = [30000,54000,84000,109000,129000]; //distance in meters
    hidden var controlstationMaxTime = [18000000,37800000,55800000,75600000,93600000]; //max time in milliseconds
    hidden var currentControlStation = 0;
    hidden var lastControlStation = 4;	
    hidden var distanceNextControlStation = 0;
    hidden var paceNextControlStation = 0; // in milliseconds per kilometer
    hidden var distanceEnd = controlstationDistance[lastControlStation]/1000;
    hidden var calculatedPlannedTime = 0; // calculated curent time at current position using controlstationPace in milliseconds
    hidden var millisecondsAheadBehind = 0;
    hidden var controlstationPace; //the max pace for the segment
    hidden var estimatedFinnishTime = 0; //Estimated finnish time in milliseconds 
    hidden var paceAvgDistance = [0,0,0,0,0,0,0,0,0,0];
    hidden var paceAvgTime = [0,0,0,0,0,0,0,0,0,0];
    hidden var paceAvg = 0;
    hidden var nextCalcTime = 10000;
    hidden var percentDone = 0;
  

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
    	hr = calcNullable(info.currentHeartRate, 0);
        gpsSignal = info.currentLocationAccuracy;
		//Debug info
		if (info.elapsedDistance != null && info.elapsedDistance > 10 && info.elapsedTime != null && info.elapsedTime >= nextCalcTime) {
        	calculateDistance(info);
   	    	calculateElapsedTime(info);
       		currentControlStation = calcCurrentControlStation(info);
			calcDistanceNextControlStation(info);
			calcDistanceEnd(info);
			calcCalculatedPlannedTime(info);
			calcAheadBehind(info);
			calcEstimatedFinnishTime(info);
			calcPaceAvg(info);
        	System.println("AheadBehind " + displayHMS(millisecondsAheadBehind) + " calculatedPlannedTime " + 
   	    	displayHMS(calculatedPlannedTime) + " info.elapsedDistance " + info.elapsedDistance + " info.elapsedTime " + info.elapsedTime + 
       		" controlstationMaxTime " + controlstationMaxTime[currentControlStation] + " paceNextControlStation " + displayHMS(paceNextControlStation));
			percentDone = info.elapsedDistance / controlstationMaxTime[lastControlStation];
			nextCalcTime = info.elapsedTime + 10000;	
		}
    }

    //! Display the value you computed here. This will be called
    //! once a second when the data field is visible.
    function onUpdate(dc) {
        draw(dc);
        drawGrid(dc);
        drawGps(dc);
        drawBattery(dc); 
        drawDone(dc);   
    }
    //! API functions
    
    //! function setLayout(layout) {}
    //! function onShow() {}
    //! function onHide() {}

    //Functionality for ControlStations and distance, pace calculations
	function calcCurrentControlStation(info) {
        if (info.elapsedDistance > controlstationDistance[currentControlStation] and currentControlStation < lastControlStation) {
           	currentControlStation += 1;        
        }
        return currentControlStation;   
    }
    
    function calcCalculatedPlannedTime(info) {
        if (currentControlStation == 0) {
         	calculatedPlannedTime =  info.elapsedDistance / controlstationPace[currentControlStation];
           	//System.println(calculatedPlannedTime + " " + info.elapsedDistance + " " + info.elapsedTime);
		}
		else {
			calculatedPlannedTime =  (info.elapsedDistance - controlstationDistance[currentControlStation]) / 
			controlstationPace[currentControlStation] + controlstationMaxTime[currentControlStation - 1];
		}  	      	
    }  
      
    function calcDistanceNextControlStation(info) {
         if ((controlstationDistance[currentControlStation] - info.elapsedDistance)>0) {
           	if ((controlstationMaxTime[currentControlStation] - info.elapsedTime)>0) {
            	paceNextControlStation = (controlstationMaxTime[currentControlStation] - info.elapsedTime) / 
            	(controlstationDistance[currentControlStation] - info.elapsedDistance) * 1000;
           	}
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
       		paceNextControlStation = " ";
		}  	      	
    }
    
    function calcPaceAvg(info) {
    	paceAvg = (info.elapsedTime - paceAvgTime[0]) / 
    	(info.elapsedDistance - paceAvgDistance[0]) * 1000;
    	if (info.elapsedTime > paceAvgTime[9] + 30000) {
    		for (var i = 0; i < 9; i++) {
    			paceAvgTime[i] = paceAvgTime[i+1];
    			paceAvgDistance[i] = paceAvgDistance[i+1]; 
    		}
    		paceAvgTime[9] = info.elapsedTime;
    		paceAvgDistance[9] = info.elapsedDistance;
    	}
    }
    
    function calcDistanceEnd(info) {
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
    
    function calcAheadBehind(info) {
        millisecondsAheadBehind = calculatedPlannedTime - info.elapsedTime;
    }
    
    function calcEstimatedFinnishTime(info) {
   		estimatedFinnishTime = controlstationMaxTime[lastControlStation] - (millisecondsAheadBehind / info.elapsedDistance * controlstationDistance[lastControlStation]);
	}
    
    function displayHMS(milliseconds) {
        if (milliseconds != null) {
        	var millisecondsInt = milliseconds.toNumber();
            var hours = null;
            var minutes = millisecondsInt / 1000 / 60;
            var seconds = millisecondsInt / 1000 % 60;
            
            if (minutes >= 60) {
                hours = minutes / 60;
                minutes = minutes % 60;
            }
            
            if (hours == null) {
                return (minutes.format("%02d") + ":" + seconds.format("%02d"));
            } else {
                return (hours.format("%02d") + ":" + minutes.format("%02d"));
            }
        }
        return " ";
    }

    function drawGrid(dc) {
        setColor(dc, Gfx.COLOR_YELLOW);
        dc.setPenWidth(1);
		dc.drawLine(0, 31, dc.getWidth(), 31);
		dc.drawLine(0, 91, dc.getWidth(), 91);
		dc.drawLine(0, 150, dc.getWidth(), 150);  
		dc.drawLine(105, 31, 105, 91);  
		dc.drawLine(57, 91, 57, 150);  
		dc.drawLine(135, 91, 135, 150);  
		dc.drawLine(105, 150, 105, dc.getHeight());  
    }
    function draw(dc) {
        setColor(dc, Gfx.COLOR_DK_GRAY);

        dc.drawText(60, 40, HEADER_FONT, "NC Dist", CENTER);
        dc.drawText(150, 40, HEADER_FONT, "NC Pace", CENTER);
        
        dc.drawText(30, 99, HEADER_FONT, "HR", CENTER);
        dc.drawText(95,99, HEADER_FONT, "AHD/BHD", CENTER);
        dc.drawText(172,99, HEADER_FONT, "Cur Pace", CENTER);

        dc.drawText(75, 199, HEADER_FONT, "Rem", CENTER);
        dc.drawText(145,199, HEADER_FONT, "ETF", CENTER);
        
        setColor(dc, Gfx.COLOR_BLACK);

        dc.drawText(110, 20, Gfx.FONT_TINY, controlstationName[currentControlStation], CENTER);

        txtVsOutline(60, 64, VALUE_FONT, distanceNextControlStation, CENTER, Gfx.COLOR_BLACK, dc, 1);
        txtVsOutline(150, 64, VALUE_FONT, displayHMS(paceNextControlStation), CENTER, Gfx.COLOR_BLACK, dc, 1);

   		txtVsOutline(28, 124, VALUE_FONT, hr.format("%d"), CENTER, Gfx.COLOR_BLACK, dc, 1);
   		if (millisecondsAheadBehind < 0) {
			txtVsOutline(96, 124, VALUE_FONT, displayHMS(-millisecondsAheadBehind), CENTER, Gfx.COLOR_RED, dc, 1);
		}
		else {
			txtVsOutline(96, 124, VALUE_FONT, displayHMS(millisecondsAheadBehind), CENTER, Gfx.COLOR_DK_GREEN, dc, 1);
		}
		if (paceAvg > paceNextControlStation) {
			txtVsOutline(176,124, VALUE_FONT, displayHMS(paceAvg), CENTER, Gfx.COLOR_RED, dc, 1);
		}
		else {
			txtVsOutline(176,124, VALUE_FONT, displayHMS(paceAvg), CENTER, Gfx.COLOR_DK_GREEN, dc, 1);
		}
		
        txtVsOutline(70, 170, VALUE_FONT, distanceEnd, CENTER, Gfx.COLOR_BLACK, dc, 1);
        //txtVsOutline(105,160, VALUE_FONT, distance, CENTER, Gfx.COLOR_BLUE, dc, 1); //temporary for debug
        //txtVsOutline(105,190, VALUE_FONT, elapsedTime, CENTER, Gfx.COLOR_BLUE, dc, 1); //temporary for debug
        txtVsOutline(145,170, VALUE_FONT, displayHMS(estimatedFinnishTime), CENTER, Gfx.COLOR_BLACK, dc, 1);
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
        var yStart = 31;
        var xStart = 20;

       setColor(dc, Gfx.COLOR_DK_GREEN);
		dc.fillRectangle(xStart, yStart , 169 * gpsSignal / 4, 3); 
		
   }
    
    function drawBattery(dc) {
        var yStart = 90;
        var xStart = 1;

       setColor(dc, Gfx.COLOR_DK_GREEN);
		dc.fillRectangle(xStart, yStart , 216 * System.getSystemStats().battery / 100, 3);        
    }
    
    function drawDone(dc) {
        var yStart = 149;
        var xStart = 8;

      	setColor(dc, Gfx.COLOR_DK_GREEN);
		dc.fillRectangle(xStart, yStart , 202 * percentDone , 3);        
    }

	function calcNullable(nullableValue, defaultValue) {
	   if (nullableValue != null) {
	   	return nullableValue;
	   } else {
	   	return defaultValue;
   	   }	
	}

    function calculateDistance(info) {
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
    
    function calculateElapsedTime(info) {
        var hours = null;
        var minutes = info.elapsedTime / 1000 / 60;
        var seconds = info.elapsedTime / 1000 % 60;
           
        if (minutes >= 60) {
            hours = minutes / 60;
            minutes = minutes % 60;
        }
           
        if (hours == null) {
            elapsedTime = minutes.format("%02d") + ":" + seconds.format("%02d");
        } 
        else {
            elapsedTime = hours.format("%02d") + ":" + minutes.format("%02d");// + ":" + seconds.format("%02d");
        }
    }
}
