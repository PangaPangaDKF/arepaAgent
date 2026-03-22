# DESIGN SYSTEM — ArepaPay
> Referencia de diseño actualizada. Leer siempre antes de construir o editar componentes.
> Estilo actual: Pixel RPG venezolano — azul marino + dorado + crema. NO verde, NO pergamino naranja.
> Ultima actualizacion: Marzo 2026

---

## PALETA DE COLORES REAL (lo que esta en produccion)

### Fondos
```
CREAM:        #FFF8E0   <- fondo principal de TODA la app (pantallas, contenido)
WHITE_CARD:   #FFFFFF   <- interior de tarjetas y modales sobre el fondo crema
```

### Marca principal — AZUL MARINO
```
NAVY:         #1A2472   <- azul marino — color de marca (header, botones primarios)
NAVY_DARK:    #0D1040   <- azul mas oscuro — bordes y sombras navy
NAVY_DEEPER:  #111855   <- fondo de gradiente en botones azul oscuro
```

### Cafe / Marron
```
BROWN_DARK:   #2C1A0E   <- cafe oscuro — bottom nav, bordes importantes
BROWN_MID:    #5A4A30   <- cafe medio — texto secundario en fondos claros
BROWN_LIGHT:  #8A6A40   <- cafe claro — labels, subtextos
```

### Dorado / Amber (bordes y acentos de tarjetas)
```
GOLD:         #D4B87A   <- dorado principal — bordes de tarjetas, tabs activos
GOLD_BORDER:  #C89038   <- dorado oscuro — borde y sombra de cards
GOLD_AMBER:   #D4921C   <- ambar — iconos de conversion Bs/USDT, acciones de cambio
```

### Rojo
```
RED:          #CC1111   <- rojo principal — errores, alertas, bandera VE, botones destructivos
RED_DARK:     #770000   <- sombra del boton rojo
RED_BRIGHT:   #E02222   <- highlight superior boton rojo
```

### Azules complementarios
```
BLUE_INFO:    #4A9EFF   <- links, estados informativos, TX hash
BLUE_SUBTLE:  #8899CC   <- texto de apoyo sutil (gas, red)
```

---

## BOTONES — PixelButton (unico componente de boton)

Todos los botones: borderRadius 24px (pill), Inter bold 16px, width 100%, efecto press translateY(3px) + reduccion de sombra.

### blue — boton primario (mayoria de acciones)
```
background:  linear-gradient(180deg, #2A3A9E 0%, #1A2472 45%, #111855 100%)
border:      3px solid #0D1040
color:       #FFFFFF
boxShadow:   0 5px 0 #0D1040
pressed:     translateY(3px) + boxShadow 0 2px 0 #0D1040
```
Usos: Conectar wallet, Confirmar pago, Entrar rifa, cualquier accion principal.

### red / orange — accion destructiva o secundaria
```
background:  linear-gradient(180deg, #E02222 0%, #CC1111 45%, #991111 100%)
border:      3px solid #770000
color:       #FFFFFF
boxShadow:   0 5px 0 #770000
```
Nota: "orange" y "red" son identicos — no existe boton verde en produccion.

### ghost — sin relleno
```
background:  #FFFFFF
border:      3px solid #1A2472
color:       #1A2472
boxShadow:   0 5px 0 #1A2472
```
Usos: Cancelar, acciones alternativas.

### dark — navy mas oscuro
```
background:  linear-gradient(180deg, #1A2472 0%, #0D1040 100%)
border:      3px solid #0D1040
color:       #FFFFFF
boxShadow:   0 5px 0 #050820
```

---

## TARJETAS Y PANELES

### Card estandar (el mas comun)
```
background:    #FFFFFF
border:        4px solid #C89038
borderRadius:  12-16px
boxShadow:     6px 6px 0px #C89038
padding:       16-24px
```

### Panel de balance / info
```
background:    #FFF8E0
border:        3px solid #C89038
borderRadius:  12px
boxShadow:     4px 4px 0px #C89038
```

### Header de pantalla (siempre azul marino)
```
background:    #1A2472
borderBottom:  3px solid #0D1040
padding:       12px 16px
color:         #FFFFFF
```
IMPORTANTE: El header es AZUL (#1A2472), NO cafe. El cafe (#2C1A0E) es solo para el bottom nav.

### Patron de cuadros (decorativo — login y algunas cards)
Franja de 14px con cuadros rojos y crema. Se usa arriba y abajo de la card de login.
```
colores:   #CC1111 (rojo) sobre #FFF8E0 (crema)
size:      12px x 12px
height:    14px
```

---

## TIPOGRAFIA

```
Fuente unica:  Inter, sans-serif

Titulo H1:     fontSize 34px, fontWeight 900, letterSpacing 4px, uppercase
               color #1A2472 (sobre fondos claros) o #FFFFFF (sobre fondos oscuros)

Titulo H2:     fontSize 22-28px, fontWeight 900
               color #1A2472 o #FFFFFF segun fondo

Subtitulo:     fontSize 11-13px, fontWeight 700-900, uppercase, letterSpacing 2-3px
               color #CC1111 (acento rojo) o #D4B87A (acento dorado)

Balance:       fontSize 32-38px, fontWeight 900
               color #2C1A0E (sobre crema) o #FFFFFF (sobre oscuro)

Label:         fontSize 10-11px, fontWeight 700, uppercase, letterSpacing 1-2px

Body:          fontSize 12-14px, lineHeight 1.4-1.6, color #5A4A30

Subtext:       fontSize 10-11px, color #8899CC o #8A6A40

Monospace:     font-family monospace (solo addresses 0x..., TX hashes)
```

---

## BOTTOM NAV

```
background:    #2C1A0E  (cafe oscuro — NO azul)
borderTop:     3px solid #C89038
height:        aprox 64px
position:      fixed, bottom 0
display:       flex, justifyContent space-around
padding:       8px 0

Tab activo:    color #D4B87A (dorado)
Tab inactivo:  color #8A6A40 (cafe claro)
```

---

## PANTALLA DE LOGIN (App.jsx)

Estructura especifica:
- Fondo: #FFF8E0
- Card central con borde 4px solid #C89038 y sombra 6px 6px 0px #C89038
- Franja patron cuadros arriba (14px rojo/crema)
- Logo arepa SVG circular (96x96px, borde dorado, fondo crema)
- Titulo AREPAPAY en #1A2472, 34px, letterSpacing 4px
- Subtitulo "La arepa es venezolana" en #CC1111
- PixelButton variant="blue" para conectar wallet
- Link naranja MetaMask (#F6851B, borde #C96000) — solo visible en mobile
- Franja patron cuadros abajo (14px rojo/crema)

---

## LAYOUT GENERAL

```
maxWidth:     420px
margin:       0 auto
background:   #FFF8E0 (toda la app, no hay negro ni gris oscuro en el fondo)
fontFamily:   Inter, sans-serif

Estructura vertical:
+-----------------------------+
|  HEADER azul #1A2472        |  sticky top
+-----------------------------+
|                             |
|  CONTENIDO crema #FFF8E0    |  scrollable
|  cards con borde dorado     |
|                             |
+-----------------------------+
|  BOTTOM NAV cafe #2C1A0E    |  fixed bottom
+-----------------------------+
```

---

## LO QUE YA NO SE USA (no incluir en nuevos componentes)

- Fondo pergamino #F5E8C0 o #F0DCA0 — reemplazado por #FFF8E0
- Botones verdes (#78C040) — eliminados, todo es azul navy o rojo
- Borde cafe #2C1A0E en tarjetas — reemplazado por dorado #C89038
- Fondo naranja (#D4842A) en paneles — no se usa en produccion
- BorderRadius pill en tarjetas — las cards usan 12-16px, solo botones usan 24px

---

## CHECKLIST ANTES DE HACER UN COMPONENTE

- Fondo de la pagina es #FFF8E0?
- Botones usan PixelButton con variant blue/red/ghost/dark (no verde)?
- Cards tienen border 4px solid #C89038 y boxShadow 6px 6px 0px #C89038?
- Header usa #1A2472 (azul marino)?
- Bottom nav usa #2C1A0E (cafe oscuro)?
- Texto sobre fondos oscuros usa #FFFFFF o #FFF8E0?
- Funciona en 375px (iPhone SE)?
- Los numeros de balance no rompen el layout?
