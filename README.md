Etapa 1: Configuração de Rede

Modifica o arquivo /etc/network/interfaces
Configura interface enp0s3 (NAT/DHCP)
Configura interface enp0s8 (IP fixo 192.168.56.20)
Sobe a interface com ifup

Etapa 2: Atualização do Sistema

Comenta primeira linha do sources.list
Roda apt update para atualizar lista de pacotes

Etapa 3: Instalação do Apache

Instala apache2, wget e unzip
Habilita o serviço para iniciar no boot
Inicia o Apache

Etapa 4: Download e Publicação do Site

Limpa o diretório /var/www/html/
Baixa um template HTML do site tooplate.com
Descompacta os arquivos
Move tudo para a pasta do Apache
Se o download falhar, cria uma página HTML simples

Etapa 5: Configuração do DNS

Instala Bind9 e ferramentas
Cria arquivo named.conf.options (configurações gerais)
Cria arquivo named.conf.local (define a zona gabriel.local)
Cria arquivo de zona com registros DNS (ns1, www)
Valida a configuração com named-checkzone
Reinicia o Bind9

chmod +x script-completo.sh
