#!/bin/sh

set -x

RAM=$1
WORLD=$2
MINECRAFT_PORT=$3
export MAVENCRAFT_WRAPPER_PORT=$4
JAR=$5
MINECRAFT_ROOT=/home/minecraft

mkdir -p $MINECRAFT_ROOT/tmp

export DYNASTY_SOCK=$MINECRAFT_ROOT/tmp/$WORLD-dynasty.sock
MAVENCRAFT_WRAPPER=$MINECRAFT_ROOT/minecraft-wrapper/server2.rb

cd $MINECRAFT_ROOT

LOG_CONF=-Dlog4j.configurationFile=log4j2.xml
LOG_CONF=

java --version

#JVM_ARGS="-mx${RAM} -Xmx${RAM} -Xms${RAM} -XX:MaxGCPauseMillis=5 --illegal-access=warn"
#JVM_ARGS="-mx${RAM} -Xmx${RAM} -Xms${RAM} -XX:MaxGCPauseMillis=5 --illegal-access=warn"
#JVM_ARGS="-mx${RAM} -Xmx${RAM} -Xms${RAM} -XX:MaxGCPauseMillis=1 -XX:+UseG1GC -XX:ParallelGCThreads=32 -XX:ConcGCThreads=32 -XX:InitiatingHeapOccupancyPercent=0"
JVM_ARGS="-mx${RAM} -Xmx${RAM} -Xms${RAM} -XX:MaxGCPauseMillis=1 -XX:+UseG1GC -XX:ParallelGCThreads=256 -XX:ConcGCThreads=256 -XX:InitiatingHeapOccupancyPercent=0 -XX:+AggressiveOpts"

#-XX:InitiatingHeapOccupancyPercent=10 -XX:AllocatePrefetchStyle=1 -XX:+UseSuperWord -XX:+OptimizeFill -XX:LoopUnrollMin=4 -XX:LoopMaxUnroll=16 -XX:+UseLoopPredicate -XX:+RangeCheckElimination -XX:+CMSCleanOnEnter -XX:+EliminateLocks -XX:+DoEscapeAnalysis -XX:+TieredCompilation -XX:+UseCodeCacheFlushing -XX:+CMSScavengeBeforeRemark -XX:+ScavengeBeforeFullGC -XX:+AlwaysPreTouch -XX:+UnlockExperimentalVMOptions -XX:G1HeapWastePercent=10 -XX:G1MaxNewSizePercent=10 -XX:G1HeapRegionSize=32M -XX:G1NewSizePercent=10 -XX:MaxGCPauseMillis=100 -XX:+OptimizeStringConcat -XX:+UseNUMA -XX:+UseCompressedOops -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -XX:SurvivorRatio=2 -XX:+DisableExplicitGC"

ruby $MAVENCRAFT_WRAPPER java ${LOG_CONF} ${JVM_ARGS} -server -jar $JAR --port $MINECRAFT_PORT nogui
