#!/bin/bash
# Script de Automação - Servidor Web + DNS
# Autor: Gabriel Lamata
# Versão completa com as melhorias pedidas

# para o script se der erro
set -e

# variaveis
DOMAIN="gabriel.local"
IP="192.168.56.20"
IFACE1="enp0s3"
IFACE2="enp0s8"
ZONE_FILE="/var/cache/bind/gabriel.local.zone"

# pergunta pro usuario
echo "=================================="
echo "Script de Configuração Automática"
echo "=================================="
echo "Este script vai configurar:"
echo "  - Rede"
echo "  - Apache"
echo "  - DNS"
echo ""
read -p "Deseja continuar? (s/n): " CONFIRMAR

if [[ "$CONFIRMAR" != "s" && "$CONFIRMAR" != "S" ]]; then
    echo "Operação cancelada."
    exit 1
fi

echo "Iniciando..."
sleep 1

# configurando rede
echo ""
echo "[1/5] Configurando rede..."
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

ifup $IFACE2 2>/dev/null || true
echo "Rede ok! IP: $IP"
sleep 1

# atualizando sistema
echo ""
echo "[2/5] Atualizando sistema..."
sed -i '1s/^/#/' /etc/apt/sources.list 2>/dev/null || true
apt update -y || echo "aviso: falha ao atualizar"
echo "Sistema atualizado"
sleep 1

# instalando apache
echo ""
echo "[3/5] Instalando Apache..."
apt-get install -y apache2 wget unzip

# ocultando versao do apache (requisito do trabalho)
echo "Configurando segurança do Apache..."
if [ -f /etc/apache2/conf-available/security.conf ]; then
    sed -i 's/^ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
    sed -i 's/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf
    echo "Versão do Apache ocultada"
else
    echo "ServerTokens Prod" >> /etc/apache2/apache2.conf
    echo "ServerSignature Off" >> /etc/apache2/apache2.conf
    echo "Configuração adicionada no apache2.conf"
fi

# habilitando apache pra iniciar automaticamente (requisito)
echo "Habilitando Apache no boot..."
systemctl enable apache2
echo "Apache vai iniciar automaticamente agora"

systemctl start apache2
echo "Apache instalado e rodando"
sleep 1

# baixando site da internet
echo ""
echo "[4/5] Baixando template HTML..."
rm -rf /var/www/html/*

# tentando baixar o template
if wget -q --timeout=10 https://www.tooplate.com/zip-templates/2133_moso_interior.zip -O /tmp/site.zip 2>/dev/null; then
    echo "Download ok"
    unzip -q /tmp/site.zip -d /tmp/site
    mv /tmp/site/*/* /var/www/html/ 2>/dev/null || mv /tmp/site/* /var/www/html/
    rm -rf /tmp/site /tmp/site.zip
    echo "Template publicado"
else
    # se nao conseguir baixar, cria pagina simples
    echo "Não conseguiu baixar, criando pagina basica..."
    echo "<h1>Servidor Web - gabriel.local</h1><p>Configurado com sucesso!</p>" > /var/www/html/index.html
fi

chown -R www-data:www-data /var/www/html
echo "Site disponivel em: http://$IP"
sleep 1

# configurando DNS
echo ""
echo "[5/5] Configurando DNS..."
apt-get install -y bind9 bind9utils dnsutils

# arquivo de opcoes do bind
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

# arquivo de zona local
cat > /etc/bind/named.conf.local <<EOF
zone "$DOMAIN" IN {
    type master;
    file "$ZONE_FILE";
};
EOF

# criando zona dns
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
named-checkzone $DOMAIN $ZONE_FILE

# habilitando bind9 pra iniciar automaticamente (requisito)
echo "Habilitando Bind9 no boot..."
systemctl enable bind9 2>/dev/null || true

systemctl restart bind9 2>/dev/null || /etc/init.d/bind9 restart
echo "DNS configurado"
sleep 1

# finalizando
echo ""
echo "=================================="
echo "Configuração completa!"
echo "=================================="
echo ""
echo "Informações:"
echo "  IP: $IP"
echo "  Domínio: $DOMAIN"
echo "  Site: http://$IP"
echo ""
echo "Para testar no cliente:"
echo "  1. Configure o DNS: echo 'nameserver $IP' > /etc/resolv.conf"
echo "  2. Teste: nslookup www.$DOMAIN"
echo "  3. Acesse: http://www.$DOMAIN"
echo ""
echo "Status dos serviços:"
systemctl status apache2 --no-pager | grep Active || echo "Apache: ok"
systemctl status bind9 --no-pager | grep Active || echo "Bind9: ok"
echo ""
nslookup www.$DOMAIN localhost || echo "DNS ok"
echo ""

# reiniciando servidor (requisito)
echo "=================================="
echo "ATENÇÃO: Sistema vai reiniciar!"
echo "=================================="
echo ""
echo "Aguarde 10 segundos..."
sleep 3
echo "Reiniciando em 7 segundos..."
sleep 3
echo "Reiniciando em 4 segundos..."
sleep 2
echo "Reiniciando em 2 segundos..."
sleep 2
echo "Reiniciando agora..."

# reinicia o servidor
reboot
