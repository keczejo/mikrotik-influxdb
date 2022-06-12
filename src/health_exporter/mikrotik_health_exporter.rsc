:global influxDBURL "http://influx.db.server:8086/api/v2/write?org=ORAGNIZATION&bucket=BUCKET&precision=ns"

:local version DEV
:local scriptRunDatetime
:local deviceIdentity
:local deviceMemFree
:local deviceMemTotal
:local deviceDiskFree
:local deviceDiskTotal
:local deviceDiskBadBlocks
:local deviceDiskWriteSectSinceReboot
:local deviceDiskWriteSectTotal
:local deviceCPULoad
:local currentPostRequestPayloadPart
:local postRequestPayloadParts ({})
:local postRequestPayload


:if ([:tostr [:typeof $influxDBURL ]] = "nothing" ) do={
	:error "Error: can't read out variable \$influxDBURL. InfluxDB URL not set, exiting."
}

:set scriptRunDatetime ( [:tostr [ /system clock get date ]] . " " . [:tostr [ /system clock get time ]] )
:set deviceIdentity ( [ /system identity get name] )
:set deviceMemFree ( [ /system resource get free-memory ] )
:set deviceMemTotal ( [ /system resource get total-memory ] )
:set deviceDiskFree ( [ /system resource get free-hdd-space ] )
:set deviceDiskTotal ( [ /system resource get total-hdd-space ] )
:set deviceDiskBadBlocks ( [ /system resource get bad-blocks ] )
:set deviceDiskWriteSectSinceReboot ( [ /system resource get write-sect-since-reboot ] )
:set deviceDiskWriteSectTotal ( [ /system resource get write-sect-total ] )
:set deviceCPULoad ( [ /system resource get cpu-load ] )

:log debug message="HealthMon: scriptRunDatetime: '$scriptRunDatetime'"
:log debug message="HealthMon: deviceIdentity: '$deviceIdentity'"
:log debug message="HealthMon: deviceMemFree: '$deviceMemFree'"
:log debug message="HealthMon: deviceMemTotal: '$deviceMemTotal'"
:log debug message="HealthMon: deviceDiskFree: '$deviceDiskFree'"
:log debug message="HealthMon: deviceDiskTotal: '$deviceDiskTotal'"
:log debug message="HealthMon: deviceDiskBadBlocks: '$deviceDiskBadBlocks'"
:log debug message="HealthMon: deviceDiskWriteSectSinceReboot: '$deviceDiskWriteSectSinceReboot'"
:log debug message="HealthMon: deviceDiskWriteSectTotal: '$deviceDiskWriteSectTotal'"
:log debug message="HealthMon: deviceCPULoad: '$deviceCPULoad'"

:set postRequestPayloadParts {
	"deviceMemFree"="$deviceMemFree";
	"deviceMemTotal"="$deviceMemTotal";
	"deviceDiskFree"="$deviceDiskFree";
	"deviceDiskTotal"="$deviceDiskTotal";
	"deviceDiskBadBlocks"="$deviceDiskBadBlocks";
	"deviceDiskWriteSectSinceReboot"="$deviceDiskWriteSectSinceReboot";
	"deviceDiskWriteSectTotal"="$deviceDiskWriteSectTotal";
	"deviceCPULoad"="$deviceCPULoad";
}

:foreach postRequestPayloadPartName,postRequestPayloadPart in=$postRequestPayloadParts do={

	:if ( [:len ($postRequestPayloadParts->"$postRequestPayloadPartName") ] > 0 ) do={
		:set currentPostRequestPayloadPart ("monitoring,instance=$deviceIdentity" . " " . $postRequestPayloadPartName . "=" . $postRequestPayloadParts->"$postRequestPayloadPartName")
		:set postRequestPayload ( "$currentPostRequestPayloadPart" . "\n" . "$postRequestPayload" )
	
	} else={
		:log warning message="$postRequestPayloadPartName is empty. Omitting."
	};
}

/tool fetch url="$influxDBURL" http-header-field="Authorization: TOKEN YOUR-TOKEN,Content-Type: text/plain; charset=utf-8,Content-Type: text/plain; charset=utf-8" keep-result=no http-method=post http-data="$postRequestPayload"

