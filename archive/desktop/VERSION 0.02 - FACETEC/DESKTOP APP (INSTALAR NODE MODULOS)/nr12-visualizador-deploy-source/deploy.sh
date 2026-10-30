#!/bin/bash
##############################################################
#  deploy.sh — Setup automático na VPS
#  Planta Fabril 3D | NR-12/NR-06 Viewer
#  KazinhoSystems / ArrudaCorp
#
#  COMO USAR:
#    1. Envie esta pasta inteira para a VPS via SCP/FTP
#    2. No terminal SSH da VPS, execute:
#         chmod +x /tmp/nr12-viewer/deploy.sh
#         bash /tmp/nr12-viewer/deploy.sh
##############################################################

set -e  # Para em caso de erro

SITE_DIR="/var/www/nr12-viewer"
NGINX_CONF="/etc/nginx/sites-available/nr12-viewer"
NGINX_ENABLED="/etc/nginx/sites-enabled/nr12-viewer"
UPLOAD_DIR="$(dirname "$0")"  # pasta onde está este script

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Planta Fabril 3D — Deploy NR-12/NR-06 Viewer      ║"
echo "║   KazinhoSystems / ArrudaCorp                       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── 1. Instalar Nginx se não estiver instalado ──────────────
echo "▶ [1/6] Verificando Nginx..."
if ! command -v nginx &> /dev/null; then
    echo "  → Nginx não encontrado. Instalando..."
    apt-get update -qq
    apt-get install -y nginx
    echo "  ✓ Nginx instalado."
else
    echo "  ✓ Nginx já instalado: $(nginx -v 2>&1)"
fi

# ── 2. Criar estrutura de pastas ────────────────────────────
echo ""
echo "▶ [2/6] Criando pasta do site..."
mkdir -p "$SITE_DIR/assets"
mkdir -p "$SITE_DIR/css"
mkdir -p "$SITE_DIR/js"
echo "  ✓ Pasta criada: $SITE_DIR"

# ── 3. Copiar arquivos do site ──────────────────────────────
echo ""
echo "▶ [3/6] Copiando arquivos do site..."

cp "$UPLOAD_DIR/index.html"       "$SITE_DIR/index.html"
cp "$UPLOAD_DIR/css/style.css"    "$SITE_DIR/css/style.css"
cp "$UPLOAD_DIR/js/main.js"       "$SITE_DIR/js/main.js"

# Copiar factory.obj se existir
if [ -f "$UPLOAD_DIR/assets/factory.obj" ]; then
    echo "  → Copiando factory.obj (arquivo grande, aguarde)..."
    cp "$UPLOAD_DIR/assets/factory.obj" "$SITE_DIR/assets/factory.obj"
    echo "  ✓ factory.obj copiado."
else
    echo "  ⚠ factory.obj não encontrado na pasta de upload."
    echo "    Copie manualmente para: $SITE_DIR/assets/factory.obj"
fi

# Ajustar permissões
chown -R www-data:www-data "$SITE_DIR"
chmod -R 755 "$SITE_DIR"
echo "  ✓ Arquivos copiados e permissões ajustadas."

# ── 4. Configurar Nginx ─────────────────────────────────────
echo ""
echo "▶ [4/6] Configurando Nginx..."

cp "$UPLOAD_DIR/nr12-viewer.nginx.conf" "$NGINX_CONF"

# Ativar site
if [ ! -L "$NGINX_ENABLED" ]; then
    ln -s "$NGINX_CONF" "$NGINX_ENABLED"
fi

# Desativar site padrão (evita conflito)
if [ -L "/etc/nginx/sites-enabled/default" ]; then
    rm -f "/etc/nginx/sites-enabled/default"
    echo "  → Site padrão do Nginx desativado."
fi

# Testar configuração
echo "  → Testando configuração Nginx..."
nginx -t
echo "  ✓ Configuração Nginx OK."

# ── 5. Iniciar / Recarregar Nginx ───────────────────────────
echo ""
echo "▶ [5/6] Iniciando Nginx..."
systemctl enable nginx
systemctl reload nginx
echo "  ✓ Nginx recarregado com sucesso."

# ── 6. Verificar e exibir IP ────────────────────────────────
echo ""
echo "▶ [6/6] Verificando acesso..."
VPS_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s api.ipify.org 2>/dev/null || echo "IP_NAO_DETECTADO")

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   ✅ DEPLOY CONCLUÍDO COM SUCESSO!                   ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║                                                      ║"
echo "║   🌐 Acesse agora:  http://$VPS_IP"
echo "║                                                      ║"
echo "║   📁 Arquivos em:   $SITE_DIR"
echo "║                                                      ║"
echo "║   Para adicionar domínio, edite:                     ║"
echo "║   $NGINX_CONF                   "
echo "║   Linha: server_name _;                              ║"
echo "║   Troque por: server_name seudominio.com.br;         ║"
echo "║                                                      ║"
echo "║   Para SSL gratuito (HTTPS), execute:                ║"
echo "║   apt install certbot python3-certbot-nginx -y       ║"
echo "║   certbot --nginx -d seudominio.com.br               ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
