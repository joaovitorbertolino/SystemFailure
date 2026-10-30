;==============================================================================
; chr_spr.inc - tiles dos SPRITES (tabela de padrões 1, PPU $1000-$1FFF)
;==============================================================================
; Cada tile 8x8 ocupa 16 bytes: 8 bytes do PLANO 0 e 8 bytes do PLANO 1.
; Cor do pixel = (bit do plano 1) * 2 + (bit do plano 0)  ->  valores 0, 1, 2 ou 3.
; O bit mais significativo (esquerda do número binário) é o pixel mais a ESQUERDA.
; Tiles não listados abaixo ficam preenchidos com zero pelo linker (fill).

;------------------------------------------------------------------------------
; Tile $00 - herói - sup. esq.
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %00000111        ; linha 0   pixels: 0 0 0 0 0 1 1 1
    .byte %00011000        ; linha 1   pixels: 0 0 0 1 1 2 2 2
    .byte %00100000        ; linha 2   pixels: 0 0 1 2 2 2 2 2
    .byte %01000000        ; linha 3   pixels: 0 1 2 2 2 2 2 2
    .byte %01001110        ; linha 4   pixels: 0 1 2 2 3 3 3 2
    .byte %10001110        ; linha 5   pixels: 1 2 2 2 3 1 1 2
    .byte %10001110        ; linha 6   pixels: 1 2 2 2 3 1 1 2
    .byte %10001110        ; linha 7   pixels: 1 2 2 2 3 3 3 2
; plano 1 = bit ALTO de cada pixel
    .byte %00000000        ; linha 0   pixels: 0 0 0 0 0 1 1 1
    .byte %00000111        ; linha 1   pixels: 0 0 0 1 1 2 2 2
    .byte %00011111        ; linha 2   pixels: 0 0 1 2 2 2 2 2
    .byte %00111111        ; linha 3   pixels: 0 1 2 2 2 2 2 2
    .byte %00111111        ; linha 4   pixels: 0 1 2 2 3 3 3 2
    .byte %01111001        ; linha 5   pixels: 1 2 2 2 3 1 1 2
    .byte %01111001        ; linha 6   pixels: 1 2 2 2 3 1 1 2
    .byte %01111111        ; linha 7   pixels: 1 2 2 2 3 3 3 2

;------------------------------------------------------------------------------
; Tile $01 - herói - sup. dir.
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %11100000        ; linha 0   pixels: 1 1 1 0 0 0 0 0
    .byte %00011000        ; linha 1   pixels: 2 2 2 1 1 0 0 0
    .byte %00000100        ; linha 2   pixels: 2 2 2 2 2 1 0 0
    .byte %00000010        ; linha 3   pixels: 2 2 2 2 2 2 1 0
    .byte %01110010        ; linha 4   pixels: 2 3 3 3 2 2 1 0
    .byte %01110001        ; linha 5   pixels: 2 1 1 3 2 2 2 1
    .byte %01110001        ; linha 6   pixels: 2 1 1 3 2 2 2 1
    .byte %01110001        ; linha 7   pixels: 2 3 3 3 2 2 2 1
; plano 1 = bit ALTO de cada pixel
    .byte %00000000        ; linha 0   pixels: 1 1 1 0 0 0 0 0
    .byte %11100000        ; linha 1   pixels: 2 2 2 1 1 0 0 0
    .byte %11111000        ; linha 2   pixels: 2 2 2 2 2 1 0 0
    .byte %11111100        ; linha 3   pixels: 2 2 2 2 2 2 1 0
    .byte %11111100        ; linha 4   pixels: 2 3 3 3 2 2 1 0
    .byte %10011110        ; linha 5   pixels: 2 1 1 3 2 2 2 1
    .byte %10011110        ; linha 6   pixels: 2 1 1 3 2 2 2 1
    .byte %11111110        ; linha 7   pixels: 2 3 3 3 2 2 2 1

;------------------------------------------------------------------------------
; Tile $02 - herói - inf. esq.
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %10000000        ; linha 0   pixels: 1 2 2 2 2 2 2 2
    .byte %10000000        ; linha 1   pixels: 1 2 2 2 2 2 2 2
    .byte %10100000        ; linha 2   pixels: 1 2 1 2 2 2 2 2
    .byte %10011111        ; linha 3   pixels: 1 2 2 1 1 1 1 1
    .byte %01000000        ; linha 4   pixels: 0 1 2 2 2 2 2 2
    .byte %00100000        ; linha 5   pixels: 0 0 1 2 2 2 2 2
    .byte %00111111        ; linha 6   pixels: 0 0 1 3 3 3 1 1
    .byte %00011100        ; linha 7   pixels: 0 0 0 1 1 1 0 0
; plano 1 = bit ALTO de cada pixel
    .byte %01111111        ; linha 0   pixels: 1 2 2 2 2 2 2 2
    .byte %01111111        ; linha 1   pixels: 1 2 2 2 2 2 2 2
    .byte %01011111        ; linha 2   pixels: 1 2 1 2 2 2 2 2
    .byte %01100000        ; linha 3   pixels: 1 2 2 1 1 1 1 1
    .byte %00111111        ; linha 4   pixels: 0 1 2 2 2 2 2 2
    .byte %00011111        ; linha 5   pixels: 0 0 1 2 2 2 2 2
    .byte %00011100        ; linha 6   pixels: 0 0 1 3 3 3 1 1
    .byte %00000000        ; linha 7   pixels: 0 0 0 1 1 1 0 0

;------------------------------------------------------------------------------
; Tile $03 - herói - inf. dir.
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %00000001        ; linha 0   pixels: 2 2 2 2 2 2 2 1
    .byte %00000001        ; linha 1   pixels: 2 2 2 2 2 2 2 1
    .byte %00000101        ; linha 2   pixels: 2 2 2 2 2 1 2 1
    .byte %11111001        ; linha 3   pixels: 1 1 1 1 1 2 2 1
    .byte %00000010        ; linha 4   pixels: 2 2 2 2 2 2 1 0
    .byte %00000100        ; linha 5   pixels: 2 2 2 2 2 1 0 0
    .byte %11111100        ; linha 6   pixels: 1 1 3 3 3 1 0 0
    .byte %00111000        ; linha 7   pixels: 0 0 1 1 1 0 0 0
; plano 1 = bit ALTO de cada pixel
    .byte %11111110        ; linha 0   pixels: 2 2 2 2 2 2 2 1
    .byte %11111110        ; linha 1   pixels: 2 2 2 2 2 2 2 1
    .byte %11111010        ; linha 2   pixels: 2 2 2 2 2 1 2 1
    .byte %00000110        ; linha 3   pixels: 1 1 1 1 1 2 2 1
    .byte %11111100        ; linha 4   pixels: 2 2 2 2 2 2 1 0
    .byte %11111000        ; linha 5   pixels: 2 2 2 2 2 1 0 0
    .byte %00111000        ; linha 6   pixels: 1 1 3 3 3 1 0 0
    .byte %00000000        ; linha 7   pixels: 0 0 1 1 1 0 0 0

