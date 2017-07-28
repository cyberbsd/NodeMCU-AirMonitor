local moduleName = "SensorDetector"
local M = {}
_G[moduleName] = M



local enablePMSPin = 4
local uartTimer = tmr.create()
local rcv = ""
bIsPms5003 = false
bIsPms5003s = false
bIsPms5003t = false
bExistSi7021 = false


function M.stopAllOutPut()
     print("stopAllOutPut")
     gpio.mode(enablePMSPin,gpio.OUTPUT)
     gpio.write(enablePMSPin,gpio.LOW)
     uart.setup( 0, 115200, 8, 0, 1, 0 )
     uart.on("data", 0,
       function(data)
          --print("uart restored")
       end, 1)
     gpio.mode(0, gpio.OUTPUT)  
     gpio.write(0,gpio.HIGH)
end

function M.startAllOutPut()
     print("startAllOutPut")
     gpio.mode(enablePMSPin,gpio.OUTPUT)
     gpio.write(enablePMSPin,gpio.HIGH)
     gpio.mode(0, gpio.OUTPUT)  
     --gpio.write(0,gpio.LOW)
end

function M.detectSi7021()
     --print("detectSi7021")
     local si7021 = require("si7021")
	SDA_PIN = 5 -- sda pin
	SCL_PIN = 6 -- scl pin
	
	--si7021.init(SDA_PIN, SCL_PIN)
	--si7021.read(OSS)
	--Hum = si7021.getHumidity()
	--Temp = si7021.getTemperature()
	--print(Temp)
	--if(Temp~=nil)then
		--LeweiMqtt.appendSensorValue("H1",Hum)
          --LeweiMqtt.appendSensorValue("T1",Temp)
          --OLED.showSensorValues()
		--bExistSi7021 = true	
     --else
          --si7021 = nil
	--end
end

function M.detectSensor()
          si7021Timer = tmr.create()
          si7021Timer:register(20000, tmr.ALARM_AUTO, function()
               --M.detectSi7021()
          end)
          si7021Timer:start()
          OLED.init_OLED(1,2)
     M.startAllOutPut()
     M.enablUart()
end

function M.calcAQI(pNum)
     --local clow = {0,15.5,40.5,65.5,150.5,250.5,350.5}
     --local chigh = {15.4,40.4,65.4,150.4,250.4,350.4,500.4}
     --local ilow = {0,51,101,151,201,301,401}
     --local ihigh = {50,100,150,200,300,400,500}
     local ipm25 = {0,35,75,115,150,250,350,500}
     local laqi = {0,50,100,150,200,300,400,500}
     local result={"优","良","轻度污染","中度污染","重度污染","严重污染","爆表"}
     --print(table.getn(chigh))
     aqiLevel = 8
     for i = 1,table.getn(ipm25),1 do
          if(pNum<ipm25[i])then
               aqiLevel = i
               break
          end
     end
     --aqiNum = (ihigh[aqiLevel]-ilow[aqiLevel])/(chigh[aqiLevel]-clow[aqiLevel])*(pNum-clow[aqiLevel])+ilow[aqiLevel]
     aqiNum = (laqi[aqiLevel]-laqi[aqiLevel-1])/(ipm25[aqiLevel]-ipm25[aqiLevel-1])*(pNum-ipm25[aqiLevel-1])+laqi[aqiLevel-1]
     return math.floor(aqiNum),result[aqiLevel-1]
end

function M.resolveData(data)
     --print("resolveData"..data)
     --Socket.send(data)
     gpio.write(0,gpio.LOW)
     if((((string.byte(data,1)==0x42) and(string.byte(data,2)==0x4d)) or ((string.byte(data,1)==0x32) and(string.byte(data,2)==0x3d))) and string.byte(data,13)~=nil and string.byte(data,14)~=nil)  then
          
          if((string.byte(data,1)==0x32) and(string.byte(data,2)==0x3d)) then
               --Teetc.com
               pm25 = (string.byte(data,7)*256+string.byte(data,8))
          else
               pm10 = (string.byte(data,11)*256+string.byte(data,12))
               pm25 = (string.byte(data,13)*256+string.byte(data,14))
               pm100 = (string.byte(data,15)*256+string.byte(data,16))
               if(string.byte(data,29) ~=nil and string.byte(data,30)~=nil)then
                   --if(string.byte(data,29) == 0x71)then
                    if(string.byte(data,29) ~= 0xE1)then
                         hcho = nil
                         if(string.byte(data,29) ~= 0x71)then
                             bIsPms5003 = true
                         else
                             bIsPms5003t = true
                             Hum = (string.byte(data,25)*256+string.byte(data,26))/10
                             Temp = (string.byte(data,27)*256+string.byte(data,28))/10
                             --OLED.showInfo("pm5003t:"..pm25,2)
                         end
                         bIsPms5003s = false
                         --OLED.showInfo("pm5003:"..pm25,2)
                    else
                         bIsPms5003 = false
                         bIsPms5003s = true
                         --OLED.showInfo("pm5003s:"..pm25,2)
                         hcho = (string.byte(data,29)*256+string.byte(data,30))/1000
                         LeweiMqtt.appendSensorValue("HCHO",hcho)
                         --Socket.send(hcho)
                         --Socket.send(type(LeweiMqtt.getSensorValues())..node.heap().."\n\r")
                    end
               end
          end
          aqi,result = M.calcAQI(pm25)
          if(bIsPms5003t) then
              LeweiMqtt.appendSensorValue("H1",Hum)                   
              LeweiMqtt.appendSensorValue("T1",Temp)          
          end
          LeweiMqtt.appendSensorValue("dust",pm25)
          LeweiMqtt.appendSensorValue("AQI",aqi)
          LeweiMqtt.appendSensorValue("PM1.0",pm10)
          LeweiMqtt.appendSensorValue("PM10",pm100)

          OLED.showSensorValues()
          --OLED.showInfo("pm5003s:",2)
     else
          OLED.showInfo("No Sensor Recognised",2)
     end
     gpio.write(0,gpio.HIGH)
end

function M.enablUart()
     print("enablUart")
     uart.setup( 0, 9600, 8, 0, 1, 0 )
     uart.on("data", 0,
       function(data)
          uartTimer:register(10, tmr.ALARM_SINGLE, function()
          M.resolveData(rcv)
          uartTimer:stop()
          rcv = ""
          end)
          rcv = rcv..data
          uartTimer:start()
     end, 0)
end
return M
