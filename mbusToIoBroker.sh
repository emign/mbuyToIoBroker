#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/pi/mbusToIoBroker
#
# Simple script to read M-Bus meter values from a connected
# smart meter and send the value to an MQTT broker
#
# usage: mbus_mqtt.sh PRIMARY_ADDRESS
#
# The orimary address needs to be given on the command line.
# For unconfigured meters this is typically "0"
#
# Update tour crontab to run this command reagularly, e.g.
# */15 * * * * /usr/local/bin/mbus_mqtt.sh 1  to read meter 1 every 15min
#
# Author: Hoich
#
# Credits: http://stackoverflow.com/a/24088031 for XML parsing

if [ "$#" -ne 1 ] ; then
  echo "usage: $0 PRIMARY_ADDRESS" >&2
  exit 1
fi

PRIMARY_ADDRESS=$1
TMPFILE=mbus_pa${PRIMARY_ADDRESS}.xml

# Read data from M-Bus
mbus-serial-request-data -b 2400 /dev/ttyUSB0 $PRIMARY_ADDRESS > ${TMPFILE}

# Parse
Id=($(grep -oP '(?<=Id>)[^<]+' ${TMPFILE}))
Manufacturer=($(grep -oP '(?<=Manufacturer>)[^<]+' ${TMPFILE}))
Medium=($(grep -oP '(?<=Medium>)[^<]+' ${TMPFILE}))
Values=($(grep -oP '(?<=Value>)[^<]+' ${TMPFILE} ))
sleep 2
oIFS=$IFS; IFS=$'\n'
#Units=($(grep -oP '(?<=Unit>)[^<]+' ${TMPFILE} ))
Units=($(grep -oP '(?<=<Unit>).*?(?=</Unit>)' ${TMPFILE} ))
IFS=$oIFS
unset oIFS

echo "Primary Address: $PRIMARY_ADDRESS"
echo "Id: ${Id}"
echo "Manufacturer: ${Manufacturer}"
echo "Medium: ${Medium}"

# Send to MQTT broker (not needed regularly, actually, but we do it nevertheless)
mosquitto_pub -h 192.168.178.39 -p 1900 -u <<USERNAME>> --pw <<<<PASSWORD>>> -t "mbus/${PRIMARY_ADDRESS}/PrimaryAddress" -m "$PRIMARY_ADDRESS"
mosquitto_pub -h 192.168.178.39 -p 1900 -u <<USERNAME>> --pw <<<<PASSWORD>>> -t "mbus/${PRIMARY_ADDRESS}/Id" -m ${Id}
mosquitto_pub -h 192.168.178.39 -p 1900 -u <<USERNAME>> --pw <<<<PASSWORD>>> -t "mbus/${PRIMARY_ADDRESS}/Manufacturer" -m ${Manufacturer}
mosquitto_pub -h 192.168.178.39 -p 1900 -u <<USERNAME>> --pw <<<<PASSWORD>>> -t "mbus/${PRIMARY_ADDRESS}/Medium" -m ${Medium}

# Do the same for all dynamic values - that's the interesting part for visualization etc.
for i in ${!Values[@]}
do
  echo  "$i" "${Values[$i]}" "${Units[$i]}"
  mosquitto_pub -h 192.168.178.39 -p 1900 -u <<USERNAME>> --pw <<<<PASSWORD>>> -m "${Values[$i]}" -t "mbus/${PRIMARY_ADDRESS}/${i}/Value"
  echo "${Units[$i]}" | mosquitto_pub -h 192.168.178.39 -p 1900 -u <<USERNAME>> --pw <<<<PASSWORD>>> -t "mbus/${PRIMARY_ADDRESS}/${i}/Unit" -l
done

# EOF
