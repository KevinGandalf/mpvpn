#!/bin/bash
#Hier können Ausnahmen konfiguriert werden, ob zum Beispiel IoT Geräte den VPN umgehen.
#Der Dateiname sollte auf das aktuelle Interface eth0 etc. angepasst werden
#IP Rule Ausnahmen Table 100 über enp1s0 --> 192.168.10.1
echo "Setze Ausnahmen auf Table 100..."
ip rule add fwmark 100 table 100
#ip route add default via 192.168.10.1 dev enp1s0 table 100
ip rule add from 192.168.1.167 table 100
#ip rule add from 192.168.10.167 prohibit
ip rule add from 192.168.1.164 table 100
#ip rule add from 192.168.10.164 prohibit
ip rule add from 192.168.1.61 table 100
#ip rule add from 192.168.10.61 prohibit
ip rule add from 192.168.1.51 table 100
ip route add default via 192.168.1.1 dev enp1s0 table enp1s0only
