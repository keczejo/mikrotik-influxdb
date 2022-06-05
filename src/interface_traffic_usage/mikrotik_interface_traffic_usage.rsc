#
# Interface Traffic Usage 
#
# Comment payload example:
# - {traffic:null}
# - {traffic: rx=1300 tx=1700 total=3000}
# - Custom text here {traffic: rx=1300 tx=1700 total=3000}
# - Custom text here {traffic: rx=1300 tx=1700 total=3000} more custom text



:global influxDBURL "http://influx.db.server:8086/api/v2/write?org=ORAGNIZATION&bucket=BUCKET&precision=ns"

:local version DEV
:local currentItemName
:local currentItemComment
:local currentItemCommentBeforeData
:local currentItemCommentAfterData
:local currentItemCommentBytes
:local currentItemNewComment
:local currentItemCommentRx
:local currentItemCommentTx
:local currentItemCommentTotal

:local currentItemNowRx
:local currentItemNowTx
:local currentItemNowTotal

:local currentItemDiffRx
:local currentItemDiffTx
:local currentItemDiffTotal

:local posDataBegin
:local posDataEnd
:local posDataDelimiter
:local posRxDelimiter
:local posTxDelimiter
:local posTotalDelimiter
:local posCommentEnd

:local dataPartRx
:local dataPartTx
:local dataPartTotal
:local dataContent

:local postRequestPayload

:local scriptRunDatetime
:local deviceIdentity

:global removeSpaces do={

	:local inputLine $1

	:local posEnd
	:local posCurrentDelimiter
	:local partBeforeDelimiter
	:local partAfterDelimiter

	:local i 0
	:while (  [:tonum [:find "$inputLine" "\_"] ] > 0 and $i < 6 ) do={
		:set posEnd [:len $inputLine ]
		:set posCurrentDelimiter [:find $inputLine "\_"]
		:set partBeforeDelimiter [:pick $inputLine 0 $posCurrentDelimiter]
		:set partAfterDelimiter [:pick $inputLine ($posCurrentDelimiter + 1) $posEnd ]

		:set inputLine  ("$partBeforeDelimiter" . "$partAfterDelimiter") 
		:set i ($i + 1)

	}

	:return [:tonum $inputLine]

}

:set scriptRunDatetime ( [:tostr [/system clock get date]] . " " . [:tostr [/system clock get time]] )
:set deviceIdentity ( [/system identity get name] )

:if ([:tostr [:typeof $influxDBURL ]] = "nothing" ) do={
	:error "Error: can't read out variable \$influxDBURL. InfluxDB URL not set, exiting."
}

:foreach itemID in=[/interface find comment~"\\{traffic:.*\\}"] do={
	:log info message="ITU: processing item $itemID"

	:set currentItemComment [ /interface get $itemID comment ]
	:set currentItemName [ /interface get $itemID name ]
	:log info message="ITU: Item: $itemID, Name: '$currentItemName', Comment: '$currentItemComment'"

	:if ([:find $currentItemComment ":"] != "") do={
		:log info message="ITU: Item: $itemID Delimiter found, hope syntax is correct"

		:set posDataBegin [ :find $currentItemComment "{" ]
		:set posDataEnd [ :find $currentItemComment "}" ]
		:set posDataDelimiter [ :find $currentItemComment ":" ]
		:set posRxDelimiter [ :find $currentItemComment ":rx=" ]
		:set posTxDelimiter [ :find $currentItemComment " tx=" ]
		:set posTotalDelimiter [ :find $currentItemComment " total=" ]
		:set posCommentEnd [ :len $currentItemComment ]

		:log info message="ITU: Item: $itemID, posRxDelimiter=$posRxDelimiter posTxDelimiter=$posTxDelimiter posTotalDelimiter=$posTotalDelimiter"

		:set currentItemCommentBytes [ :pick $currentItemComment ($posDataDelimiter + 1) ($posDataEnd) ]
		:set currentItemCommentBeforeData [ :pick $currentItemComment 0 $posDataBegin ]
		:set currentItemCommentRx [ :pick $currentItemComment ($posRxDelimiter + 4) $posTxDelimiter ]
		:set currentItemCommentTx [ :pick $currentItemComment ($posTxDelimiter + 4) $posTotalDelimiter ]
		:set currentItemCommentTotal [ :pick $currentItemComment ($posTotalDelimiter + 7) $posDataEnd ]
		:set currentItemCommentAfterData [ :pick $currentItemComment ($posDataEnd + 1) $posCommentEnd ]
		
		:log info message="ITU: Item: $itemID, Restored Rx: '$currentItemCommentRx'"
		:log info message="ITU: Item: $itemID, Restored Tx: '$currentItemCommentTx'"
		:log info message="ITU: Item: $itemID, Restored Total: '$currentItemCommentTotal'"
		:log info message="ITU: Item: $itemID, Comment before data: '$currentItemCommentBeforeData'"
		:log info message="ITU: Item: $itemID, Comment after data: '$currentItemCommentAfterData'"

		:log info message="ITU: Item: $itemID, Getting current counters"
		:set currentItemNowRx [ $removeSpaces [:tostr [ /interface get number=$itemID rx-byte ] ] ]
		:set currentItemNowTx [ $removeSpaces [:tostr [ /interface get number=$itemID tx-byte ] ] ]
		:set currentItemNowTotal ( $currentItemNowRx + $currentItemNowTx ) 

		:log info message="ITU: Item: $itemID, Current counters: rx=$currentItemNowRx tx=$currentItemNowTx total=$currentItemNowTotal"

		:set dataPartRx "rx=$currentItemNowRx"
		:set dataPartTx "tx=$currentItemNowTx"
		:set dataPartTotal "total=$currentItemNowTotal"
		:set dataContent "{traffic:$dataPartRx $dataPartTx $dataPartTotal}"

		:set currentItemNewComment ( $currentItemCommentBeforeData . $dataContent . $currentItemCommentAfterData )
		/interface set numbers=$itemID comment="$currentItemNewComment"

		:if ( $currentItemCommentBytes = "null" ) do={
			:log info message="ITU: Item: $itemID A first start. Wrote current data instead of 'null'."

		} else={

			:if ( $currentItemCommentRx < $currentItemNowRx ) do={
				:log info message="ITU: Item: $itemID, Looks like counters got reset."
			}

			:set currentItemDiffRx ( $currentItemNowRx - $currentItemCommentRx )
			:set currentItemDiffTx ( $currentItemNowTx - $currentItemCommentTx )
			:set currentItemDiffTotal ( $currentItemNowTotal - $currentItemCommentTotal )

			:log info message="ITU: Item: $itemID, Current counters: diff-rx=$currentItemDiffRx diff-tx=$currentItemDiffTx diff-total=$currentItemDiffTotal"

			:log info message="ITU: Item: $itemID Updated data and now sending a notification."
			
			:set postRequestPayload ( "monitoring,interface=$currentItemName,instance=$deviceIdentity traffic_rx=$currentItemNowRx" . "\n" .  "monitoring,interface=$currentItemName,instance=$deviceIdentity traffic_tx=$currentItemNowTx" )
			/tool fetch url="$influxDBURL" http-header-field="Authorization: TOKEN YOUR-TOKEN,Content-Type: text/plain; charset=utf-8,Content-Type: text/plain; charset=utf-8" keep-result=no http-method=post http-data="$postRequestPayload"
		}

	}

}

