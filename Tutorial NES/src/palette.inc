; Paletas: 32 bytes copiados para a RAM de paletas da PPU ($3F00-$3F1F).
; Cada paleta tem 4 cores; a cor 0 de CADA paleta de fundo é a cor de fundo universal.
; ATENÇÃO: $3F10 é espelho de $3F00 -> o byte 16 deve ser IGUAL ao byte 0 ($21).
palette_data:
    ; ---- 4 paletas de FUNDO ($3F00-$3F0F) ----
    .byte $21,$30,$31,$11     ; fundo 0: céu/nuvem: branco, azul pálido, azul
    .byte $21,$1A,$2A,$17     ; fundo 1: grama/terra: verde escuro, verde claro, marrom
    .byte $21,$17,$27,$37     ; fundo 2: tijolo: marrom, laranja, creme
    .byte $21,$16,$26,$36     ; fundo 3: vermelhos (coração): vermelho escuro, vermelho, rosa
    ; ---- 4 paletas de SPRITE ($3F10-$3F1F) ----
    .byte $21,$0F,$16,$30     ; sprite 0: herói: preto (contorno), vermelho, branco
    .byte $21,$0F,$1A,$30     ; sprite 1: variante verde
    .byte $21,$0F,$12,$30     ; sprite 2: variante azul
    .byte $21,$0F,$28,$30     ; sprite 3: variante amarela
