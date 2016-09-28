#!/bin/sh
export URHO3D=/home/slapin/Urho3D
export PROJECT=/home/slapin/dungeon/urho3d
if [ $# -eq 0 ]; then OPT1="-w -s"; fi
$URHO3D/bin/Urho3DPlayer Scripts/my_VehicleDemo.as -pp "$PROJECT/bin" -p "CoreData;Data" $OPT1 $@ 


