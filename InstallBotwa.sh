#!/bin/bash

# ===========================================
#  🧩 PANEL WHATSAPP BOT – con escaneo QR
#  Autor: MaulynetZ + GPT-5
#  Versión Corregida y Mejorada: Manus
# ===========================================

# --- Variables y Colores ---
BOT_DIR="/root/whatsapp-bot"
BOT_ZIP_URL="https://github.com/MaulynetZ/wavob/raw/main/Bot.zip"
BOT_MAIN="index.js"
BOT_NAME_FILE="/root/.bot_name"

# Códigos de color ANSI
readonly R='\033[0m'    # Reset
readonly Y='\033[1;33m' # Yellow
readonly C='\033[1;36m' # Cyan
readonly W='\033[1;37m' # White
readonly G='\033[1;32m' # Green
readonly R_BOLD='\033[1;31m' # Red Bold

# --- Funciones de Utilidad ---

# Muestra un mensaje de éxito
msg_success() {
    echo -e "${G}✅ $1${R}"
}

# Muestra un mensaje de advertencia/información
msg_info() {
    echo -e "${C}ℹ️  $1${R}"
}

# Muestra un mensaje de error
msg_error() {
    echo -e "${R_BOLD}❌ $1${R}"
}

# Pausa la ejecución y limpia la pantalla
pausar_y_limpiar() {
    echo
    echo -e "${C}Presiona Enter para continuar...${R}"
    read -r
    clear
}

# Verifica si el bot está configurado en PM2
bot_configurado() {
    [ -f "$BOT_NAME_FILE" ] && [ -s "$BOT_NAME_FILE" ]
}

# Obtiene el nombre del bot configurado en PM2
get_bot_name() {
    if bot_configurado; then
        cat "$BOT_NAME_FILE"
    else
        echo "[Bot no configurado]"
    fi
}

# Verifica si el bot está corriendo (estado de PM2)
bot_corriendo() {
    if bot_configurado; then
        local nombre_bot
        nombre_bot=$(cat "$BOT_NAME_FILE")
        pm2 status "$nombre_bot" | grep -q "online"
        return $?
    else
        return 1
    fi
}

# --- Funciones del Menú Principal ---

instalar_dependencias() {
    msg_info "📦 Instalando dependencias del sistema..."

    # Detección de Sistema Operativo: Solo soporta Debian/Ubuntu
    if ! command -v apt >/dev/null 2>&1; then
        msg_error "Sistema operativo no soportado. Este script solo funciona en sistemas basados en Debian/Ubuntu."
        return 1
    fi

    # --- 1. Comprobación de Estado Granular ---
    local DEPS_OK=true
    local DEPS_TO_INSTALL=""
    local NODE_VERSION_OK=true
    
    msg_info "Realizando comprobación granular de dependencias..."
    
    # Paquetes a verificar
    local REQUIRED_DEPS=("curl" "wget" "unzip" "git")
    local INSTALLED_DEPS=""
    local MISSING_DEPS=""
    
    # Verificar herramientas básicas
    for dep in "${REQUIRED_DEPS[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            INSTALLED_DEPS+="✅ $dep "
        else
            MISSING_DEPS+="❌ $dep "
            DEPS_OK=false
            DEPS_TO_INSTALL+=" $dep"
        fi
    done
    
    # Verificar Node.js y NPM
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node -v)
        if echo "$node_version" | grep -q "v20"; then
            INSTALLED_DEPS+="✅ Node.js ($node_version) "
        else
            MISSING_DEPS+="❌ Node.js (Detectado: $node_version, Requerido: v20) "
            DEPS_OK=false
            NODE_VERSION_OK=false
        fi
    else
        MISSING_DEPS+="❌ Node.js "
        DEPS_OK=false
    fi
    
    if command -v npm >/dev/null 2>&1; then
        INSTALLED_DEPS+="✅ npm "
    else
        MISSING_DEPS+="❌ npm "
        DEPS_OK=false
    fi
    
    echo -e "${G}--- Estado de Dependencias ---${R}"
    echo -e "${G}Instaladas: ${INSTALLED_DEPS}${R}"
    echo -e "${R_BOLD}Faltantes: ${MISSING_DEPS}${R}"
    echo -e "${G}------------------------------${R}"
    
    # --- 2. Lógica de Acción ---
    
    # Caso 1: Todo OK
    if $DEPS_OK; then
        msg_success "Todas las dependencias requeridas están instaladas. Proceso finalizado."
        return 0
    fi
    
    # Caso 2: Falta algo, preguntar si desea instalar
    echo
    read -r -p "$(echo -e ${Y}"¿Desea proceder con la instalación/actualización de las dependencias faltantes? (S/n): "${R})" INSTALL_CHOICE
    echo
    
    if [[ ! "$INSTALL_CHOICE" =~ ^[SsYy]$ ]]; then
        msg_info "Instalación cancelada por el usuario."
        return 0
    fi
    
    # Caso 3: Purga si la versión de Node.js es incorrecta o si falta NPM (instalación corrupta)
    if ! $NODE_VERSION_OK || ! command -v npm >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
        msg_info "⚠️ Realizando purga de Node.js para asegurar la versión 20.x o corregir la instalación."
        # Comando de purga de Node.js, npm y archivos residuales
        sudo apt remove --purge -y nodejs npm >/dev/null 2>&1
        sudo rm -rf /etc/apt/sources.list.d/nodesource.list /root/.npm /usr/local/lib/node_modules /usr/bin/node /usr/bin/npm
        sudo apt autoremove -y >/dev/null 2>&1
    fi
    
    # 2. Instalación
    # --- 3. Instalación ---
    
    msg_info "Actualizando lista de paquetes..."
    if ! sudo apt update -y >/dev/null 2>&1; then
        msg_error "Fallo al actualizar los paquetes del sistema."
        return 1
    fi
    
    # Instalar herramientas básicas faltantes
    if [ -n "$DEPS_TO_INSTALL" ]; then
        msg_info "Instalando herramientas básicas faltantes: $DEPS_TO_INSTALL..."
        if ! sudo apt install -y $DEPS_TO_INSTALL >/dev/null 2>&1; then
            msg_error "Fallo al instalar paquetes básicos faltantes."
            return 1
        fi
    fi
    
    # Instalar Node.js 20 (si no estaba o fue purgado)
    if ! command -v node >/dev/null 2>&1; then
        msg_info "Instalando Node.js versión 20 (LTS)..."
        
        sudo rm -f /etc/apt/sources.list.d/nodesource.list
        if ! curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - >/dev/null 2>&1; then
            msg_error "Fallo al configurar el repositorio de NodeSource (v20)."
            return 1
        fi
        
        if ! sudo apt install -y nodejs >/dev/null 2>&1; then
            msg_error "Fallo al instalar Node.js y npm."
            return 1
        fi
        
        msg_success "Node.js 20 (LTS) y npm instalados correctamente."
    else
        msg_info "Node.js ya está instalado (versión correcta o recién purgado/reinstalado)."
    fi
}

descargar_bot() {
    msg_info "⬇️  Descargando bot desde GitHub..."
    mkdir -p "$BOT_DIR"
    cd "$BOT_DIR" || { msg_error "No se pudo acceder al directorio del bot: $BOT_DIR"; return 1; }
    
    if ! wget -q "$BOT_ZIP_URL" -O Bot.zip; then
        msg_error "Error al descargar el archivo del bot."
        return 1
    fi
    
    if ! unzip -o Bot.zip >/dev/null 2>&1; then
        msg_error "Error al descomprimir el archivo del bot."
        rm -f Bot.zip
        return 1
    fi
    
    rm -f Bot.zip
    msg_success "Bot descargado en: ${W}$BOT_DIR${R}"
}

eliminar_bot_total() {
    msg_info "🗑️ Eliminando bot y archivos asociados..."
    if bot_configurado; then
        desinstalar_pm2_forzado
    fi
    if [ -d "$BOT_DIR" ]; then
        rm -rf "$BOT_DIR"
        msg_success "Carpeta del bot eliminada."
    else
        msg_info "⚠️  La carpeta del bot no existe."
    fi
    msg_success "Eliminación del bot completada."
}

registrar_admin() {
    local cerebro_file="$BOT_DIR/cerebro.js"
    local admin_jid
    
    msg_info "📝 Configurando JID del Administrador..."
    
    if [ ! -f "$cerebro_file" ]; then
        msg_error "Archivo cerebro.js no encontrado en $BOT_DIR."
        msg_info "Asegúrate de haber descargado el bot (Opción [2]) primero."
        return 1
    fi
    
    # 1. Solicitar JID
    while [ -z "$admin_jid" ]; do
        read -r -p "$(echo -e ${Y}"Ingresa el JID del administrador (ej: 573001234567@s.whatsapp.net): "${R})" admin_jid
        if [ -z "$admin_jid" ]; then
            msg_error "El JID no puede estar vacío."
        fi
    done
    
    # 2. Actualizar la constante en cerebro.js
    # Usamos sed para buscar la línea que define la constante y reemplazar el valor.
    # Asumimos que la constante se llama ADMIN_JID y tiene el formato: const ADMIN_JID = '57300...';
    # Escapamos los caracteres especiales para sed.
    local escaped_jid=$(echo "$admin_jid" | sed 's/[\/&]/\\&/g')
    
    # Patrón Corregido: Busca const ADMIN_JID = "..." y reemplaza el contenido entre comillas dobles.
    # Se añade validación con grep para asegurar que la línea existe antes de intentar modificarla.
    
    if ! grep -q '^const ADMIN_JID = ".*";$' "$cerebro_file"; then
        msg_error "No se encontró la constante 'const ADMIN_JID = \"...\";' en el formato esperado."
        msg_info "Asegúrate de que la constante esté definida como: const ADMIN_JID = \"...\"; en cerebro.js."
        return 1
    fi

    if ! sed -i "s/^\(const ADMIN_JID = \"\)[^\"]*\(\";.*$\)/\1$escaped_jid\2/" "$cerebro_file"; then
        msg_error "Fallo al actualizar la constante ADMIN_JID en cerebro.js."
        msg_info "Asegúrate de que la constante esté definida como: const ADMIN_JID = "..." y que el formato sea correcto."
        return 1
    fi
    
    msg_success "JID del administrador actualizado a: ${W}$admin_jid${R}"
    msg_info "Si el bot está corriendo, reinícialo (Opción [7]) para aplicar el cambio."
}

eliminar_sesion_bot() {
    msg_info "🗑️ Eliminando archivos de sesión del bot..."
    if bot_configurado; then
        local nombre_bot=$(cat "$BOT_NAME_FILE")
        if bot_corriendo; then
            pm2 stop "$nombre_bot" >/dev/null 2>&1
            msg_info "Bot detenido para liberar archivos de sesión."
        fi
    fi
    if [ -d "$BOT_DIR/auth_info_baileys" ]; then
        rm -rf "$BOT_DIR"/auth_info_baileys
        msg_success "Archivos de sesión eliminados. Deberás escanear un nuevo QR."
    else
        msg_info "⚠️  No se encontraron archivos de sesión para eliminar."
    fi
}

instalar_dependencias_bot() {
    msg_info "📦 Instalando dependencias internas del bot..."
    cd "$BOT_DIR" || { msg_error "Carpeta del bot no encontrada. Ejecuta la opción [2] Descargar bot primero."; return 1; }
    
    local package_json="$BOT_DIR/package.json"
    
    # 1. Mostrar dependencias
    if [ -f "$package_json" ]; then
        msg_info "Dependencias a instalar (según package.json):"
        # Usar grep para extraer las líneas de "dependencies" y "devDependencies"
        grep -E '"(dependencies|devDependencies)"' -A 10 "$package_json" | grep -E '^\s+"' | sed 's/^\s*//; s/",//; s/": "/: /' | sed 's/"//g' | while read -r line; do
            echo -e "${W}  - ${line}${R}"
        done
        echo
    else
        msg_error "Archivo package.json no encontrado. No se puede verificar la lista de dependencias."
        return 1
    fi
    
    # 2. Comprobación de existencia de node_modules
    if [ -d "$BOT_DIR/node_modules" ]; then
        msg_success "✅ La carpeta 'node_modules' ya existe."
        echo
        read -r -p "$(echo -e ${Y}"¿Desea reinstalar las dependencias (npm install)? (S/n): "${R})" REINSTALL_CHOICE
        echo
        
        if [[ ! "$REINSTALL_CHOICE" =~ ^[SsYy]$ ]]; then
            msg_info "Reinstalación cancelada por el usuario."
            return 0
        fi
    fi
    
    # 3. Instalación/Reinstalación
    msg_info "Iniciando 'npm install'..."
    if ! npm install --silent; then
        msg_error "Fallo al instalar las dependencias de Node.js. Revisa los logs de npm."
        return 1
    fi
    
    msg_success "Dependencias del bot instaladas."
}

escanear_qr() {
    msg_info "🔍 Escaneando código QR..."
    if [ -d "$BOT_DIR/auth_info_baileys" ]; then
        msg_info "⚠️  Ya existe una sesión activa."
        msg_info "Para escanear un nuevo QR, elimina la sesión activa."
        return
    fi
    echo -e "${W}Abre WhatsApp y escanea el código que aparecerá a continuación.${R}"
    echo
    cd "$BOT_DIR" || { msg_error "Carpeta del bot no encontrada."; return 1; }
    msg_info "Presiona Ctrl+C después de escanear el QR."
    node "$BOT_MAIN"
    echo
    msg_success "Si la conexión fue exitosa, el QR no se pedirá más."
}

# --- Funciones de PM2 ---

desinstalar_pm2_forzado() {
    msg_info "🗑️ Desinstalación forzada de PM2..."
    pm2 stop all >/dev/null 2>&1 && pm2 delete all >/dev/null 2>&1
    msg_success "Procesos de PM2 detenidos y eliminados."
    pm2 unstartup systemd >/dev/null 2>&1
    msg_success "Script de inicio automático de PM2 eliminado."
    npm uninstall -g pm2 >/dev/null 2>&1
    msg_success "Paquete global de PM2 desinstalado."
    rm -rf /root/.pm2 /usr/lib/node_modules/pm2
    msg_success "Directorios de configuración de PM2 eliminados."
    rm -f "$BOT_NAME_FILE"
    msg_success "Archivo de nombre del bot eliminado."
    msg_success "Desinstalación de PM2 completada."
}

configurar_pm2() {
    msg_info "⚙️ Instalando PM2 y configurando el bot..."
    if ! command -v npm >/dev/null 2>&1; then
        msg_error "npm no está instalado. Ejecuta la opción [1] primero."
        return 1
    fi
    if ! npm install -g pm2 >/dev/null 2>&1; then
        msg_error "Fallo al instalar PM2 globalmente."
        return 1
    fi
    cd "$BOT_DIR" || { msg_error "Carpeta del bot no encontrada."; return 1; }
    local nombre_bot
    while [ -z "$nombre_bot" ]; do
        read -r -p "$(echo -e ${Y}"📝 Nombre para el bot (sin espacios): "${R})" nombre_bot
        if [ -z "$nombre_bot" ]; then
            msg_error "El nombre del bot no puede estar vacío."
        fi
    done
    if bot_configurado; then
        local old_name=$(cat "$BOT_NAME_FILE")
        pm2 delete "$old_name" >/dev/null 2>&1
    fi
    echo "$nombre_bot" > "$BOT_NAME_FILE"
    if ! pm2 start "$BOT_MAIN" --name "$nombre_bot" >/dev/null 2>&1; then
        msg_error "Fallo al iniciar el bot con PM2."
        return 1
    fi
    pm2 save >/dev/null 2>&1
    pm2 startup -u root --hp /root >/dev/null 2>&1
    msg_success "Bot registrado en PM2 como: ${W}$nombre_bot${R}"
    msg_info "PM2 configurado para inicio automático."
}

# --- Submenú de PM2 ---

control_pm2_menu() {
    while true; do
        local nombre_bot=$(get_bot_name)
        clear
        echo -e "${Y}=============================${R}"
        echo -e "${C}     ⚙️  CONTROL DE PM2${R}"
        echo -e "${W}     Bot Actual: ${nombre_bot}${R}"
        echo -e "${Y}=============================${R}"
        echo
        echo -e "${W}[1]${C} Instalar/Configurar PM2 y Bot"
        echo -e "${W}[2]${C} Desinstalar PM2"
        echo -e "${W}-----------------------------------"
        if bot_corriendo; then
            echo -e "${W}[3]${G} Bot: Corriendo (Online)${R}"
            echo -e "${W}[4]${C} Detener Bot con PM2"
        else
            echo -e "${W}[3]${R_BOLD} Bot: Detenido (Offline)${R}"
            echo -e "${W}[4]${C} Iniciar Bot con PM2"
        fi
        echo -e "${W}[5]${C} Reiniciar Bot con PM2"
        echo -e "${W}[6]${C} Logs del Bot con PM2"
        echo -e "${W}[0]${C} Volver al Menú Principal${R}"
        echo
        read -r -p "$(echo -e ${Y}"Selecciona una opción: "${R})" op

        if [[ "$op" -ge 3 && "$op" -le 6 ]] && ! bot_configurado; then
            msg_error "El bot aún no está configurado en PM2."
            msg_info "Ejecuta primero la opción 1."
            pausar_y_limpiar
            continue
        fi

        case $op in
            1) configurar_pm2 ; pausar_y_limpiar ;;
            2) desinstalar_pm2_forzado ; pausar_y_limpiar ;;
            3) 
                if bot_corriendo; then
                    msg_info "El bot ya está corriendo."
                else
                    msg_info "▶️ Iniciando bot..."
                    pm2 start "$nombre_bot" >/dev/null 2>&1
                    msg_success "Bot iniciado."
                fi
                pausar_y_limpiar
                ;;
            4) 
                if bot_corriendo; then
                    msg_info "⏹️ Deteniendo bot..."
                    pm2 stop "$nombre_bot" >/dev/null 2>&1
                    msg_success "Bot detenido."
                else
                    msg_info "El bot ya está detenido. Iniciando bot..."
                    pm2 start "$nombre_bot" >/dev/null 2>&1
                    msg_success "Bot iniciado."
                fi
                pausar_y_limpiar
                ;;
            5) 
                msg_info "🔄 Reiniciando bot..."
                pm2 restart "$nombre_bot" >/dev/null 2>&1
                msg_success "Bot reiniciado."
                pausar_y_limpiar
                ;;
            6) 
                msg_info "Mostrando logs del bot. Presiona Ctrl+C para volver."
                pm2 logs "$nombre_bot"
                pausar_y_limpiar
                ;;
            0) break ;;
            *) msg_error "Opción inválida." ; pausar_y_limpiar ;;
        esac
    done
}

# --- Menú principal ---
main_menu() {
    while true; do
        clear
        echo -e "${Y}==============================================${R}"
        echo -e "${C}          🧩 PANEL WHATSAPP BOT${R}"
        echo -e "${Y}==============================================${R}"
        echo
        echo -e "${W}[1]${C} Instalar dependencias del sistema"
        echo -e "${W}[2]${C} Descargar bot"
        echo -e "${W}[3]${C} Eliminar bot"
        echo -e "${W}[4]${C} Eliminar Sesión"
        echo -e "${W}[5]${C} Registrar Administrador"
        echo -e "${W}[6]${C} Instalar dependencias del bot"
        echo -e "${W}[7]${C} Escanear código QR"
        echo -e "${W}[8]${C} Control de PM2 y Bot"
        echo -e "${W}[0]${C} Salir${R}"
        echo
        read -r -p "$(echo -e ${Y}"Selecciona una opción: "${R})" opcion

        case $opcion in
            1) instalar_dependencias ; pausar_y_limpiar ;;
            2) descargar_bot ; pausar_y_limpiar ;;
            3) eliminar_bot_total ; pausar_y_limpiar ;;
            4) eliminar_sesion_bot ; pausar_y_limpiar ;;
            5) registrar_admin ; pausar_y_limpiar ;;
            6) instalar_dependencias_bot ; pausar_y_limpiar ;;
            7) escanear_qr ; pausar_y_limpiar ;;
            8) control_pm2_menu ;;
            0) msg_info "👋 Saliendo..."; exit 0 ;;
            *) msg_error "Opción inválida." ; pausar_y_limpiar ;;
        esac
    done
}

# --- Inicio del Script ---

if [ "$(id -u)" -ne 0 ]; then
    msg_error "Este script debe ser ejecutado como usuario root."
    exit 1
fi

if [ -z "$BASH_VERSION" ]; then
    msg_error "Este script debe ser ejecutado con Bash."
    exit 1
fi

main_menu