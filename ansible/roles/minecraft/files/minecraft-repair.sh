#!/bin/sh

echo minecraft-repair

echo "mode?"
read line

if [ "$line" = "destroy" ];
then
  echo destroying

  rm -Rf /home/mavencraft/mavencraft-world
  rm -Rf /usr/share/nginx/html/normal
  rm -Rf /usr/share/nginx/html/scenes

  line="kill"
fi;

if [ "$line" = "kill" ];
then
  echo killing

  echo -e 'authentic\nsave-on\nsave-all' | nc -w 1 localhost 25566 2>&1 > /dev/null
  echo -e 'authentic\nsave-on\nsave-all' | nc -w 1 localhost 25567 2>&1 > /dev/null
  echo -e 'authentic\nsave-on\nsave-all' | nc -w 1 localhost 25566 2>&1 > /dev/null
  echo -e 'authentic\nsave-on\nsave-all' | nc -w 1 localhost 25567 2>&1 > /dev/null

  pkill -9 -f overviewer || true
  #pkill -9 -f java || true
  #pkill -9 -f java || true
  #pkill -9 -f ruby || true
  pkill -9 -f 'java(.*)mavencraft-' || true
  pkill -9 -f 'server2(.*)mavencraft-' || true

  rm -Rf /home/mavencraft/running-mavencraft
  rm -Rf /home/mavencraft/running-overviewer
fi;

sleep 1
