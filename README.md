# Dragon_UI

Adaptación de [DragonUI](https://github.com/NeticSoul/DragonUI) para World of Warcraft 3.3.5a. Conserva los créditos y las licencias del proyecto original.

## Instalación

Copia `DragonUI` y `DragonUI_Options` a `World of Warcraft/Interface/AddOns/`. Reinicia WoW después de instalar. El visor de monturas está integrado en DragonUI.

- `/dragonui` abre las opciones. En **Barras de Acción → General → Distribución de barras** puedes elegir **Clásica** o **Moderna**. Ambos modos usan el arte de DragonUI. Clásica guarda sus posiciones de barras por separado en el editor y viene con los grifos ocultos.
- `/duiedit` abre el editor de posiciones.
- `/monturas` abre el diario de DragonUI si el módulo Colecciones está activo. DragonUI incluye un catálogo base para la vista previa de monturas sin aprender.

## Catálogo de monturas del reino

Con Node.js 20 o superior, usa `DragonUI/tools/catalog.mjs` para generar un catálogo a partir de `Spell.dbc` y sincronizar un JSON servido por HTTPS. Ejecuta el comando desde la carpeta que contiene el addon `DragonUI`.

```sh
node DragonUI/tools/catalog.mjs sync --url https://tu-reino.example/mounts.json --addon DragonUI
```

El comando actualiza `DragonUI/modules/collections/RealmCatalog.lua`. DragonUI valida los datos al cargarlos y usa el catálogo local al iniciar o al ejecutar `/reload`. Las monturas custom requieren los modelos y las texturas en el cliente. Cuando el cliente carga solo el modelo base, la textura puede variar.

## Licencias

El código de DragonUI se distribuye bajo la licencia MIT. El arte y los datos del juego, las fuentes y las bibliotecas de terceros conservan sus licencias y atribuciones. Consulta [los avisos de terceros](DragonUI/THIRD_PARTY_NOTICES.md).
