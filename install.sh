#!/bin/bash

# Функция для проверки установки Docker
check_docker_installed() {
    if command -v docker &> /dev/null; then
        echo "Docker уже установлен, пропускаем установку"
        return 0
    else
        echo "Docker не установлен, начинаем установку..."
        return 1
    fi
}

# Функция для получения значения переменной из .env файла
get_env_value() {
    local key="$1"
    local value
    value=$(grep -E "^${key}=" .env | cut -d '=' -f2 | tr -d '"' | tr -d "'")
    echo "$value"
}

# Проверяем наличие Docker и устанавливаем при необходимости
if ! check_docker_installed; then
    echo "Устанавливаем Docker..."
    curl -fsSL https://get.docker.com/ | sh
    
    # Проверяем успешность установки
    if ! command -v docker &> /dev/null; then
        echo "Ошибка: не удалось установить Docker"
        exit 1
    fi
fi

# Проверяем наличие файла .env
if [ ! -f .env ]; then
    echo "Файл .env не найден"
    exit 1
fi

# Получаем значение SELFSNI из .env файла
SELFSNI=$(get_env_value "SELFSNI")

# Запускаем docker-compose-certs.yml только если SELFSNI=true
if [ "$SELFSNI" = "true" ]; then
    echo "SELFSNI=true, запускаем контейнеры для сертификатов..."
    
    # Проверяем наличие файла docker-compose-certs.yml
    if [ -f docker-compose-certs.yml ]; then
        sudo docker compose -f docker-compose-certs.yml up -d
    else
        echo "Файл docker-compose-certs.yml не найден"
    fi
else
    echo "SELFSNI=false, пропускаем запуск сертификатов"
fi

# Запускаем основной docker-compose
echo "Запускаем основной docker-compose..."
sudo docker compose up --build -d
echo "УСТАНОВКА ЗАВЕРШЕНА! СКОПИРУЙТЕ КЛЮЧИ:"
echo "INSTALLATION IS COMPLETE. DON'T FORGET TO COPY KEYS YOUR KEYS:"
cat connection/connstring.txt
