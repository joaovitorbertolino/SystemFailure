;==============================================================================
; chr_bg.inc - tiles do FUNDO (tabela de padrões 0, PPU $0000-$0FFF)
;==============================================================================
; Cada tile 8x8 ocupa 16 bytes: 8 bytes do PLANO 0 e 8 bytes do PLANO 1.
; Cor do pixel = (bit do plano 1) * 2 + (bit do plano 0)  ->  valores 0, 1, 2 ou 3.
; O bit mais significativo (esquerda do número binário) é o pixel mais a ESQUERDA.
; Tiles não listados abaixo ficam preenchidos com zero pelo linker (fill).

;------------------------------------------------------------------------------
; Tile $00 - vazio (céu)
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %00000000        ; linha 0   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 1   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 2   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 3   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 4   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 5   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 6   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 7   pixels: 0 0 0 0 0 0 0 0
; plano 1 = bit ALTO de cada pixel
    .byte %00000000        ; linha 0   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 1   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 2   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 3   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 4   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 5   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 6   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 7   pixels: 0 0 0 0 0 0 0 0

;------------------------------------------------------------------------------
; Tile $01 - tijolo
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %11111111        ; linha 0   pixels: 1 1 1 1 1 1 1 1
    .byte %10001100        ; linha 1   pixels: 3 2 2 2 1 3 2 2
    .byte %00001000        ; linha 2   pixels: 2 2 2 2 1 2 2 2
    .byte %00001000        ; linha 3   pixels: 2 2 2 2 1 2 2 2
    .byte %11111111        ; linha 4   pixels: 1 1 1 1 1 1 1 1
    .byte %11000000        ; linha 5   pixels: 1 3 2 2 2 2 2 2
    .byte %10000000        ; linha 6   pixels: 1 2 2 2 2 2 2 2
    .byte %10000000        ; linha 7   pixels: 1 2 2 2 2 2 2 2
; plano 1 = bit ALTO de cada pixel
    .byte %00000000        ; linha 0   pixels: 1 1 1 1 1 1 1 1
    .byte %11110111        ; linha 1   pixels: 3 2 2 2 1 3 2 2
    .byte %11110111        ; linha 2   pixels: 2 2 2 2 1 2 2 2
    .byte %11110111        ; linha 3   pixels: 2 2 2 2 1 2 2 2
    .byte %00000000        ; linha 4   pixels: 1 1 1 1 1 1 1 1
    .byte %01111111        ; linha 5   pixels: 1 3 2 2 2 2 2 2
    .byte %01111111        ; linha 6   pixels: 1 2 2 2 2 2 2 2
    .byte %01111111        ; linha 7   pixels: 1 2 2 2 2 2 2 2

;------------------------------------------------------------------------------
; Tile $02 - grama (topo do chão)
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %00000000        ; linha 0   pixels: 0 0 2 0 0 2 0 0
    .byte %00000000        ; linha 1   pixels: 0 2 2 0 2 2 2 0
    .byte %00000000        ; linha 2   pixels: 2 2 2 2 2 2 2 2
    .byte %10100101        ; linha 3   pixels: 1 2 1 2 2 1 2 1
    .byte %11111111        ; linha 4   pixels: 3 1 3 3 1 3 3 3
    .byte %11111111        ; linha 5   pixels: 3 3 3 3 3 1 3 3
    .byte %11111111        ; linha 6   pixels: 3 1 3 3 3 3 3 3
    .byte %11111111        ; linha 7   pixels: 3 3 3 3 1 3 3 3
; plano 1 = bit ALTO de cada pixel
    .byte %00100100        ; linha 0   pixels: 0 0 2 0 0 2 0 0
    .byte %01101110        ; linha 1   pixels: 0 2 2 0 2 2 2 0
    .byte %11111111        ; linha 2   pixels: 2 2 2 2 2 2 2 2
    .byte %01011010        ; linha 3   pixels: 1 2 1 2 2 1 2 1
    .byte %10110111        ; linha 4   pixels: 3 1 3 3 1 3 3 3
    .byte %11111011        ; linha 5   pixels: 3 3 3 3 3 1 3 3
    .byte %10111111        ; linha 6   pixels: 3 1 3 3 3 3 3 3
    .byte %11110111        ; linha 7   pixels: 3 3 3 3 1 3 3 3

;------------------------------------------------------------------------------
; Tile $03 - terra
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %11111111        ; linha 0   pixels: 3 3 1 3 3 3 3 3
    .byte %11111111        ; linha 1   pixels: 3 3 3 3 3 1 3 3
    .byte %11111111        ; linha 2   pixels: 1 3 3 3 3 3 3 3
    .byte %11111111        ; linha 3   pixels: 3 3 3 1 3 3 3 1
    .byte %11111111        ; linha 4   pixels: 3 3 3 3 3 3 3 3
    .byte %11111111        ; linha 5   pixels: 3 1 3 3 3 1 3 3
    .byte %11111111        ; linha 6   pixels: 3 3 3 3 3 3 3 3
    .byte %11111111        ; linha 7   pixels: 3 3 1 3 3 3 3 3
; plano 1 = bit ALTO de cada pixel
    .byte %11011111        ; linha 0   pixels: 3 3 1 3 3 3 3 3
    .byte %11111011        ; linha 1   pixels: 3 3 3 3 3 1 3 3
    .byte %01111111        ; linha 2   pixels: 1 3 3 3 3 3 3 3
    .byte %11101110        ; linha 3   pixels: 3 3 3 1 3 3 3 1
    .byte %11111111        ; linha 4   pixels: 3 3 3 3 3 3 3 3
    .byte %10111011        ; linha 5   pixels: 3 1 3 3 3 1 3 3
    .byte %11111111        ; linha 6   pixels: 3 3 3 3 3 3 3 3
    .byte %11011111        ; linha 7   pixels: 3 3 1 3 3 3 3 3

;------------------------------------------------------------------------------
; Tile $04 - nuvem - canto sup. esq.
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %00000000        ; linha 0   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 1   pixels: 0 0 0 0 0 0 0 0
    .byte %00000001        ; linha 2   pixels: 0 0 0 0 0 0 0 1
    .byte %00000011        ; linha 3   pixels: 0 0 0 0 0 0 1 1
    .byte %00000111        ; linha 4   pixels: 0 0 0 0 0 1 1 1
    .byte %00001111        ; linha 5   pixels: 0 0 0 0 1 1 1 1
    .byte %00111111        ; linha 6   pixels: 0 0 1 1 1 1 1 1
    .byte %00111111        ; linha 7   pixels: 0 0 1 1 1 1 1 1
; plano 1 = bit ALTO de cada pixel
    .byte %00000000        ; linha 0   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 1   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 2   pixels: 0 0 0 0 0 0 0 1
    .byte %00000000        ; linha 3   pixels: 0 0 0 0 0 0 1 1
    .byte %00000000        ; linha 4   pixels: 0 0 0 0 0 1 1 1
    .byte %00000000        ; linha 5   pixels: 0 0 0 0 1 1 1 1
    .byte %00000000        ; linha 6   pixels: 0 0 1 1 1 1 1 1
    .byte %00000000        ; linha 7   pixels: 0 0 1 1 1 1 1 1

;------------------------------------------------------------------------------
; Tile $05 - nuvem - canto sup. dir.
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %00000000        ; linha 0   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 1   pixels: 0 0 0 0 0 0 0 0
    .byte %11100000        ; linha 2   pixels: 1 1 1 0 0 0 0 0
    .byte %11110000        ; linha 3   pixels: 1 1 1 1 0 0 0 0
    .byte %11111000        ; linha 4   pixels: 1 1 1 1 1 0 0 0
    .byte %11111000        ; linha 5   pixels: 1 1 1 1 1 0 0 0
    .byte %11111110        ; linha 6   pixels: 1 1 1 1 1 1 1 0
    .byte %11111110        ; linha 7   pixels: 1 1 1 1 1 1 1 0
; plano 1 = bit ALTO de cada pixel
    .byte %00000000        ; linha 0   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 1   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 2   pixels: 1 1 1 0 0 0 0 0
    .byte %00000000        ; linha 3   pixels: 1 1 1 1 0 0 0 0
    .byte %00000000        ; linha 4   pixels: 1 1 1 1 1 0 0 0
    .byte %00000000        ; linha 5   pixels: 1 1 1 1 1 0 0 0
    .byte %00000000        ; linha 6   pixels: 1 1 1 1 1 1 1 0
    .byte %00000000        ; linha 7   pixels: 1 1 1 1 1 1 1 0

;------------------------------------------------------------------------------
; Tile $06 - nuvem - canto inf. esq.
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %01111111        ; linha 0   pixels: 0 1 1 1 1 1 1 1
    .byte %00111111        ; linha 1   pixels: 0 2 1 1 1 1 1 1
    .byte %00111111        ; linha 2   pixels: 0 0 1 1 1 1 1 1
    .byte %00000000        ; linha 3   pixels: 0 0 2 2 2 2 2 2
    .byte %00000000        ; linha 4   pixels: 0 0 0 0 2 2 0 0
    .byte %00000000        ; linha 5   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 6   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 7   pixels: 0 0 0 0 0 0 0 0
; plano 1 = bit ALTO de cada pixel
    .byte %00000000        ; linha 0   pixels: 0 1 1 1 1 1 1 1
    .byte %01000000        ; linha 1   pixels: 0 2 1 1 1 1 1 1
    .byte %00000000        ; linha 2   pixels: 0 0 1 1 1 1 1 1
    .byte %00111111        ; linha 3   pixels: 0 0 2 2 2 2 2 2
    .byte %00001100        ; linha 4   pixels: 0 0 0 0 2 2 0 0
    .byte %00000000        ; linha 5   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 6   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 7   pixels: 0 0 0 0 0 0 0 0

;------------------------------------------------------------------------------
; Tile $07 - nuvem - canto inf. dir.
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %11111111        ; linha 0   pixels: 1 1 1 1 1 1 1 1
    .byte %11111110        ; linha 1   pixels: 1 1 1 1 1 1 1 2
    .byte %11111110        ; linha 2   pixels: 1 1 1 1 1 1 1 0
    .byte %00000000        ; linha 3   pixels: 2 2 2 2 2 2 2 0
    .byte %00000000        ; linha 4   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 5   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 6   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 7   pixels: 0 0 0 0 0 0 0 0
; plano 1 = bit ALTO de cada pixel
    .byte %00000000        ; linha 0   pixels: 1 1 1 1 1 1 1 1
    .byte %00000001        ; linha 1   pixels: 1 1 1 1 1 1 1 2
    .byte %00000000        ; linha 2   pixels: 1 1 1 1 1 1 1 0
    .byte %11111110        ; linha 3   pixels: 2 2 2 2 2 2 2 0
    .byte %00000000        ; linha 4   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 5   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 6   pixels: 0 0 0 0 0 0 0 0
    .byte %00000000        ; linha 7   pixels: 0 0 0 0 0 0 0 0

;------------------------------------------------------------------------------
; Tile $08 - barras de cor (0,1,2,3) - teste de paleta
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %00110011        ; linha 0   pixels: 0 0 1 1 2 2 3 3
    .byte %00110011        ; linha 1   pixels: 0 0 1 1 2 2 3 3
    .byte %00110011        ; linha 2   pixels: 0 0 1 1 2 2 3 3
    .byte %00110011        ; linha 3   pixels: 0 0 1 1 2 2 3 3
    .byte %00110011        ; linha 4   pixels: 0 0 1 1 2 2 3 3
    .byte %00110011        ; linha 5   pixels: 0 0 1 1 2 2 3 3
    .byte %00110011        ; linha 6   pixels: 0 0 1 1 2 2 3 3
    .byte %00110011        ; linha 7   pixels: 0 0 1 1 2 2 3 3
; plano 1 = bit ALTO de cada pixel
    .byte %00001111        ; linha 0   pixels: 0 0 1 1 2 2 3 3
    .byte %00001111        ; linha 1   pixels: 0 0 1 1 2 2 3 3
    .byte %00001111        ; linha 2   pixels: 0 0 1 1 2 2 3 3
    .byte %00001111        ; linha 3   pixels: 0 0 1 1 2 2 3 3
    .byte %00001111        ; linha 4   pixels: 0 0 1 1 2 2 3 3
    .byte %00001111        ; linha 5   pixels: 0 0 1 1 2 2 3 3
    .byte %00001111        ; linha 6   pixels: 0 0 1 1 2 2 3 3
    .byte %00001111        ; linha 7   pixels: 0 0 1 1 2 2 3 3

;------------------------------------------------------------------------------
; Tile $09 - coração
;------------------------------------------------------------------------------
; plano 0 = bit BAIXO de cada pixel      (pixels desta linha)
    .byte %01100110        ; linha 0   pixels: 0 1 1 0 0 1 1 0
    .byte %10011001        ; linha 1   pixels: 1 2 2 1 1 2 2 1
    .byte %10100001        ; linha 2   pixels: 1 2 3 2 2 2 2 1
    .byte %10000001        ; linha 3   pixels: 1 2 2 2 2 2 2 1
    .byte %01000010        ; linha 4   pixels: 0 1 2 2 2 2 1 0
    .byte %00100100        ; linha 5   pixels: 0 0 1 2 2 1 0 0
    .byte %00011000        ; linha 6   pixels: 0 0 0 1 1 0 0 0
    .byte %00000000        ; linha 7   pixels: 0 0 0 0 0 0 0 0
; plano 1 = bit ALTO de cada pixel
    .byte %00000000        ; linha 0   pixels: 0 1 1 0 0 1 1 0
    .byte %01100110        ; linha 1   pixels: 1 2 2 1 1 2 2 1
    .byte %01111110        ; linha 2   pixels: 1 2 3 2 2 2 2 1
    .byte %01111110        ; linha 3   pixels: 1 2 2 2 2 2 2 1
    .byte %00111100        ; linha 4   pixels: 0 1 2 2 2 2 1 0
    .byte %00011000        ; linha 5   pixels: 0 0 1 2 2 1 0 0
    .byte %00000000        ; linha 6   pixels: 0 0 0 1 1 0 0 0
    .byte %00000000        ; linha 7   pixels: 0 0 0 0 0 0 0 0

