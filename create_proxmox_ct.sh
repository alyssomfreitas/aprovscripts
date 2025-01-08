#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Banner de boas-vindas
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════╗"
echo "║     Proxmox Container Creator Script      ║"
echo "╚═══════════════════════════════════════════╝"
echo -e "${NC}"

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
show_progress 2 "Verificando CTID"

# Verificar se o template existe
echo -e "\n${GREEN}➤ Verificando template Ubuntu 22.04...${NC}"
TEMPLATE="ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
show_progress 2 "Verificando template"

# Criar o container
echo -e "\n${GREEN}➤ Criando container...${NC}"

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
    --mp0 local:0/mp0,mp=/mnt/data \
    --ostype ubuntu \
    --onboot 1 \
    --protection 0 \
    --acl 1 \
    --firewall 1

show_progress 5 "Criando container"

# Iniciar o container
echo -e "\n${GREEN}➤ Iniciando container...${NC}"
pct start $NEXT_CTID
show_progress 3 "Iniciando container"

# Exibir resumo
echo -e "\n${BLUE}═══ Resumo da Criação do Container ═══${NC}"
echo -e "CTID: ${GREEN}$NEXT_CTID${NC}"
echo -e "Hostname: ${GREEN}$CT_HOSTNAME${NC}"
echo -e "IP: ${GREEN}$IP_ADDRESS${NC}"
echo -e "CPU Cores: ${GREEN}$CPU_CORES${NC}"
echo -e "Memória: ${GREEN}$MEMORY MB${NC}"
echo -e "Disco: ${GREEN}$DISK_SIZE GB${NC}"

echo -e "\n${GREEN}Container criado com sucesso!${NC}"
