#!/bin/bash

BDAY=${BDAY:-"17Jul"}
PERSON=${PERSON:-"Slackware"}

function happy_birthday ()
{
  echo "Time to get the cake!"
  echo -e "Let's light the candles!\n"
  echo -e "Time to sing..."
  i=0
  output=''

  for i in $(seq 1 4); do
    output=$output"\nHappy Birthday"

    if [ $i -eq 3 ]; then
      output=$output" dear $PERSON"
    else
      output=$output" to you"
    fi

  done

  echo -e $output"!\n"

  echo -e "Let's open gifts!\n"
}

if [ $(date +%d%b) == "$BDAY" ]; then
  happy_birthday
  echo "Happy Birthday $PERSON!"
else
  y=$(date --date $BDAY +%j)
  x=$(date +%j)
  ((z=x-y))

  if [ $z -lt 0 ]; then
    ((z+=+365))
  fi

  DAYZ="days"
  if [ $z -eq 1 ]; then
    DAYZ="day"
  fi

  echo "$z $DAYZ until $PERSON's next birthday!"
fi
