import os

# Lista de archivos de texto
files = {
    "Registros A": "IP",
    "Registros AAAA": "AAAA",
    "Registros CNAME": "CNAME",
    "Registros MX": "MX",
    "Registros TXT": "TXT"
}

# Crear el archivo Markdown
markdown_file = 'reconocimiento.md'

with open(markdown_file, 'w') as md_file:
    md_file.write('# Reconocimiento de example.com\n\n')
    md_file.write('## Registros DNS\n\n')

    for title, filename in files.items():
        md_file.write(f'### {title}\n')
        
        # Comprobar si el archivo existe y agregar su contenido
        if os.path.exists(filename):
            with open(filename, 'r') as f:
                for line in f:
                    md_file.write(f'- {line.strip()}\n')
        else:
            md_file.write('- No se encontraron registros.\n')
        
        md_file.write('\n')

print(f'Archivo {markdown_file} generado exitosamente.')
