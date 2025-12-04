# MealMaker

Aplicación móvil de recetas que combina una base de datos local con TheMealDB API para búsqueda inteligente de recetas.

## Características

- **Búsqueda inteligente**: Encuentra recetas por ingredientes usando procesamiento de lenguaje natural
- **Fuentes híbridas**: Combina 50 recetas locales + miles de recetas de TheMealDB API
- **Visuales atractivos**: Fotos reales para recetas API, gradientes de colores para recetas locales
- **Favoritos**: Guarda tus recetas preferidas para acceso rápido
- **Indicadores visuales**: Bordes de color distinguen recetas API (azul) de locales (verde)

## Tecnologías

- **Flutter/Dart**: Framework UI multiplataforma
- **SQLite**: Base de datos local para almacenamiento de recetas
- **TheMealDB API**: Integración con API externa de recetas
- **HTTP**: Peticiones a API REST

## Instalación

```bash
# Clonar repositorio
git clone <repository-url>
cd mealmaker

# Instalar dependencias
flutter pub get

# Ejecutar aplicación
flutter run
```

## Estructura del Proyecto

```
lib/
├── main.dart                    # Punto de entrada y UI principal
├── data/
│   ├── models/                  # Modelo Recipe
│   ├── database/                # Configuración SQLite
│   ├── repositories/            # 50 recetas iniciales
│   └── services/                # API y búsqueda
```

## Uso

1. **Buscar recetas**: Ingresa ingredientes en el buscador (ej: "chicken pasta")
2. **Ver resultados**: Recetas locales (borde verde) y API (borde azul)
3. **Ver detalles**: Tap en "Cook" para ver instrucciones completas
4. **Favoritos**: Guarda recetas tocando el ícono de corazón
5. **Ver todas**: Navega a "All Recipes" desde el home

## API

Integración con [TheMealDB](https://www.themealdb.com/api.php) para búsqueda extendida de recetas.

---

Desarrollado con Flutter
