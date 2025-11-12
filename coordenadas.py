# Nombres de los archivos de entrada y salida
archivo_entrada = 'datos_procesados.txt'
archivo_salida = 'coordenadas.txt'

try:
    # 'with' asegura que los archivos se cierren automáticamente
    with open(archivo_entrada, 'r') as f_entrada, open(archivo_salida, 'w') as f_salida:
        # Itera sobre cada línea en el archivo de entrada
        for linea in f_entrada:
            # Elimina espacios en blanco y divide la línea por comas
            partes = linea.strip().split(',')
            
            # Asegurarse de que la línea tiene suficientes campos
            if len(partes) >= 2:
                # Tomar los dos últimos campos (índices -2 y -1)
                latitud = partes[-2]
                longitud = partes[-1]
                
                # Escribir los dos campos en el nuevo archivo, separados por una coma
                # y con un salto de línea al final
                f_salida.write(f"{latitud},{longitud}\n")
                
    print(f"¡Proceso completado! Se ha creado el archivo '{archivo_salida}'.")

except FileNotFoundError:
    print(f"Error: El archivo '{archivo_entrada}' no fue encontrado.")
except Exception as e:
    print(f"Ha ocurrido un error: {e}")