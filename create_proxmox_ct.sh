#!/bin/bash

# Função para validar entrada de IP
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Verificar se o comando pct está disponível
if ! command -v pct &> /dev/null; then
    echo "Erro: O comando 'pct' não foi encontrado. Certifique-se de que o Proxmox está instalado corretamente."
    exit 1
fi

# Solicitar informações ao usuário
read -p "Digite o hostname do container: " HOSTNAME
read -s -p "Digite a senha do container: " PASSWORD
echo
read -p "Digite o tamanho do disco (ex: 10G): " DISK_SIZE
read -p "Digite o número de cores da CPU: " CPU_CORES
read -p "Digite a quantidade de memória (ex: 2048 para 2GB): " MEMORY
read -p "Digite o endereço IPv4 estático (ex: 192.168.1.100): " IPV4
while ! validate_ip "$IPV4"; do
    read -p "Endereço IPv4 inválido. Digite novamente: " IPV4
done
read -p "Digite o gateway (ex: 192.168.1.1): " GATEWAY
while ! validate_ip "$GATEWAY"; do
    read -p "Gateway inválido. Digite novamente: " GATEWAY
done
read -p "Digite o servidor DNS (ex: 8.8.8.8): " DNS_SERVER
while ! validate_ip "$DNS_SERVER"; do
    read -p "DNS inválido. Digite novamente: " DNS_SERVER
done

# Definir variáveis fixas
NODE="pve"
TEMPLATE="ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
STORAGE="local"
NETWORK_NAME="eth0"
BRIDGE="vmbr0"
MOUNT_OPTIONS="noatime,discard"
ACLS="1"
UNPRIVILEGED="1"
NESTING="1"
FIREWALL="1"

# Obter o próximo CTID disponível
CTID=$(pvesh get /cluster/nextid)
if [ -z "$CTID" ]; then
    echo "Erro ao obter o próximo CTID."
    exit 1
fi

# Criar o container
echo "Criando o container com CTID $CTID..."
pct create $CTID \
    $STORAGE:$TEMPLATE \
    --hostname $HOSTNAME \
    --password $PASSWORD \
    --unprivileged $UNPRIVILEGED \
    --nesting $NESTING \
    --storage $STORAGE \
    --rootfs $STORAGE:$DISK_SIZE,mountoptions=$MOUNT_OPTIONS,acl=$ACLS \
    --cores $CPU_CORES \
    --memory $MEMORY \
    --net0 name=$NETWORK_NAME,bridge=$BRIDGE,ip=$IPV4/24,gw=$GATEWAY \
    --nameserver $DNS_SERVER \
    --onboot 1 \
    --firewall $FIREWALL

# Verificar se o container foi criado com sucesso
if [ $? -eq 0 ]; then
    echo "Container criado com sucesso!"
    echo "CTID: $CTID"
    echo "Hostname: $HOSTNAME"
    echo "IPv4: $IPV4"
    echo "Gateway: $GATEWAY"
    echo "DNS: $DNS_SERVER"
else
    echo "Erro ao criar o container."
    exit 1
fi

# Iniciar o container
echo "Iniciando o container..."
pct start $CTID

if [ $? -eq 0 ]; then
    echo "Container iniciado com sucesso!"
else
    echo "Erro ao iniciar o container."
    exit 1
fi

echo "Processo concluído!"
