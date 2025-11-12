import os
from pathlib import Path

def guardar_contenido_archivos(directorio, archivo_salida="contenido_archivos.txt"):
    """
    Lee el contenido de todos los archivos en un directorio y lo guarda en un archivo TXT,
    identificando cada uno con su nombre.
    
    Args:
        directorio (str): Ruta del directorio a escanear.
        archivo_salida (str): Nombre del archivo de salida.
    """
    try:
        directorio_path = Path(directorio)
        
        if not directorio_path.exists():
            print(f"El directorio '{directorio}' no existe.")
            return
            
        if not directorio_path.is_dir():
            print(f"'{directorio}' no es un directorio válido.")
            return
        
        with open(archivo_salida, 'w', encoding='utf-8') as f_out:
            # Recorrer todos los archivos
            for archivo in directorio_path.rglob('*'):
                if archivo.is_file():
                    try:
                        # Escribir separador con nombre del archivo
                        f_out.write(f"\n\n{'='*50}\n")
                        f_out.write(f"ARCHIVO: {archivo.relative_to(directorio_path)}\n")
                        f_out.write(f"{'='*50}\n\n")
                        
                        # Leer y escribir contenido
                        with open(archivo, 'r', encoding='utf-8', errors='ignore') as f_in:
                            contenido = f_in.read()
                            f_out.write(contenido)
                            
                    except UnicodeDecodeError:
                        f_out.write("\n[El archivo no es de texto legible]\n")
                    except Exception as e:
                        f_out.write(f"\n[Error al leer el archivo: {str(e)}]\n")
        
        print(f"Contenido de archivos guardado en '{archivo_salida}'")
    
    except Exception as e:
        print(f"Ocurrió un error general: {e}")

if __name__ == "__main__":
    # Solicitar directorio al usuario
    directorio_input = input("Ingrese la ruta del directorio a escanear: ")
    
    # Llamar a la función
    guardar_contenido_archivos(directorio_input)