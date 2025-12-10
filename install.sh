#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода ошибки и завершения
error_exit() {
    echo -e "${RED}ОШИБКА: $1${NC}"
    echo -e "${RED}ERROR: $2${NC}"
    exit 1
}

# Функция для вывода предупреждения
warning() {
    echo -e "${YELLOW}ВНИМАНИЕ: $1${NC}"
    echo -e "${YELLOW}WARNING: $2${NC}"
}

# Функция для вывода успеха
success() {
    echo -e "${GREEN}✓ $1${NC}"
    echo -e "${GREEN}✓ $2${NC}"
}

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
    value=$(grep -E "^${key}=" .env | cut -d '=' -f2 | tr -d '"' | tr -d "'" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    echo "$value"
}

# Функция для проверки, указывает ли домен на IP сервера
check_domain_points_to_server() {
    local domain=$1
    local server_ip=$2
    
    # Получаем IP домена
    local domain_ip
    domain_ip=$(dig +short "$domain" | head -n 1)
    
    if [ -z "$domain_ip" ]; then
        error_exit "Не удалось получить IP для домена $domain" "Could not get IP for domain $domain"
    fi
    
    if [ "$domain_ip" = "$server_ip" ]; then
        success "Домен $domain указывает на IP сервера ($server_ip)" "Domain $domain points to server IP ($server_ip)"
        return 0
    else
        error_exit "Домен $domain указывает на $domain_ip, а не на IP сервера ($server_ip)" "Domain $domain points to $domain_ip, not to server IP ($server_ip)"
    fi
}

# Функция для проверки валидности email
validate_email() {
    local email=$1
    
    # Проверяем, что email не пустой
    if [ -z "$email" ]; then
        error_exit "Email не указан!" "Email is not specified!"
    fi
    
    # Простая проверка email формата
    if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        success "Email $email валиден" "Email $email is valid"
        return 0
    else
        error_exit "Неверный формат email: $email" "Invalid email format: $email"
    fi
}

# Функция для проверки наличия необходимых команд
check_required_commands() {
    local commands=("dig" "curl")
    
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error_exit "Команда $cmd не установлена. Установите её: sudo apt-get install dnsutils curl" "Command $cmd is not installed. Install it: sudo apt-get install dnsutils curl"
        fi
    done
}

# Проверяем наличие необходимых команд
check_required_commands

# Проверяем наличие Docker и устанавливаем при необходимости
if ! check_docker_installed; then
    echo "Устанавливаем Docker..."
    curl -fsSL https://get.docker.com/ | sh
    
    # Проверяем успешность установки
    if ! command -v docker &> /dev/null; then
        error_exit "Не удалось установить Docker" "Failed to install Docker"
    fi
fi

# Проверяем наличие файла .env
if [ ! -f .env ]; then
    error_exit "Файл .env не найден" ".env file not found"
fi

# Получаем значения из .env файла
SELFSNI=$(get_env_value "SELFSNI")
TRANSPORT=$(get_env_value "TRANSPORT")
DOMAIN=$(get_env_value "DOMAIN")
EMAIL=$(get_env_value "EMAIL")

echo "TRANSPORT = $TRANSPORT"
echo "SELFSNI = $SELFSNI"
echo "DOMAIN = $DOMAIN"
echo "EMAIL = $EMAIL"

# Проверяем, что DOMAIN не пустой
if [ -z "$DOMAIN" ]; then
    error_exit "DOMAIN не указан в .env файле" "DOMAIN is not specified in .env file"
fi

# Проверяем условие: если TRANSPORT=xhttp, то SELFSNI должен быть true
if [ "$TRANSPORT" = "xhttp" ] && [ "$SELFSNI" != "true" ]; then
    error_exit "При TRANSPORT=xhttp параметр SELFSNI должен быть true!" "When TRANSPORT=xhttp, SELFSNI must be true!"
fi

# Если SELFSNI=true, выполняем дополнительные проверки
if [ "$SELFSNI" = "true" ]; then
    echo "Проверяем конфигурацию для SELFSNI=true..."
    
    # 1. Проверяем, что email заполнен и валиден
    validate_email "$EMAIL"
    
    # 2. Проверяем, указывает ли домен на IP сервера
    echo "Проверяем, указывает ли домен $DOMAIN на IP этого сервера..."
    
    # Получаем IP сервера
    SERVER_IP=$(curl -s 2ip.ru)
    if [ -z "$SERVER_IP" ]; then
        warning "Не удалось получить IP сервера. Пробуем альтернативный метод..." "Could not get server IP. Trying alternative method..."
        SERVER_IP=$(curl -s https://api.ipify.org || curl -s https://icanhazip.com || curl -s https://checkip.amazonaws.com)
    fi
    
    if [ -z "$SERVER_IP" ]; then
        error_exit "Не удалось получить IP сервера" "Could not get server IP"
    fi
    
    echo "IP этого сервера: $SERVER_IP"
    
    # Проверяем DNS запись
    check_domain_points_to_server "$DOMAIN" "$SERVER_IP"
    
    success "Все проверки для SELFSNI=true пройдены" "All checks for SELFSNI=true passed"
    
    # Запускаем docker-compose-certs.yml
    echo "Запускаем контейнеры для сертификатов..."
    
    # Проверяем наличие файла docker-compose-certs.yml
    if [ -f docker-compose-certs.yml ]; then
        sudo docker compose -f docker-compose-certs.yml up
    else
        error_exit "Файл docker-compose-certs.yml не найден" "docker-compose-certs.yml file not found"
    fi
else
    echo "SELFSNI=false, пропускаем запуск сертификатов"
fi

# Запускаем основной docker-compose
echo "Запускаем основной docker-compose..."
sudo docker compose up --build -d

success "Установка завершена успешно!" "Installation completed successfully!"
echo ""
echo "СКОПИРУЙТЕ КЛЮЧИ:"
echo "DON'T FORGET TO COPY YOUR KEYS:"
echo "========================================"
cat connection/connstring.txt
echo "========================================"