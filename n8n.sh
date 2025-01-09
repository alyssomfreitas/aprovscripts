#!/bin/bash

# Function to display progress bar
progress_bar() {
    local progress=$1
    local total=100
    local filled=$(( progress * 50 / total ))
    local empty=$(( 50 - filled ))
    printf "\r["
    printf "%0.s#" $(seq 1 $filled)
    printf "%0.s-" $(seq 1 $empty)
    printf "] %d%%" $progress
}

# Function to prompt user to continue
prompt_to_continue() {
    local message=$1
    echo -e "\n$message"
    read -p "Deseja continuar? (s/n): " choice
    case "$choice" in 
        s|S ) echo "Continuando...";;
        n|N ) echo "Instalação cancelada."; exit;;
        * ) echo "Opção inválida."; prompt_to_continue "$message";;
    esac
}

# Start script
echo "Iniciando instalação do n8n com Redis usando Docker em Ubuntu 22.04."

# Update and install Docker
progress_bar 0
prompt_to_continue "Atualizando sistema e instalando Docker."
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose
sudo systemctl enable docker
sudo systemctl start docker
progress_bar 30

# Pull n8n and Redis images
prompt_to_continue "Baixando imagens Docker para n8n e Redis."
sudo docker pull n8nio/n8n
sudo docker pull redis
progress_bar 60

# Prompt for webhook URL
read -p "Digite a URL externa para o webhook do n8n: " webhook_url

# Set up Docker Compose
prompt_to_continue "Configurando Docker Compose."
cat <<EOL > docker-compose.yml
version: '3.7'

services:
  redis:
    image: redis
    restart: always

  n8n:
    image: n8nio/n8n
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=admin
      - N8N_REDIS_HOST=redis
      - N8N_REDIS_PORT=6379
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - WEBHOOK_URL=$webhook_url
    depends_on:
      - redis
    restart: always
EOL
progress_bar 80

# Start services
prompt_to_continue "Iniciando serviços com Docker Compose."
sudo docker-compose up -d
progress_bar 90

# Show service status
echo -e "\nServiços iniciados com sucesso!"
echo "n8n está disponível na porta 5678."
echo "URL configurada para o webhook: $webhook_url"
echo "Redis está rodando na porta 6379."

progress_bar 100

# End script
echo -e "\nInstalação concluída com sucesso!"
