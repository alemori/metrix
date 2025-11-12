import pandas as pd
import folium

# Nombre del archivo de entrada que contiene las coordenadas
archivo_entrada = 'coordenadas.csv'

# Nombre del archivo de salida del mapa
archivo_salida = 'mapa_satelital.html'

try:
    # Lee el archivo CSV. Asumimos que las columnas son: latitud, longitud
    df = pd.read_csv(archivo_entrada, header=None, names=['latitud', 'longitud'])

    # Calcula el punto central del mapa
    latitud_media = df['latitud'].mean()
    longitud_media = df['longitud'].mean()

    # Crea el objeto de mapa, centrado en el punto medio
    mapa = folium.Map(location=[latitud_media, longitud_media], zoom_start=15)

    # --- INICIO DE LA MODIFICACIÓN ---

    # Añade la capa de mapa satelital de Esri (una alternativa popular a Google Maps)
    folium.TileLayer(
        tiles='https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        attr='Tiles &copy; Esri &mdash; Source: Esri, i-cubed, USDA, USGS, AEX, GeoEye, Getmapping, Aerogrid, IGN, IGP, UPR-EGP, and the GIS User Community',
        name='Vista Satelital'
    ).add_to(mapa)

    # Añade un control de capas para poder cambiar entre el mapa base y el satelital
    folium.LayerControl().add_to(mapa)

    # --- FIN DE LA MODIFICACIÓN ---

    # Itera sobre cada coordenada y añade un marcador al mapa
    for indice, fila in df.iterrows():
        folium.Marker(
            location=[fila['latitud'], fila['longitud']],
            popup=f"Lat: {fila['latitud']}<br>Lon: {fila['longitud']}"
        ).add_to(mapa)

    # Guarda el mapa en un archivo HTML
    mapa.save(archivo_salida)
    
    print(f"¡Mapa satelital generado! Abre el archivo '{archivo_salida}' en tu navegador.")

except FileNotFoundError:
    print(f"Error: No se pudo encontrar el archivo '{archivo_entrada}'.")
except Exception as e:
    print(f"Ocurrió un error inesperado: {e}")