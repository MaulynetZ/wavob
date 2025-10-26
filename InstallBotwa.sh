#!/bin/bash
# ===========================================
#  🧩 PANEL WHATSAPP BOT – con escaneo QR
#  Autor: MaulynetZ + GPT-5
# ===========================================

# --- Colores ---
yellow="\033[1;33m"
cyan="\033[1;36m"
white="\033[1;37m"
reset="\033[0m"

# --- Variables ---
BOT_DIR="/root/whatsapp-bot"
BOT_ZIP_URL="https://github.com/MaulynetZ/wavob/raw/main/Bot.zip"
BOT_MAIN="index.js"
BOT_NAME_FILE="/root/.bot_name"

# --- Funciones ---

instalar_dependencias() {
    echo -e "${cyan}📦 Instalando dependencias del sistema...${reset}"
    apt update -y >/dev/null 2>&1
    apt install -y curl wget unzip git >/dev/null 2>&1
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
    apt install -y nodejs npm >/dev/null 2>&1
    echo -e "${yellow}✅ Dependencias instaladas correctamente.${reset}"
    sleep 1
}

descargar_bot() {
    echo -e "${cyan}⬇️  Descargando bot desde GitHub...${reset}"
    mkdir -p "$BOT_DIR"
    cd "$BOT_DIR" || exit
    wget -q "$BOT_ZIP_URL" -O Bot.zip
    if [ ! -f "Bot.zip" ]; then
        echo -e "${yellow}❌ Error al descargar el archivo del bot.${reset}"
        return
    fi
    unzip -o Bot.zip >/dev/null 2>&1
    rm -f Bot.zip
    echo -e "${yellow}✅ Bot descargado en:${white} $BOT_DIR${reset}"
    sleep 1
}

instalar_dependencias_bot() {
    echo -e "${cyan}📦 Instalando dependencias internas del bot...${reset}"
    cd "$BOT_DIR" || { echo -e "${yellow}❌ Carpeta del bot no encontrada.${reset}"; return; }
    npm install >/dev/null 2>&1
    echo -e "${yellow}✅ Dependencias del bot instaladas.${reset}"
    sleep 1
}

escanear_qr() {
    echo -e "${cyan}🔍 Escaneando código QR...${reset}"
    echo -e "${white}Abre WhatsApp y escanea el código que aparecerá a continuación.${reset}"
    echo
    cd "$BOT_DIR" || { echo -e "${yellow}❌ Carpeta del bot no encontrada.${reset}"; return; }

    # Ejecuta node index.js para mostrar QR en consola
    node "$BOT_MAIN"

    echo
    echo -e "${yellow}✅ Si la conexión fue exitosa, el QR ya no se pedirá más.${reset}"
    echo -e "${cyan}Presiona Enter para volver al panel...${reset}"
    read
}

instalar_pm2() {
    echo -e "${cyan}⚙️ Instalando PM2 y configurando el bot...${reset}"
    npm install -g pm2 >/dev/null 2>&1
    cd "$BOT_DIR" || exit
    read -p "$(echo -e ${yellow}"📝 Nombre para el bot (sin espacios): "${reset})" nombre_bot
    [ -z "$nombre_bot" ] && nombre_bot="whatsapp-bot"
    echo "$nombre_bot" > "$BOT_NAME_FILE"

    pm2 start "$BOT_MAIN" --name "$nombre_bot" >/dev/null 2>&1
    pm2 save >/dev/null 2>&1
    pm2 startup -u root --hp /root >/dev/null 2>&1
    echo -e "${yellow}✅ Bot registrado en PM2 como:${white} $nombre_bot${reset}"
    sleep 1
}

controlar_bot() {
    clear
    if [ ! -f "$BOT_NAME_FILE" ]; then
        echo -e "${yellow}⚠️  El bot aún no está configurado en PM2.${reset}"
        echo -e "${cyan}Ejecuta primero la opción 5 (Configurar PM2).${reset}"
        sleep 2
        return
    fi

    nombre_bot=$(cat "$BOT_NAME_FILE")

    while true; do
        clear
        echo -e "${yellow}=============================${reset}"
        echo -e "${cyan}     ⚙️  CONTROL DEL BOT${reset}"
        echo -e "${yellow}=============================${reset}"
        echo
        echo -e "${white}[1]${cyan} Iniciar bot"
        echo -e "${white}[2]${cyan} Detener bot"
        echo -e "${white}[3]${cyan} Reiniciar bot"
        echo -e "${white}[4]${cyan} Logs del bot"
        echo -e "${white}[0]${cyan} Volver${reset}"
        echo
        read -p "$(echo -e ${yellow}"Selecciona una opción: "${reset})" op

        case $op in
            1) echo -e "${cyan}▶️ Iniciando bot...${reset}"; pm2 start "$nombre_bot" ;;
            2) echo -e "${cyan}⏹️ Deteniendo bot...${reset}"; pm2 stop "$nombre_bot" ;;
            3) echo -e "${cyan}🔄 Reiniciando bot...${reset}"; pm2 restart "$nombre_bot" ;;
            4) pm2 logs "$nombre_bot" ;;
            0) break ;;
            *) echo -e "${yellow}❌ Opción inválida.${reset}" ;;
        esac
        sleep 1
    done
}

# --- Menú principal ---
while true; do
    clear
    echo -e "${yellow}==============================================${reset}"
    echo -e "${cyan}          🧩 PANEL WHATSAPP BOT${reset}"
    echo -e "${yellow}==============================================${reset}"
    echo
    echo -e "${white}[1]${cyan} Instalar dependencias del sistema"
    echo -e "${white}[2]${cyan} Descargar bot"
    echo -e "${white}[3]${cyan} Instalar dependencias del bot"
    echo -e "${white}[4]${cyan} Escanear código QR"
    echo -e "${white}[5]${cyan} Configurar PM2"
    echo -e "${white}[6]${cyan} Control del bot"
    echo -e "${white}[0]${cyan} Salir${reset}"
    echo
    read -p "$(echo -e ${yellow}"Selecciona una opción: "${reset})" opcion

    case $opcion in
        1) instalar_dependencias ;;
        2) descargar_bot ;;
        3) instalar_dependencias_bot ;;
        4) escanear_qr ;;
        5) instalar_pm2 ;;
        6) controlar_bot ;;
        0) echo -e "${white}👋 Saliendo...${reset}"; exit 0 ;;
        *) echo -e "${yellow}❌ Opción inválida.${reset}" ;;
    esac
done