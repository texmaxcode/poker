#!/bin/bash

URL="https://tekeye.uk/playing_cards/images/svg_playing_cards/"
SUITE_ENUM=("clubs" "spades" "hearts" "diamonds")
RANK_ENUM=("2" "3" "4" "5" "6" "7" "8" "9" "10" "jack" "queen" "king" "ace")

for suite in "${SUITE_ENUM[@]}"; do
  for rank in "${RANK_ENUM[@]}"; do
    wget $URL"fronts/"$suite"_"$rank".svg";
  done
done

#Get backs
wget $URL"backs/red2.svg"
wget $URL"backs/blue2.svg"
