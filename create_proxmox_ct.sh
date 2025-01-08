#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Função para limpar instalações mal sucedidas
cleanup_failed_install() {
    local ctid=$1
    echo -e "\n${BLUE}➤ Limpando instalação mal sucedida...${NC}"
    
    # Remove o arquivo de configuração se existir
    if [ -f "/etc/pve/lxc/${ctid}.conf" ]; then
        rm -f "/etc/pve/lxc/${ctid}.conf"
    fi
    
    # Remove o diretório de imagens se existir
    if [ -d "/var/lib/vz/images/${ctid}" ]; then
        rm -rf "/var/lib/vz/images/${ctid}"
    fi
    
    # Remove snapshots se existirem
    if [ -d "/var/lib/vz/snapshots/${ctid}" ]; then
        rm -rf "/var/lib/vz/snapshots/${ctid}"
    fi
    
    show_progress 2 "Limpando arquivos residuais"
    echo -e "${GREEN}Limpeza concluída!${NC}"
}

# Função para exibir barra de progresso
show_progress() {
    local duration=$1
    local text=$2
    local progress=0
    while [ $progress -le 100 ]; do
        echo -ne "\r${text}: [${GREEN}"
        for ((i=0; i<$progress; i+=2)); do echo -ne "#"; done
        for ((i=$progress; i<100; i+=2)); do echo -ne " "; done
        echo -ne "${NC}] ${progress}%"
        sleep $(echo "scale=3; ${duration}/100" | bc)
        ((progress+=2))
    done
    echo
}

# Função para verificar erros
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}Erro: $1${NC}"
        cleanup_failed_install $NEXT_CTID
        exit 1
    fi
}

# Banner de boas-vindas
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════╗"
echo "║     Proxmox Container Creator Script      ║"
echo "╚═══════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar se há instalações mal sucedidas
echo -e "${GREEN}➤ Verificando instalações residuais...${NC}"
for ctid in $(ls /etc/pve/lxc/ 2>/dev/null | grep -oE '^[0-9]+' || true); do
    if [ ! -f "/var/lib/vz/images/${ctid}/vm-${ctid}-disk-0.raw" ] && [ -f "/etc/pve/lxc/${ctid}.conf" ]; then
        echo -e "${RED}Detectada instalação incompleta do CT ${ctid}${NC}"
        read -p "Deseja limpar esta instalação? (s/n): " clean
        if [ "$clean" = "s" ]; then
            cleanup_failed_install $ctid
        fi
    fi
done

# Coletar informações necessárias
echo -e "${GREEN}➤ Por favor, forneça as seguintes informações:${NC}\n"

# Hostname
read -p "Digite o hostname do container: " CT_HOSTNAME

# Password
read -s -p "Digite a senha do container: " CT_PASSWORD
echo

# Recursos
read -p "Digite o tamanho do disco em GB (ex: 20): " DISK_SIZE
read -p "Digite o número de cores CPU (ex: 2): " CPU_CORES
read -p "Digite a quantidade de memória RAM em MB (ex: 2048): " MEMORY

# Rede
read -p "Digite o IP com máscara (ex: 192.168.1.100/24): " IP_ADDRESS
read -p "Digite o gateway: " GATEWAY
read -p "Digite o servidor DNS: " DNS_SERVER

# Encontrar próximo CTID disponível
echo -e "\n${GREEN}➤ Buscando próximo CTID disponível...${NC}"
NEXT_CTID=$(pvesh get /cluster/nextid)
check_error "Falha ao obter próximo CTID"
show_progress 2 "Verificando CTID"

# Verificar se o template existe
echo -e "\n${GREEN}➤ Verificando template Ubuntu 22.04...${NC}"
TEMPLATE="ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
if [ ! -f "/var/lib/vz/template/cache/$TEMPLATE" ]; then
    echo -e "${RED}Template não encontrado. Por favor, faça o download primeiro.${NC}"
    exit 1
fi
show_progress 2 "Verificando template"

# Criar o container
echo -e "\n${GREEN}➤ Criando container...${NC}"

# Redireciona a saída para /dev/null mas mantém os erros visíveis
pct create $NEXT_CTID /var/lib/vz/template/cache/$TEMPLATE \
    --hostname $CT_HOSTNAME \
    --password $CT_PASSWORD \
    --storage local \
    --rootfs local:$DISK_SIZE \
    --unprivileged 1 \
    --features nesting=1 \
    --cores $CPU_CORES \
    --memory $MEMORY \
    --net0 name=eth0,bridge=vmbr0,ip=$IP_ADDRESS,gw=$GATEWAY \
    --nameserver $DNS_SERVER \
    --ostype ubuntu \
    --onboot 1 \
    --protection 0 > /dev/null 2>&1

check_error "Falha ao criar o container"
show_progress 10 "Criando container"

# Iniciar o container
echo -e "\n${GREEN}➤ Iniciando container...${NC}"
sleep 2
pct start $NEXT_CTID > /dev/null 2>&1
check_error "Falha ao iniciar o container"
show_progress 3 "Iniciando container"

# Verificar status do container
echo -e "\n${GREEN}➤ Verificando status do container...${NC}"
STATUS=$(pct status $NEXT_CTID)
check_error "Falha ao verificar status do container"
show_progress 2 "Verificando status"

# Exibir resumo
echo -e "\n${BLUE}═══ Resumo da Criação do Container ═══${NC}"
echo -e "CTID: ${GREEN}$NEXT_CTID${NC}"
echo -e "Hostname: ${GREEN}$CT_HOSTNAME${NC}"
echo -e "IP: ${GREEN}$IP_ADDRESS${NC}"
echo -e "CPU Cores: ${GREEN}$CPU_CORES${NC}"
echo -e "Memória: ${GREEN}$MEMORY MB${NC}"
echo -e "Disco: ${GREEN}$DISK_SIZE GB${NC}"
echo -e "Status: ${GREEN}$STATUS${NC}"

echo -e "\n${GREEN}Container criado com sucesso!${NC}"
