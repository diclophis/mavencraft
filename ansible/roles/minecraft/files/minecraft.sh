#!/bin/sh

#set -e
#set -x

pgrep "ruby"
OK_TO_RUN_WHEN_ONE=$?

if [ $OK_TO_RUN_WHEN_ONE = 0 ];
then
  tail -n 6 /var/log/syslog
  sleep 1
  exit 1
fi;

RAM=1500M
MINECRAFT_ROOT=/opt/minecraft
MAVENCRAFT_WRAPPER=/home/mavencraft/mavencraft/minecraft-wrapper/server2.rb
MAVENCRAFT_BLOCKER=/home/mavencraft/mavencraft/minecraft-wrapper/blocker.rb

mkdir -p $MINECRAFT_ROOT
cd $MINECRAFT_ROOT

pkill -9 -f java || true

rm -Rf /opt/minecraft/world*
rm -f /tmp/dynasty.sock

ruby $MAVENCRAFT_WRAPPER ruby $MAVENCRAFT_BLOCKER java -d64 -XX:UseSSE=2 -Xmx$RAM -Xms$RAM -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:+CMSIncrementalPacing -XX:ParallelGCThreads=2 -XX:+AggressiveOpts -server -jar $MINECRAFT_ROOT/minecraft.jar nogui &

while [ true ];
do
  echo 'authentic\nsave-all'
  echo 'authentic\nsave-all' | nc -w 5 localhost 25566 | grep 'Save complete'
  SAVED=$?
  if [ $SAVED = 0 ];
  then
    break
  fi
  sleep 5
done

sudo -u mavencraft sh /home/mavencraft/mavencraft/scripts/overviewer.sh | logger &

nc -l 0.0.0.0 20021

pkill -9 -f overviewer || true
pkill -9 -f java || true
pkill -9 -f ruby || true
