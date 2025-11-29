#!/bin/bash

curl -fsSL https://get.docker.com/ | sh

sudo docker compose up --build -d
echo "УСТАНОВКА ЗАВЕРШЕНА! СКОПИРУЙТЕ КЛЮЧИ:"
echo "INSTALLATION IS COMPLETE. DON'T FORGET TO COPY KEYS YOUR KEYS:"
cat connection/connstring.txt