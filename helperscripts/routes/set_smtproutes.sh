#!/bin/bash
#IP Rule Ausnahmen Table 200 über enp1s0 --> 192.168.10.1
echo "Setze Ausnahmen auf Table 200..."
ip route add default via 192.168.10.1 dev enp1s0 table 200
ip rule add fwmark 200 table 200
ip rule add from all lookup main
