# Definimos los nombres de los archivos de entrada y salida
archivo_entrada = 'fumigacion_log-5.txt'
archivo_salida = 'datos_procesados.txt'

try:
    # Usamos 'with' para asegurarnos de que los archivos se cierren correctamente
    with open(archivo_entrada, 'r') as infile, open(archivo_salida, 'w') as outfile:
        # Leemos cada línea del archivo original
        for linea in infile:
            # Verificamos si la cadena "N/A,N/A" NO está en la línea
            if 'N/A,N/A' not in linea:
                # Si no está, escribimos la línea en el nuevo archivo
                outfile.write(linea)
    
    print(f"¡Listo! Se ha creado el archivo '{archivo_salida}' sin los registros no deseados.")

except FileNotFoundError:
    print(f"Error: No se pudo encontrar el archivo de entrada '{archivo_entrada}'.")
    print("Asegúrate de que el archivo esté en la misma carpeta que este script.")

except Exception as e:
    print(f"Ocurrió un error inesperado: {e}")