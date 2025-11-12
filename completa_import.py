import pandas as pd

# Leer el archivo original
df = pd.read_csv("coordenadas.csv")

# Si tu archivo tiene solo 'latitud' y 'longitud', asegúrate que se llamen así
df.columns = ['Latitude', 'Longitude']

# Agregar columnas que My Maps necesita
df['Name'] = [f"Punto {i+1}" for i in range(len(df))]
df['Description'] = "Parte del recorrido"
df['Category'] = "Ruta"

# Ordenar columnas como espera My Maps
df = df[['Name', 'Description', 'Category', 'Latitude', 'Longitude']]

# Guardar el archivo listo para importar
df.to_csv("coordenadas_mymaps.csv", index=False, encoding='utf-8')

print("Archivo 'coordenadas_mymaps.csv' generado correctamente.")
