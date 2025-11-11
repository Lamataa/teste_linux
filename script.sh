#!/bin/bash
# ==============================================
# Script de Automação - Servidor Web + DNS
# Autor: Gabriel Lamata
# ==============================================

# Para o script em caso de erro
set -e

# Variáveis
DOMAIN="gabriel.local"
IFACE2="enp0s8"
ZONE_FILE="/var/cache/bind/gabriel.local.zone"

# Interação com usuário
echo "=================================="
echo "Script de Configuração Automática"
echo "=================================="
echo "Este script vai configurar:"
echo "  - Apache (servidor web)"
echo "  - Bind9 (DNS)"
echo ""
read -p "Deseja continuar? (s/n): " CONFIRMAR

if [[ "$CONFIRMAR" != "s" && "$CONFIRMAR" != "S" ]]; then
    echo "Operação cancelada."
    exit 1
fi

echo "Iniciando..."
sleep 1

# Detecta IP
echo "Detectando IP..."
IP=$(ip -4 addr show $IFACE2 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

if [ -z "$IP" ]; then
    echo "ERRO: Interface $IFACE2 não configurada!"
    echo "Configure a rede primeiro."
    exit 1
fi

echo "IP encontrado: $IP"
sleep 1

# Atualiza sistema
echo "Atualizando sistema..."
sed -i '1s/^/#/' /etc/apt/sources.list 2>/dev/null || true
apt update -y || echo "Aviso: falha ao atualizar"
sleep 1

# Instala Apache
echo "Instalando Apache..."
apt-get install -y apache2 wget unzip
systemctl enable apache2
systemctl start apache2
echo "Apache instalado!"
sleep 1

# Baixa template
echo "Baixando template HTML..."
rm -rf /var/www/html/*

if wget -q --timeout=10 https://www.tooplate.com/zip-templates/2133_moso_interior.zip -O /tmp/site.zip 2>/dev/null; then
    echo "Template baixado!"
    unzip -q /tmp/site.zip -d /tmp/site
    mv /tmp/site/*/* /var/www/html/ 2>/dev/null || mv /tmp/site/* /var/www/html/
    rm -rf /tmp/site /tmp/site.zip
else
    echo "Falha no download, criando página simples..."
    echo "<h1>Servidor Web - gabriel.local</h1><p>Configurado com sucesso!</p>" > /var/www/html/index.html
fi

chown -R www-data:www-data /var/www/html
echo "Site publicado em http://$IP"
sleep 1

# Instala e configura DNS
echo "Instalando Bind9..."
apt-get install -y bind9 bind9utils dnsutils

echo "Configurando DNS..."

# Arquivo de opções
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

# Arquivo de zona local
cat > /etc/bind/named.conf.local <<EOF
zone "$DOMAIN" IN {
    type master;
    file "$ZONE_FILE";
};
EOF

# Cria arquivo de zona
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

chown bind:bind $ZONE_FILE

# Valida e reinicia
named-checkzone $DOMAIN $ZONE_FILE
systemctl restart bind9 2>/dev/null || /etc/init.d/bind9 restart
systemctl enable bind9 2>/dev/null || true

echo "DNS configurado!"
sleep 1

# Resultado final
echo ""
echo "=================================="
echo "Configuração Concluída!"
echo "=================================="
echo "IP: $IP"
echo "Domínio: $DOMAIN"
echo "Site: http://$IP"
echo ""
echo "Para testar no cliente:"
echo "  - Configure DNS para $IP"
echo "  - Acesse: http://www.$DOMAIN"
echo ""
echo "Status dos serviços:"
systemctl status apache2 --no-pager | grep Active
systemctl status bind9 --no-pager | grep Active
echo ""
echo "Teste de DNS:"
nslookup www.$DOMAIN localhost
echo "=================================="
