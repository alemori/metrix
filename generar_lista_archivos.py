import os
from pathlib import Path

def generar_lista_archivos(directorio, archivo_salida="lista_archivos.txt"):
    """
    Genera un archivo de texto con la lista de archivos en un directorio y sus subdirectorios.
    
    Args:
        directorio (str): Ruta del directorio a escanear.
        archivo_salida (str): Nombre del archivo de salida (por defecto: lista_archivos.txt).
    """
    try:
        # Convertir a Path object para manejo más fácil
        directorio_path = Path(directorio)
        
        # Verificar si el directorio existe
        if not directorio_path.exists():
            print(f"El directorio '{directorio}' no existe.")
            return
        
        # Verificar si es un directorio
        if not directorio_path.is_dir():
            print(f"'{directorio}' no es un directorio válido.")
            return
        
        # Abrir archivo para escritura
        with open(archivo_salida, 'w', encoding='utf-8') as f:
            # Recorrer todos los archivos en el directorio y subdirectorios
            for archivo in directorio_path.rglob('*'):
                if archivo.is_file():
                    # Escribir la ruta relativa del archivo
                    f.write(f"{archivo.relative_to(directorio_path)}\n")
        
        print(f"Lista de archivos generada correctamente en '{archivo_salida}'")
    
    except Exception as e:
        print(f"Ocurrió un error: {e}")

if __name__ == "__main__":
    # Solicitar directorio al usuario
    directorio_input = input("Ingrese la ruta del directorio a escanear: ")
    
    # Llamar a la función
    generar_lista_archivos(directorio_input)