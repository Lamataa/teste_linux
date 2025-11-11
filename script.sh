#!/bin/bash
# ==============================================
# AUTOMAÇÃO DE SERVIDOR WEB + DNS (DEBIAN)
# Autor: Gabriel Lamata
# Data: $(date)
# Descrição: Script automatizado para configurar um servidor WEB (Apache) 
# e DNS (Bind9) com domínio gabriel.local.
# ATENÇÃO: Configure a rede MANUALMENTE antes de executar!
# ==============================================

set -e  # Faz o script parar em caso de erro

# ----------------------------------------------
# VARIÁVEIS PRINCIPAIS
# ----------------------------------------------
DOMAIN="gabriel.local"
IFACE2="enp0s8"
ZONE_FILE="/var/cache/bind/gabriel.local.zone"

# ----------------------------------------------
# INTERAÇÃO COM O USUÁRIO
# ----------------------------------------------
echo "=============================================="
echo "   CONFIGURAÇÃO AUTOMÁTICA DE SERVIDOR WEB + DNS"
echo "=============================================="
echo "Este script configurará automaticamente:"
echo "  - Servidor Apache (HTTP)"
echo "  - Servidor DNS Bind9 (gabriel.local)"
echo ""
echo "ATENÇÃO: A rede deve estar configurada ANTES!"
echo "  - enp0s3: NAT (DHCP)"
echo "  - enp0s8: IP fixo (ex: 192.168.56.20/24)"
echo ""
read -p "Já configurou a rede manualmente? (s/n): " CONFIRMAR

if [[ "$CONFIRMAR" != "s" && "$CONFIRMAR" != "S" ]]; then
    echo "Operação cancelada pelo usuário."
    echo "Configure a rede primeiro e execute novamente."
    exit 1
fi

# ----------------------------------------------
# DETECÇÃO DO IP
# ----------------------------------------------
echo "[REDE] Detectando IP da interface $IFACE2..."
sleep 1

IP=$(ip -4 addr show $IFACE2 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

if [ -z "$IP" ]; then
    echo "[ERRO] Não foi possível detectar o IP da interface $IFACE2!"
    echo "Certifique-se de que a interface está configurada com IP fixo."
    echo ""
    echo "Configure manualmente em /etc/network/interfaces:"
    echo "auto $IFACE2"
    echo "iface $IFACE2 inet static"
    echo "    address 192.168.56.20"
    echo "    netmask 255.255.255.0"
    exit 1
fi

echo "[OK] IP detectado: $IP"
echo "Iniciando configuração..."
sleep 2

# ----------------------------------------------
# VERIFICAÇÃO DE CONECTIVIDADE
# ----------------------------------------------
echo "[REDE] Verificando conectividade com a internet..."
sleep 1

if ! ping -c 2 8.8.8.8 &> /dev/null; then
    echo "[AVISO] Sem conectividade com a internet."
    echo "Tentando configurar rota padrão via enp0s3..."
    ip route add default via 10.0.2.2 dev enp0s3 2>/dev/null || true
    sleep 1
fi

if ping -c 2 8.8.8.8 &> /dev/null; then
    echo "[OK] Conectividade confirmada!"
else
    echo "[AVISO] Sem internet. Script continuará, mas pode falhar no download do template."
fi
sleep 1

# ----------------------------------------------
# ATUALIZAÇÃO DO SISTEMA
# ----------------------------------------------
echo "[SISTEMA] Atualizando pacotes..."
sleep 1

# Comenta a primeira linha do sources.list se necessário
sed -i '1s/^/#/' /etc/apt/sources.list 2>/dev/null || true
apt update -y || {
    echo "[AVISO] Falha ao atualizar pacotes. Continuando mesmo assim..."
}
echo "[OK] Sistema atualizado!"
sleep 1

# ----------------------------------------------
# INSTALAÇÃO DO SERVIDOR APACHE
# ----------------------------------------------
echo "[WEB] Instalando e configurando o Apache..."
sleep 1

apt-get install -y apache2 wget unzip
systemctl enable apache2
systemctl start apache2

# Baixa e publica um template HTML da Internet
rm -rf /var/www/html/*
echo "[WEB] Baixando template da internet..."
wget -q https://www.tooplate.com/zip-templates/2129_crispy_kitchen.zip -O /tmp/site.zip || {
    echo "[AVISO] Falha ao baixar template, usando página padrão..."
    echo "<h1>Servidor Web Apache - Gabriel.local</h1><p>Servidor configurado com sucesso!</p>" > /var/www/html/index.html
}

if [ -f /tmp/site.zip ]; then
    unzip -q /tmp/site.zip -d /tmp/site
    mv /tmp/site/*/* /var/www/html/ 2>/dev/null || mv /tmp/site/* /var/www/html/
    rm -rf /tmp/site /tmp/site.zip
fi

chown -R www-data:www-data /var/www/html

echo "[OK] Site publicado em http://$IP"
sleep 1

# ----------------------------------------------
# INSTALAÇÃO E CONFIGURAÇÃO DO DNS (BIND9)
# ----------------------------------------------
echo "[DNS] Instalando e configurando o Bind9..."
sleep 1

apt-get install -y bind9 bind9utils bind9-doc dnsutils

# Arquivo /etc/bind/named.conf.options
cat > /etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";
    listen-on port 53 { any; };
    listen-on-v6 { any; };
    allow-query { any; };
    recursion yes;
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
};
EOF

# Arquivo /etc/bind/named.conf.local
cat > /etc/bind/named.conf.local <<EOF
zone "$DOMAIN" IN {
    type master;
    file "$ZONE_FILE";
    allow-transfer { any; };
};
EOF

# Criação do arquivo de zona
cat > $ZONE_FILE <<EOF
\$TTL 300
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
        2024022201
        7200
        3600
        86400
        300
)
@       IN      NS      ns1.$DOMAIN.
@       IN      NS      ns2.$DOMAIN.

ns1     IN      A       $IP
ns2     IN      A       $IP
www     IN      A       $IP
mail    IN      A       $IP

@       IN      MX 10   mail.$DOMAIN.
EOF

chown bind:bind $ZONE_FILE

# Verifica a zona antes de reiniciar
named-checkzone $DOMAIN $ZONE_FILE

# Reinicia o serviço DNS
systemctl restart bind9
systemctl enable bind9

echo "[OK] DNS configurado para o domínio $DOMAIN"
sleep 1

# ----------------------------------------------
# CONFIGURAÇÃO DO FIREWALL (SE HOUVER)
# ----------------------------------------------
echo "[FIREWALL] Configurando regras..."
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw allow 53/tcp
    ufw allow 53/udp
    echo "[OK] Firewall configurado!"
else
    echo "[INFO] UFW não instalado, pulando configuração de firewall."
fi
sleep 1

# ----------------------------------------------
# FINALIZAÇÃO
# ----------------------------------------------
echo ""
echo "=============================================="
echo " ✅ CONFIGURAÇÃO CONCLUÍDA COM SUCESSO!"
echo "=============================================="
echo "Informações do Servidor:"
echo "  - IP: $IP"
echo "  - Domínio: $DOMAIN"
echo "  - Site: http://$IP ou http://www.$DOMAIN"
echo ""
echo "Para testar do cliente, configure:"
echo "  1. IP estático na rede 192.168.56.0/24"
echo "  2. DNS: $IP"
echo ""
echo "Ou adicione no /etc/hosts do cliente:"
echo "   $IP www.$DOMAIN $DOMAIN"
echo ""
echo "Serviços ativos:"
systemctl status apache2 --no-pager | grep Active
systemctl status bind9 --no-pager | grep Active
echo ""
echo "Testando DNS local:"
nslookup www.$DOMAIN localhost
echo "=============================================="
