# MikroTik scripts

## Mikrotik Interface Traffic Usage

Counts rx, tx and total transferred bytes on network interfaces. Stores results in interface's comment and pushes them to InfluxDB.

### Installation

#### Initialise interface comment metadata

You can use WebFig, Winbox or other way to modify the comment. We use CLI:

```bash
/interface ethernet set ether1 comment="{traffic:null}"
/interface wireless set wlan2 comment="{traffic:null}"
```
#### Import scripts to MikroTik

#### Set InfluxDB URL in one of used scripts

```bash
:global influxDBURL "http://influx.db.server:8086/api/v2/write?org=ORAGNIZATION&bucket=BUCKET&precision=ns"
```

#### Configure system scheduler
#### Frequent updates may increase cpu usage

```bash
/system scheduler add interval=2s name=interface_traffic_usage on-event="/system/script/run script1" policy=read,write,test start-time=startup
```

#### Validate results

Check the scheduler:
```bash 
:put [ /system scheduler get interface_traffic_usage next-run ]
:put [ /system scheduler get interface_traffic_usage run-count ]
```

Check the interface comment:
```bash
:put [/interface ethernet get ether1 comment ]
:put [/interface ethernet get wlan2 comment ]
```

## Mikrotik Health Exporter

Installation is similar. Loose these comment modification steps and you're all set.

