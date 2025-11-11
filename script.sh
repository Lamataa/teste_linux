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
    echo "[AVISO] Sem conectividade detectada. Tentando adicionar rota padrão..."
    ip route add default via 10.0.2.2 dev enp0s3 2>/dev/null || true
    sleep 1
    
    if ping -c 2 8.8.8.8 &> /dev/null; then
        echo "[OK] Conectividade restaurada!"
    else
        echo "[AVISO] Ainda sem internet. Script continuará, mas downloads podem falhar."
    fi
else
    echo "[OK] Conectividade confirmada!"
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
echo "[WEB] Isso pode levar alguns minutos dependendo da conexão..."
sleep 1

apt-get install -y apache2 wget unzip || {
    echo "[ERRO] Falha ao instalar pacotes do Apache!"
    echo "Verifique se há conectividade com a internet."
    exit 1
}

echo "[WEB] Habilitando serviço Apache para iniciar no boot..."
systemctl enable apache2
echo "[WEB] Iniciando serviço Apache..."
systemctl start apache2
echo "[OK] Apache instalado e iniciado!"
sleep 1

# Baixa e publica um template HTML da Internet
echo "[WEB] Preparando diretório do site..."
rm -rf /var/www/html/*
echo "[WEB] Baixando template HTML da internet..."
echo "[WEB] URL: https://www.tooplate.com/zip-templates/2133_moso_interior.zip"
sleep 1

# Tenta baixar o template (usando template diferente)
if wget -q --timeout=10 --tries=2 https://www.tooplate.com/zip-templates/2133_moso_interior.zip -O /tmp/site.zip 2>/dev/null; then
    echo "[OK] Template baixado com sucesso!"
    echo "[WEB] Descompactando arquivos..."
    unzip -q /tmp/site.zip -d /tmp/site 2>/dev/null
    echo "[WEB] Movendo arquivos para /var/www/html/..."
    mv /tmp/site/*/* /var/www/html/ 2>/dev/null || mv /tmp/site/* /var/www/html/ 2>/dev/null
    echo "[WEB] Limpando arquivos temporários..."
    rm -rf /tmp/site /tmp/site.zip
    echo "[OK] Template profissional publicado!"
else
    echo "[AVISO] Falha ao baixar template da internet."
    echo "[WEB] Criando página HTML padrão personalizada..."
    cat > /var/www/html/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Servidor Gabriel.local</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        h1 { font-size: 3em; margin-bottom: 20px; }
        p { font-size: 1.5em; }
        .info { background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px; margin-top: 30px; }
    </style>
</head>
<body>
    <h1>🚀 Servidor Web Apache</h1>
    <p>Domínio: gabriel.local</p>
    <div class="info">
        <p>✅ Servidor configurado com sucesso!</p>
        <p>📅 Data: $(date)</p>
    </div>
</body>
</html>
HTMLEOF
    echo "[OK] Página padrão criada!"
fi

echo "[WEB] Ajustando permissões dos arquivos..."
chown -R www-data:www-data /var/www/html

echo "[OK] Site publicado em http://$IP"
sleep 1

# ----------------------------------------------
# INSTALAÇÃO E CONFIGURAÇÃO DO DNS (BIND9)
# ----------------------------------------------
echo "[DNS] Instalando e configurando o Bind9..."
echo "[DNS] Instalando pacotes necessários..."
sleep 1

apt-get install -y bind9 bind9utils bind9-doc dnsutils || {
    echo "[ERRO] Falha ao instalar pacotes do Bind9!"
    echo "Verifique se há conectividade com a internet."
    exit 1
}

echo "[OK] Pacotes do Bind9 instalados!"
echo "[DNS] Configurando arquivo named.conf.options..."
sleep 1

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

echo "[OK] Arquivo named.conf.options criado!"
echo "[DNS] Configurando arquivo named.conf.local..."
sleep 1

# Arquivo /etc/bind/named.conf.local
cat > /etc/bind/named.conf.local <<EOF
zone "$DOMAIN" IN {
    type master;
    file "$ZONE_FILE";
    allow-transfer { any; };
};
EOF

echo "[OK] Arquivo named.conf.local criado!"
echo "[DNS] Criando arquivo de zona para o domínio $DOMAIN..."
sleep 1

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

echo "[OK] Arquivo de zona criado!"
echo "[DNS] Ajustando permissões..."
chown bind:bind $ZONE_FILE

echo "[DNS] Validando sintaxe do arquivo de zona..."
# Verifica a zona antes de reiniciar
if named-checkzone $DOMAIN $ZONE_FILE; then
    echo "[OK] Arquivo de zona validado com sucesso!"
else
    echo "[ERRO] Erro na sintaxe do arquivo de zona!"
    exit 1
fi

echo "[DNS] Reiniciando serviço Bind9..."
# Reinicia o serviço DNS
systemctl restart bind9 2>/dev/null || systemctl restart named 2>/dev/null || /etc/init.d/bind9 restart

echo "[DNS] Habilitando Bind9 para iniciar no boot..."
# Tenta habilitar o serviço (ignora erro se já estiver habilitado)
systemctl enable bind9 2>/dev/null || systemctl enable named 2>/dev/null || true

echo "[OK] DNS configurado para o domínio $DOMAIN"
sleep 1

# ----------------------------------------------
# CONFIGURAÇÃO DO FIREWALL (SE HOUVER)
# ----------------------------------------------
echo "[FIREWALL] Verificando firewall..."
sleep 1

if command -v ufw &> /dev/null; then
    echo "[FIREWALL] UFW detectado, configurando regras..."
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
echo "=============================================="
echo "Verificando status dos serviços..."
echo "=============================================="
echo ""
echo "📊 Status do Apache:"
systemctl status apache2 --no-pager 2>/dev/null | grep Active || /etc/init.d/apache2 status | grep running
echo ""
echo "📊 Status do Bind9:"
systemctl status bind9 --no-pager 2>/dev/null | grep Active || systemctl status named --no-pager 2>/dev/null | grep Active || /etc/init.d/bind9 status | grep running
echo ""
echo "=============================================="
echo "Testando DNS localmente..."
echo "=============================================="
nslookup www.$DOMAIN localhost || dig www.$DOMAIN @localhost
echo ""
echo "=============================================="
echo "🎉 SERVIDOR PRONTO PARA USO!"
echo "=============================================="
