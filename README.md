# Dragon_UI

Adaptación de [DragonUI](https://github.com/NeticSoul/DragonUI) para World of Warcraft 3.3.5a. Conserva los créditos y las licencias del proyecto original.

## Instalación

Copia `DragonUI` y `DragonUI_Options` a `World of Warcraft/Interface/AddOns/`. Si también quieres previsualizar monturas sin aprenderlas en el diario de DragonUI, copia `MountPreview` al mismo directorio. Reinicia WoW después de instalar.

- `/dragonui` abre las opciones. En **Barras de Acción → General → Distribución de barras** puedes elegir **Clásica** o **Moderna**. Ambos modos usan el arte de DragonUI. Clásica guarda sus posiciones de barras por separado en el editor y viene con los grifos ocultos.
- `/duiedit` abre el editor de posiciones.
- `/monturas` abre el diario de DragonUI si el módulo Colecciones está activo. MountPreview incluye un catálogo base para la vista previa.

## Catálogo de monturas del reino

Con Node.js 20 o superior, puedes generar un catálogo de reino a partir de `Spell.dbc` y sincronizarlo desde un JSON servido por HTTPS. Ejecuta `node tools/catalog.mjs` para ver el uso básico. El addon lee el catálogo Lua local al iniciar o al ejecutar `/reload`. Las monturas custom requieren los modelos y las texturas en el cliente. Cuando el cliente carga solo el modelo base, la textura puede variar.

## Licencias

El código de DragonUI se distribuye bajo la licencia MIT. El arte y los datos del juego, las fuentes y las bibliotecas de terceros conservan sus licencias y atribuciones. Consulta [los avisos de terceros](DragonUI/THIRD_PARTY_NOTICES.md).
