#!/bin/bash

# shellcheck disable=code # code is irrelevant because reasons

./reset.sh
figlet -f slant suprimoware
if [ -z "$1" ]; then
    echo "ERROR: No enviaste un nombre de dominio"
    echo "USO: ./main.sh <domain>"
    exit 1
fi

domain=$1
echo "Escaneando $domain"

# Estructura de carpetas 
timestamp=$(date +"%Y-%m-%d_%H:%M:%S")
ruta_resultados=./resultados/$domain/$timestamp

mkdir -p "$ruta_resultados"
mkdir -p "$ruta_resultados/raw"
mkdir -p "$ruta_resultados/clean"

# Análisis infraestructura
dig +short A "$domain" > "$ruta_resultados/clean/IP"
dig +short MX "$domain" > "$ruta_resultados/clean/MX"
dig +short TXT "$domain" > "$ruta_resultados/clean/TXT"
dig +short NS "$domain" > "$ruta_resultados/clean/NS"
dig +short SRV "$domain" > "$ruta_resultados/clean/SRV"
dig +short AAAA "$domain" > "$ruta_resultados/clean/AAAA"
dig +short CNAME "$domain" > "$ruta_resultados/clean/CNAME"
dig +short SOA "$domain" > "$ruta_resultados/clean/SOA"
dig +short txt _dmarc."$domain" > "$ruta_resultados/clean/DMARC" ##Snoffing correos
dig +short txt default._domainkey."$domain" > "$ruta_resultados/clean/DKIM" ##Snoffing correos

# Extrayendo rangos IP
echo "Extrayendo rangos de IP"
whois -b "$(cat "$ruta_resultados/clean/IP")" | grep 'inetnum' | awk '{print $2, $3, $4}' > "$ruta_resultados/output/rangos_ripe"

echo "Realizando whois"
whois "$domain" > "$ruta_resultados/raw/whois"
echo "Realizando dig"
dig "$domain" > "$ruta_resultados/raw/dig"

# Verificando encabezados HTTP
curl -I "https://$domain" > "$ruta_resultados/raw/headers"
cat "$ruta_resultados/raw/headers" | grep Server | awk '{print $2}' > "$ruta_resultados/clean/headers_server"

# Revisar y eliminar archivos vacíos en la carpeta /clean
for file in "$ruta_resultados/clean"/*; do
  if [ ! -s "$file" ]; then
    echo "Eliminando archivo vacío: $file"
    rm "$file"
  fi
done

while IFS= read -r ip; do
    whois -b "$ip" | grep 'inetnum' | awk '{print $2, $3, $4}' >> "$ruta_resultados/clean/rangos_ripe"
done < "$ruta_resultados/clean/IP"

# Ejecutar Nmap
echo "Ejecutando Nmap..."
nmap -sP "$domain" > "$ruta_resultados/raw/nmap_ping_scan"
nmap -sV "$domain" > "$ruta_resultados/raw/nmap_service_scan"
nmap -O "$domain" > "$ruta_resultados/raw/nmap_os_scan"

# Ejecutar Katana y filtrar con curl
echo "Ejecutando Katana y filtrando con curl"

# Ejecutar katana y procesar las URLs con curl para obtener los códigos de estado 200
katana -u "$domain" -silent | tee "$ruta_resultados/clean/katana_output" | while IFS= read -r url; do
    # Hacer la petición con curl para verificar el código de estado HTTP
    status_code=$(curl -o /dev/null -s -w "%{http_code}" "$url")
    
    # Solo guardar las URLs con código 200
    if [[ "$status_code" -eq 200 ]]; then
        echo "$url" >> "$ruta_resultados/clean/KATANA_OUTPUT"
    fi
done

# Separar dominios y subdominios
echo "Separando dominios y subdominios"
cat "$ruta_resultados/clean/KATANA_OUTPUT" | awk -F/ '{print $3}' | sort -u | grep -E '^[^.]+(\.[^.]+)+$' > "$ruta_resultados/clean/dominios.txt"  # Guardar solo dominios
cat "$ruta_resultados/clean/KATANA_OUTPUT" | awk -F/ '{print $3}' | sort -u | grep -E '^[^.]+\..+\..+$' > "$ruta_resultados/clean/subdominios.txt"  # Guardar solo subdominios

# Crear el archivo con el encabezado del dominio
echo "# $domain" > "resultado.md"
echo "## Infraestructura" >> "resultado.md"

# Función para agregar contenido de archivos a una sección específica
function agregar_registros {
    tipo_registro=$1
    archivo_registro="$ruta_resultados/clean/$tipo_registro"
    
    # Solo agregar la sección si el archivo tiene contenido
    if [[ -s "$archivo_registro" ]]; then
        echo "### $tipo_registro" >> "resultado.md"
        
        # Cambiar aquí para añadir tres # al inicio de cada línea
        sed 's/^/#### /' "$archivo_registro" >> "resultado.md"
        
        echo "" >> "resultado.md"  # Añade una línea en blanco para separar secciones
    fi
}

# Agregar diferentes tipos de registros
agregar_registros "NS"
agregar_registros "A"
agregar_registros "MX"
agregar_registros "TXT"
agregar_registros "CNAME"
agregar_registros "SRV"
agregar_registros "AAAA"
agregar_registros "SOA"
agregar_registros "headers_server"
agregar_registros "rangos_ripe"
agregar_registros "DMARC"
agregar_registros "DKIM"

# Agregar la salida de Katana
agregar_registros "KATANA_OUTPUT"



# Generar el mapa mental con markmap
markmap "resultadoPRUEBA.md" --no-open

# Iniciar servidor HTTP
python -m http.server
