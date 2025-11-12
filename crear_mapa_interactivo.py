import pandas as pd
import folium

# Nombre del archivo de entrada que contiene las coordenadas
archivo_entrada = 'coordenadas.csv'

# Nombre del archivo de salida del mapa
archivo_salida = 'mapa_interactivo.html'

try:
    # Lee el archivo CSV. Asumimos que las columnas son: latitud, longitud
    df = pd.read_csv(archivo_entrada, header=None, names=['latitud', 'longitud'])

    # Calcula el punto central del mapa para que todos los marcadores sean visibles
    latitud_media = df['latitud'].mean()
    longitud_media = df['longitud'].mean()

    # Crea el objeto de mapa, centrado en el punto medio de tus coordenadas
    mapa = folium.Map(location=[latitud_media, longitud_media], zoom_start=15)

    # Itera sobre cada coordenada y añade un marcador al mapa
    for indice, fila in df.iterrows():
        folium.Marker(
            location=[fila['latitud'], fila['longitud']],
            popup=f"Lat: {fila['latitud']}<br>Lon: {fila['longitud']}" # Texto que aparece al hacer clic
        ).add_to(mapa)

    # Guarda el mapa en un archivo HTML
    mapa.save(archivo_salida)
    
    print(f"¡Mapa interactivo generado! Abre el archivo '{archivo_salida}' en tu navegador.")

except FileNotFoundError:
    print(f"Error: No se pudo encontrar el archivo '{archivo_entrada}'.")
    print("Asegúrate de que el archivo y el script estén en la misma carpeta.")
except Exception as e:
    print(f"Ocurrió un error inesperado: {e}")