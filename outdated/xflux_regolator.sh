#!/bin/bash

# muovi il software xflux in /bin per eseguire questo script

user="alfredo"
v=0;
pid=0;
v1=4000;
v2=3400;
latitude=41.6;
longitude=13.4;

word=1;


x=`ps -A -feww | grep xflux`;
x1=$(echo $x | cut -d ' ' -f $word);
while [ "$x1" != "" ] ; do
	if [ "$x1" = "$user" ] ; then
		word=$((word+1));
		x1=$(echo $x | cut -d ' ' -f $word);
		pid=$x1;
	fi

	if [ "$x1" = "-k" ] ; then
		word=$((word+1));
		x1=$(echo $x | cut -d ' ' -f $word);
		v=$x1;
		if [ "$v" = "$v1" ] ; then
			kill -9 $pid;
			xflux -l $latitude -g $longitude -r 1 -k $v2;
			exit 0;
		fi

		if [ "$v" = "$v2" ] ; then
			kill -9 $pid;
			exit 0;
		fi
	fi

	word=$((word+1));
	x1=$(echo $x | cut -d ' ' -f $word);
done

xflux -l $latitude -g $longitude -r 1 -k $v1;
		
exit 0;
