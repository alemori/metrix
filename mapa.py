import pandas as pd
import matplotlib.pyplot as plt

# Nombre del archivo de entrada que contiene las coordenadas
archivo_entrada = 'coordenadas.csv' # O usa 'coordenadas.txt' si lo guardaste con ese nombre

# Nombre del archivo de imagen que se va a generar
archivo_salida = 'mapa_final.png'

try:
    # Lee el archivo CSV. 
    # Asumimos que no tiene encabezado y las columnas son: latitud, longitud
    df = pd.read_csv(archivo_entrada, header=None, names=['latitud', 'longitud'])

    # Crea la figura y el gráfico de dispersión
    plt.figure(figsize=(10, 10))
    plt.scatter(df['longitud'], df['latitud'], s=15, alpha=0.7)

    # Añade títulos y etiquetas para mayor claridad
    plt.title('Mapa de Posicionamiento')
    plt.xlabel('Longitud')
    plt.ylabel('Latitud')
    plt.grid(True)
    
    # Asegura que la escala de los ejes sea similar para una mejor representación geográfica
    plt.gca().set_aspect('equal', adjustable='box')

    # Guarda el gráfico como un archivo de imagen
    plt.savefig(archivo_salida)
    
    print(f"¡Mapa generado exitosamente! Revisa el archivo '{archivo_salida}' en esta misma carpeta.")

except FileNotFoundError:
    print(f"Error: No se pudo encontrar el archivo '{archivo_entrada}'.")
    print("Asegúrate de que el archivo esté en la misma carpeta que este script.")
except Exception as e:
    print(f"Ocurrió un error inesperado: {e}")