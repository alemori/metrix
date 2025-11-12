import matplotlib.pyplot as plt

def leer_coordenadas_de_archivo(nombre_archivo):
    """
    Lee un archivo de texto con coordenadas (formato x,y).

    Args:
      nombre_archivo (str): La ruta al archivo .txt.

    Returns:
      list: Una lista de tuplas de coordenadas [(x1, y1), (x2, y2), ...].
    """
    coordenadas = []
    try:
        with open(nombre_archivo, 'r') as archivo:
            for linea in archivo:
                # Quitamos espacios en blanco o saltos de línea
                linea = linea.strip()
                if linea:  # Ignora líneas vacías
                    # Dividimos la línea por la coma
                    partes = linea.split(',')
                    if len(partes) == 2:
                        # Convertimos las partes a números y las guardamos
                        x = float(partes[0].strip())
                        y = float(partes[1].strip())
                        coordenadas.append((x, y))
    except FileNotFoundError:
        print(f"Error: No se encontró el archivo '{nombre_archivo}'.")
        print("Asegúrate de que el archivo esté en la misma carpeta que el script.")
        return None
    except Exception as e:
        print(f"Ocurrió un error al procesar el archivo: {e}")
        return None
    
    return coordenadas

def graficar_dispersion(coordenadas, nombre_archivo_salida='dispersion_final.png'):
    """
    Genera y guarda un gráfico de dispersión a partir de una lista de coordenadas.
    """
    if not coordenadas:
        print("La lista de coordenadas está vacía o no se pudo leer. No se generará el gráfico.")
        return

    # Separa las coordenadas en listas de 'x' e 'y'
    x_vals = [coord[0] for coord in coordenadas]
    y_vals = [coord[1] for coord in coordenadas]

    # Crea el gráfico
    plt.figure(figsize=(10, 8)) # Opcional: ajusta el tamaño del gráfico
    plt.scatter(x_vals, y_vals, alpha=0.7, edgecolors='b', s=80)
    
    # Añade títulos y etiquetas
    plt.title('Dispersión de Coordenadas del Archivo')
    plt.xlabel('Eje X')
    plt.ylabel('Eje Y')
    plt.grid(True)
    
    # Guarda el gráfico en un archivo
    plt.savefig(nombre_archivo_salida)
    print(f"¡Éxito! Gráfico guardado como '{nombre_archivo_salida}'")

# --- INICIO DEL PROGRAMA ---

# 1. Nombre de tu archivo de entrada
archivo_de_coordenadas = 'coordenadas.txt'

# 2. Llama a la función para leer las coordenadas
lista_de_coordenadas = leer_coordenadas_de_archivo(archivo_de_coordenadas)

# 3. Si la lectura fue exitosa, genera el gráfico
if lista_de_coordenadas:
    graficar_dispersion(lista_de_coordenadas)