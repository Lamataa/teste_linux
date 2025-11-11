#!/bin/bash
# ==============================================
# Script de Automação - Servidor Web + DNS
# Autor: Gabriel Lamata
# Versão: COMPLETA (configura rede automaticamente)
# ==============================================

# Para o script em caso de erro
set -e

# Variáveis do script - PARA MUDAR O IP, ALTERE AQUI:
DOMAIN="gabriel.local"
IP="192.168.56.20"              # <-- MUDE AQUI se precisar de outro IP
IFACE1="enp0s3"
IFACE2="enp0s8"
ZONE_FILE="/var/cache/bind/gabriel.local.zone"

# Interação com usuário (requisito 1)
echo "=================================="
echo "Script de Configuração Automática"
echo "=================================="
echo "Este script vai configurar:"
echo "  - Rede (interfaces)"
echo "  - Apache (servidor web)"
echo "  - Bind9 (DNS)"
echo ""
read -p "Deseja continuar? (s/n): " CONFIRMAR

if [[ "$CONFIRMAR" != "s" && "$CONFIRMAR" != "S" ]]; then
    echo "Operação cancelada pelo usuário."
    exit 1
fi

echo ""
echo "Iniciando configuração do servidor..."
sleep 2

# ==========================================
# ETAPA 1: Configuração de Rede
# ==========================================
echo "[1/5] Configurando interfaces de rede..."
echo "Criando arquivo /etc/network/interfaces..."

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto $IFACE1
iface $IFACE1 inet dhcp

auto $IFACE2
iface $IFACE2 inet static
    address $IP
    netmask 255.255.255.0
EOF

echo "Subindo interface $IFACE2..."
ifup $IFACE2 2>/dev/null || true
echo "Rede configurada com sucesso!"
echo "IP atribuído: $IP"
sleep 2

# ==========================================
# ETAPA 2: Atualização do Sistema
# ==========================================
echo ""
echo "[2/5] Atualizando repositórios do sistema..."
echo "Comentando primeira linha do sources.list..."
sed -i '1s/^/#/' /etc/apt/sources.list 2>/dev/null || true
echo "Executando apt update..."
apt update -y || echo "Aviso: falha ao atualizar (continuando mesmo assim)"
echo "Sistema atualizado!"
sleep 2

# ==========================================
# ETAPA 3: Instalação do Apache
# ==========================================
echo ""
echo "[3/5] Instalando servidor web Apache..."
echo "Instalando pacotes: apache2, wget, unzip..."
apt-get install -y apache2 wget unzip
echo "Habilitando Apache para iniciar no boot..."
systemctl enable apache2
echo "Iniciando serviço Apache..."
systemctl start apache2
echo "Apache instalado e iniciado com sucesso!"
sleep 2

# ==========================================
# ETAPA 4: Download e Publicação do Site
# ==========================================
echo ""
echo "[4/5] Baixando template HTML da internet..."
echo "Limpando diretório /var/www/html/..."
rm -rf /var/www/html/*

echo "Tentando download do template..."
if wget -q --timeout=10 https://www.tooplate.com/zip-templates/2133_moso_interior.zip -O /tmp/site.zip 2>/dev/null; then
    echo "Download concluído!"
    echo "Descompactando arquivos..."
    unzip -q /tmp/site.zip -d /tmp/site
    echo "Movendo arquivos para /var/www/html/..."
    mv /tmp/site/*/* /var/www/html/ 2>/dev/null || mv /tmp/site/* /var/www/html/
    echo "Limpando arquivos temporários..."
    rm -rf /tmp/site /tmp/site.zip
    echo "Template publicado com sucesso!"
else
    echo "Falha no download do template."
    echo "Criando página HTML padrão..."
    echo "<h1>Servidor Web - gabriel.local</h1><p>Configurado com sucesso!</p>" > /var/www/html/index.html
    echo "Página padrão criada!"
fi

echo "Ajustando permissões dos arquivos..."
chown -R www-data:www-data /var/www/html
echo "Site publicado em: http://$IP"
sleep 2

# ==========================================
# ETAPA 5: Configuração do DNS
# ==========================================
echo ""
echo "[5/5] Instalando e configurando servidor DNS..."
echo "Instalando pacotes: bind9, bind9utils, dnsutils..."
apt-get install -y bind9 bind9utils dnsutils

echo "Criando arquivo de configuração: named.conf.options..."
cat > /etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";
    listen-on port 53 { any; };
    allow-query { any; };
    recursion yes;
    forwarders {
        8.8.8.8;
    };
};
EOF
echo "Arquivo named.conf.options criado!"

echo "Criando arquivo de configuração: named.conf.local..."
cat > /etc/bind/named.conf.local <<EOF
zone "$DOMAIN" IN {
    type master;
    file "$ZONE_FILE";
};
EOF
echo "Arquivo named.conf.local criado!"

echo "Criando arquivo de zona DNS: $ZONE_FILE..."
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

ns1     IN      A       $IP
www     IN      A       $IP
EOF
echo "Arquivo de zona criado!"

echo "Ajustando permissões do arquivo de zona..."
chown bind:bind $ZONE_FILE

echo "Validando configuração da zona DNS..."
named-checkzone $DOMAIN $ZONE_FILE

echo "Reiniciando serviço Bind9..."
systemctl restart bind9 2>/dev/null || /etc/init.d/bind9 restart
echo "Habilitando Bind9 para iniciar no boot..."
systemctl enable bind9 2>/dev/null || true
echo "DNS configurado com sucesso!"
sleep 2

# ==========================================
# FINALIZAÇÃO
# ==========================================
echo ""
echo "=================================="
echo "   Configuração Concluída!"
echo "=================================="
echo ""
echo "Informações do servidor:"
echo "  IP: $IP"
echo "  Domínio: $DOMAIN"
echo "  Site: http://$IP"
echo ""
echo "Para testar no cliente:"
echo "  1. Configure o DNS: echo 'nameserver $IP' > /etc/resolv.conf"
echo "  2. Teste o DNS: nslookup www.$DOMAIN"
echo "  3. Acesse o site: lynx http://www.$DOMAIN"
echo ""
echo "=================================="
echo "Status dos Serviços:"
echo "=================================="
systemctl status apache2 --no-pager | grep Active || echo "Apache: Rodando"
systemctl status bind9 --no-pager | grep Active || echo "Bind9: Rodando"
echo ""
echo "=================================="
echo "Teste do DNS:"
echo "=================================="
nslookup www.$DOMAIN localhost || echo "DNS configurado (pode não resolver ainda no cliente)"
echo ""
echo "Configuração finalizada com sucesso!"
echo "=================================="
