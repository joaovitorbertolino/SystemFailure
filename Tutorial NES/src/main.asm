; ==============================================================================
;  main.asm  -  "Hello CHR": seu primeiro programa gráfico para o NES (6502 / ca65)
;
;  O que ele faz:
;    1. Inicializa o NES (reset) e espera a PPU "esquentar" (2 vblanks)
;    2. Copia 32 bytes de PALETA para a PPU
;    3. Copia a NAMETABLE (o "mapa" de 32x30 tiles + atributos) para a PPU
;    4. Monta um herói de 4 sprites (16x16) e o move de um lado para o outro
;    5. Liga a PPU e, a cada quadro (NMI), copia a OAM por DMA
;
;  COMO LER OS COMENTÁRIOS (toda linha de código tem um):
;     A <- valor     o acumulador RECEBE o valor            (X <- , Y <-  idem)
;     [endereço] <- A  a MEMÓRIA nesse endereço recebe o conteúdo de A
;     "A, X, Y intactos" = nenhum desses registradores muda nesta instrução
;     Z, N, C = flags (zero, negativo, carry) do registrador de status P
;
;  REGRAS DO PROJETO:
;     - Sem SED/CLD: o 2A03 do NES não tem modo decimal (ADC/SBC são sempre binários).
;     - Variáveis na ZERO PAGE ($00-$FF): acesso de 2 bytes e 3 ciclos (absoluto: 3 bytes, 4).
;     - IMPORTANTE: declare as variáveis da Zero Page ANTES de usá-las no código. Se o
;       assembler vir o nome pela primeira vez DEPOIS, ele assume endereço absoluto.
; ==============================================================================

.include "nes.inc"                      ; traz PPUCTRL, PPUMASK, PPUADDR... (só constantes: não gera bytes)

; ------------------------------------------------------------------------------
;  Constantes do programa (também não geram bytes; são substituídas pelo assembler)
; ------------------------------------------------------------------------------
HERO_X_START = 16                       ; posição X inicial do herói (pixels)
HERO_Y_START = 191                      ; valor de Y na OAM; o sprite aparece na linha 191+1 = 192
HERO_X_MAX   = 240                      ; limite direito: 256 - 16 pixels de largura do herói
HERO_SPRITES = 4                        ; o herói 16x16 usa 4 sprites 8x8

; ==============================================================================
;  CABEÇALHO iNES - 16 bytes no INÍCIO do arquivo .nes (o emulador lê, o NES real não)
; ==============================================================================
.segment "HEADER"                       ; troca para o segmento HEADER (ver nes.cfg)
    .byte "NES", $1A                    ; bytes 0-3: assinatura "NES" + $1A (marca do formato iNES)
    .byte 2                             ; byte 4: tamanho da PRG-ROM em blocos de 16 KB (2 = 32 KB)
    .byte 1                             ; byte 5: tamanho da CHR-ROM em blocos de 8 KB (1 = 8 KB)
    .byte %00000001                     ; byte 6: bit 0 = 1 espelhamento vertical; bits 4-7 = mapper (baixo)
    .byte %00000000                     ; byte 7: bits 4-7 = mapper (alto)  ->  mapper 0 (NROM)
    .byte 0,0,0,0,0,0,0,0               ; bytes 8-15: não usados, zerados

; ==============================================================================
;  ZERO PAGE - variáveis rápidas ($0000-$00FF). Declaradas AQUI, antes do código.
;  (.res N reserva N bytes sem dar valor; o valor inicial é zero porque limpamos a RAM)
; ==============================================================================
.segment "ZEROPAGE"                     ; tudo abaixo vai para a Zero Page
ptr:        .res 2                      ; $00-$01: ponteiro de 16 bits (ptr = byte baixo, ptr+1 = byte alto)
nmi_ready:  .res 1                      ; $02: vira 1 a cada NMI; o laço principal zera depois de tratar
hero_x:     .res 1                      ; $03: posição X (0-255) do canto superior esquerdo do herói
hero_y:     .res 1                      ; $04: posição Y (valor da OAM) do herói
hero_dir:   .res 1                      ; $05: direção: 0 = andando para a direita, 1 = para a esquerda

; ==============================================================================
;  OAM "SOMBRA" - 256 bytes em $0200. A cada quadro o DMA copia esta página para a PPU.
;  Cada sprite ocupa 4 bytes:  [0] Y   [1] número do tile   [2] atributos   [3] X
;  (não cabe na Zero Page: o DMA exige uma página inteira, e a Zero Page é preciosa)
; ==============================================================================
.segment "OAM"                          ; segmento mapeado em $0200 (ver nes.cfg)
oam_buf:    .res 256                    ; 64 sprites x 4 bytes

; ==============================================================================
;  CÓDIGO
; ==============================================================================
.segment "CODE"                         ; o código fica na PRG-ROM ($8000-$FFFF)

; ------------------------------------------------------------------------------
;  reset - a CPU salta para cá quando o NES liga ou o botão RESET é apertado
;  Estado na entrada: A, X, Y e a RAM têm valores INDEFINIDOS. Não confie em nada!
; ------------------------------------------------------------------------------
reset:
    sei                                 ; I <- 1: ignora IRQs (não usamos). A, X, Y intactos (ainda indefinidos)
    ldx #$40                            ; X <- $40 (%01000000). A, Y intactos
    stx APU_FRAME                       ; [$4017] <- X ($40): bit 6 = 1 desliga o IRQ do APU. A, X, Y intactos
    ldx #$FF                            ; X <- $FF (topo da pilha). A, Y intactos
    txs                                 ; SP <- X ($FF): pilha vazia (primeiro push vai em $01FF). A, X, Y intactos
    inx                                 ; X <- X + 1 = $00 ($FF "dá a volta" para 0). Z=1. A, Y intactos
    stx PPUCTRL                         ; [$2000] <- X (0): NMI desligado por enquanto. A, X, Y intactos
    stx PPUMASK                         ; [$2001] <- X (0): fundo e sprites desligados. A, X, Y intactos
    stx DMC_FREQ                        ; [$4010] <- X (0): sem IRQ do canal DMC. A, X, Y intactos

@wait_vblank1:                          ; rótulo local (@): vale só dentro do bloco "reset"
    bit PPUSTATUS                       ; N <- bit 7 de [$2002] (1 = PPU em vblank); ler zera esse bit. A, X, Y intactos
    bpl @wait_vblank1                   ; N=0 (ainda não é vblank)? volta e testa de novo. A, X, Y intactos

@clear_ram:                             ; limpa os 2 KB de RAM; X vai de 0 a 255 (X = 0 vindo do INX acima)
    lda #$00                            ; A <- $00 (valor de limpeza). X é o índice do laço; Y intacto
    sta $00,x                           ; [$00+X] <- A: zera a Zero Page (modo zp,X = 2 bytes, 4 ciclos). A, X, Y intactos
    sta $0100,x                         ; [$0100+X] <- A: zera a pilha (ainda não houve nenhum JSR). A, X, Y intactos
    sta $0300,x                         ; [$0300+X] <- A: zera a RAM comum, página 3. A, X, Y intactos
    sta $0400,x                         ; [$0400+X] <- A: página 4. A, X, Y intactos
    sta $0500,x                         ; [$0500+X] <- A: página 5. A, X, Y intactos
    sta $0600,x                         ; [$0600+X] <- A: página 6. A, X, Y intactos
    sta $0700,x                         ; [$0700+X] <- A: página 7. A, X, Y intactos
    lda #$FE                            ; A <- $FE: Y >= $EF coloca o sprite FORA da tela (escondido)
    sta oam_buf,x                       ; [$0200+X] <- A ($FE): esconde os 64 sprites. A, X, Y intactos
    inx                                 ; X <- X + 1 (0..255; depois de 255 volta a 0 e Z=1). A, Y intactos
    bne @clear_ram                      ; Z=0 (X != 0)? repete: 256 voltas no total. A, X, Y intactos

@wait_vblank2:                          ; segunda espera: após ~1 quadro a PPU aceita escritas com segurança
    bit PPUSTATUS                       ; N <- bit 7 de [$2002] (vblank?). A, X, Y intactos
    bpl @wait_vblank2                   ; ainda não é vblank? repete. A, X, Y intactos

    ; ---- A PPU está pronta. Com a renderização DESLIGADA podemos escrever na VRAM à vontade ----
    jsr load_palettes                   ; chama a sub-rotina (empilha o endereço de volta). Ao voltar: A=$30 (último byte copiado), X=$20 (32), Y intacto
    jsr load_nametable                  ; copia o mapa de tiles. Ao voltar: A=$0A (último byte copiado), X=$00, Y=$00
    jsr init_hero                       ; prepara tile/atributo dos 4 sprites. Ao voltar: A=$00, X=$10 (16), Y=$04

    lda #HERO_X_START                   ; A <- 16 (valor imediato). X, Y intactos
    sta hero_x                          ; [hero_x] <- A (16). Variável na Zero Page: 2 bytes, 3 ciclos. A, X, Y intactos
    lda #HERO_Y_START                   ; A <- 191. X, Y intactos
    sta hero_y                          ; [hero_y] <- A (191). A, X, Y intactos
    lda #$00                            ; A <- 0. X, Y intactos
    sta hero_dir                        ; [hero_dir] <- 0: começa andando para a direita. A, X, Y intactos

    ; ---- Só LIGUE a renderização durante o vblank. Se ligar no meio do quadro, o 1º quadro pode sair
    ; ---- com lixo: o endereço interno da PPU ainda aponta para o fim da nametable que acabamos de copiar.
@wait_vblank3:
    bit PPUSTATUS                       ; N <- bit 7 de [$2002] (vblank?). Esta leitura também reinicia o latch de $2005/$2006. A, X, Y intactos
    bpl @wait_vblank3                   ; ainda não é vblank? repete. A, X, Y intactos
    sta PPUSCROLL                       ; [$2005] <- A (0): scroll X = 0 (reaproveitamos A = 0 do STA hero_dir!). A, X, Y intactos
    sta PPUSCROLL                       ; [$2005] <- A (0): scroll Y = 0 (2ª escrita). A, X, Y intactos
    sta OAMADDR                         ; [$2003] <- A (0): DMA começa no sprite 0 (A ainda vale 0!). A, X, Y intactos
    lda #>oam_buf                       ; A <- $02 (byte alto de oam_buf). X, Y intactos
    sta OAMDMA                          ; [$4014] <- A: copia a OAM sombra (sprites ainda escondidos) ANTES de ligar a PPU.
                                        ;   Sem isto a OAM da PPU teria lixo do power-on e os sprites piscariam 1 quadro. A, X, Y intactos

    lda #(PPUCTRL_NMI | PPUCTRL_SPR_1000)  ; A <- %10001000 ($88): NMI ligado + sprites na tabela $1000. X, Y intactos
    sta PPUCTRL                         ; [$2000] <- A: fundo usa a tabela $0000; nametable 0. A, X, Y intactos
    lda #(PPUMASK_BG | PPUMASK_SPR | PPUMASK_BG_LEFT | PPUMASK_SPR_LEFT)  ; A <- %00011110 ($1E): mostra tudo. X, Y intactos
    sta PPUMASK                         ; [$2001] <- A: LIGA a renderização. A partir daqui a PPU desenha. A, X, Y intactos

; ------------------------------------------------------------------------------
;  Laço principal: espera o NMI (início do vblank), atualiza o jogo, repete
; ------------------------------------------------------------------------------
main_loop:
@wait_nmi:
    lda nmi_ready                       ; A <- [nmi_ready] (0 = ainda no mesmo quadro). Z=1 se 0. X, Y intactos
    beq @wait_nmi                       ; Z=1 (A = 0)? continua esperando. A, X, Y intactos
    lda #$00                            ; A <- 0. X, Y intactos
    sta nmi_ready                       ; [nmi_ready] <- 0: "consumimos" o aviso deste quadro. A, X, Y intactos
    jsr move_hero                       ; atualiza hero_x / hero_dir. Ao voltar: A e X mudaram (ver sub-rotina), Y intacto
    jsr update_hero                     ; escreve a posição do herói na OAM sombra. Ao voltar: A = X do último sprite, X=$10, Y=$04
    jmp main_loop                       ; volta ao início do laço (JMP = salto incondicional). A, X, Y intactos

; ------------------------------------------------------------------------------
;  nmi - a PPU interrompe a CPU no começo de cada vblank (60x por segundo, NTSC)
;  Regra de ouro: só salve/restaure o que você altera. Aqui só mexemos em A.
; ------------------------------------------------------------------------------
nmi:
    pha                                 ; empilha A (SP <- SP - 1). A, X, Y intactos (A só foi COPIADO)
    lda #$00                            ; A <- 0. X, Y intactos
    sta OAMADDR                         ; [$2003] <- A (0): o DMA começará no sprite 0. A, X, Y intactos
    lda #>oam_buf                       ; A <- byte ALTO de oam_buf = $02. X, Y intactos
    sta OAMDMA                          ; [$4014] <- A ($02): copia $0200-$02FF para a OAM (CPU pausa ~513 ciclos)
    lda #$01                            ; A <- 1. X, Y intactos
    sta nmi_ready                       ; [nmi_ready] <- 1: avisa o laço principal "um quadro novo começou". A, X, Y intactos
    pla                                 ; A <- valor do topo da pilha (restaura o A do programa interrompido). X, Y intactos
    rti                                 ; retorna da interrupção: restaura P e PC da pilha. A, X, Y intactos

; ------------------------------------------------------------------------------
;  irq - não usamos (APU/DMC com IRQ desligado); BRK também cai aqui
; ------------------------------------------------------------------------------
irq:
    rti                                 ; retorna imediatamente. A, X, Y intactos

; ------------------------------------------------------------------------------
;  load_palettes - copia 32 bytes de palette_data para $3F00-$3F1F da PPU
;  Altera: A (último byte copiado), X (termina em 32). Y intacto
; ------------------------------------------------------------------------------
load_palettes:
    bit PPUSTATUS                       ; reinicia o latch de $2006 (1ª escrita = byte alto). A, X, Y intactos
    lda #>PPU_PALETTE                   ; A <- $3F (byte alto do endereço $3F00). X, Y intactos
    sta PPUADDR                         ; [$2006] <- A ($3F): 1ª escrita = byte ALTO. A, X, Y intactos
    lda #<PPU_PALETTE                   ; A <- $00 (byte baixo do endereço $3F00). X, Y intactos
    sta PPUADDR                         ; [$2006] <- A ($00): 2ª escrita = byte BAIXO. PPU aponta para $3F00. A, X, Y intactos
    ldx #$00                            ; X <- 0: índice dentro de palette_data. A, Y intactos
@copy:
    lda palette_data,x                  ; A <- [palette_data + X] (modo absoluto,X). X, Y intactos
    sta PPUDATA                         ; [$2007] <- A: grava na paleta; o endereço da PPU avança +1 sozinho. A, X, Y intactos
    inx                                 ; X <- X + 1: próximo byte. A, Y intactos
    cpx #32                             ; compara X com 32 (X - 32 só afeta flags): Z=1 quando X = 32. A, X, Y intactos
    bne @copy                           ; Z=0 (X != 32)? repete. A, X, Y intactos
    rts                                 ; volta ao chamador (desempilha o endereço). A=último byte, X=32, Y intacto

; ------------------------------------------------------------------------------
;  load_nametable - copia 1024 bytes (960 de tiles + 64 de atributos) de "scene"
;  para a nametable 0 ($2000). Usa o ponteiro "ptr" na Zero Page, único jeito de
;  fazer LDA (ptr),Y. X = contador de páginas (4 x 256), Y = posição dentro da página.
; ------------------------------------------------------------------------------
load_nametable:
    bit PPUSTATUS                       ; reinicia o latch de $2006. A, X, Y intactos
    lda #>PPU_NAMETABLE0                ; A <- $20 (byte alto de $2000). X, Y intactos
    sta PPUADDR                         ; [$2006] <- A ($20): 1ª escrita (byte alto). A, X, Y intactos
    lda #<PPU_NAMETABLE0                ; A <- $00 (byte baixo de $2000). X, Y intactos
    sta PPUADDR                         ; [$2006] <- A ($00): 2ª escrita. PPU aponta para $2000. A, X, Y intactos
    lda #<scene                         ; A <- byte BAIXO do endereço do rótulo "scene". X, Y intactos
    sta ptr                             ; [ptr] <- A: guarda o byte baixo do ponteiro (Zero Page). A, X, Y intactos
    lda #>scene                         ; A <- byte ALTO do endereço de "scene". X, Y intactos
    sta ptr+1                           ; [ptr+1] <- A: guarda o byte alto do ponteiro. A, X, Y intactos
    ldx #$04                            ; X <- 4: faremos 4 páginas de 256 bytes = 1024 bytes. A, Y intactos
    ldy #$00                            ; Y <- 0: começa no primeiro byte da página. A, X intactos
@copy:
    lda (ptr),y                         ; A <- [ptr + Y]: lê 1 byte da ROM (indireto indexado, exige Zero Page). X, Y intactos
    sta PPUDATA                         ; [$2007] <- A: envia o byte à VRAM; endereço da PPU avança +1. A, X, Y intactos
    iny                                 ; Y <- Y + 1 (0..255; ao passar de 255 volta a 0 e Z=1). A, X intactos
    bne @copy                           ; Z=0 (Y != 0)? ainda há bytes nesta página. A, X, Y intactos
    inc ptr+1                           ; [ptr+1] <- [ptr+1] + 1: ponteiro avança para a PRÓXIMA página. A, X, Y intactos
    dex                                 ; X <- X - 1: uma página a menos. Z=1 quando X chega a 0. A, Y intactos
    bne @copy                           ; Z=0 (X != 0)? copia a próxima página. A, X, Y intactos
    rts                                 ; volta ao chamador. A=último byte, X=0, Y=0

; ------------------------------------------------------------------------------
;  init_hero - preenche, UMA vez, o número do tile e os atributos dos 4 sprites.
;  Tiles do herói na tabela $1000: $00 $01 (linha de cima), $02 $03 (linha de baixo)
;  Altera: A, X, Y
; ------------------------------------------------------------------------------
init_hero:
    ldx #$00                            ; X <- 0: deslocamento em bytes dentro de oam_buf (anda de 4 em 4). A, Y intactos
    ldy #$00                            ; Y <- 0: número do sprite (0..3) = número do tile. A, X intactos
@loop:
    tya                                 ; A <- Y: o número do sprite é igual ao número do tile. Z/N pelo valor. X, Y intactos
    sta oam_buf+1,x                     ; [oam_buf+1+X] <- A: byte 1 do sprite = tile. A, X, Y intactos
    lda #$00                            ; A <- 0: atributos (paleta de sprite 0, sem espelhar, na frente do fundo). X, Y intactos
    sta oam_buf+2,x                     ; [oam_buf+2+X] <- A: byte 2 do sprite = atributos. A, X, Y intactos
    inx                                 ; X <- X + 1 (1º de 4 INX para avançar 4 bytes = 1 sprite). A, Y intactos
    inx                                 ; X <- X + 1 (2º). A, Y intactos
    inx                                 ; X <- X + 1 (3º). A, Y intactos
    inx                                 ; X <- X + 1 (4º): X aponta para o próximo sprite. A, Y intactos
    iny                                 ; Y <- Y + 1: próximo sprite/tile. A, X intactos
    cpy #HERO_SPRITES                   ; compara Y com 4: Z=1 quando os 4 sprites foram feitos. A, X, Y intactos
    bne @loop                           ; Z=0 (Y != 4)? repete. A, X, Y intactos
    rts                                 ; volta ao chamador. A=0, X=16, Y=4

; ------------------------------------------------------------------------------
;  move_hero - anda 1 pixel por quadro; ao tocar a borda, inverte a direção
;  Altera: A (só em alguns caminhos) e X (só indo para a direita). Y intacto
; ------------------------------------------------------------------------------
move_hero:
    lda hero_dir                        ; A <- [hero_dir] (0 = direita, 1 = esquerda). Z=1 se 0. X, Y intactos
    bne @go_left                        ; Z=0 (A != 0)? vai para o trecho da esquerda. A, X, Y intactos
    inc hero_x                          ; [hero_x] <- [hero_x] + 1: anda para a direita (INC age direto na memória). A, X, Y intactos
    ldx hero_x                          ; X <- [hero_x] (posição nova). A, Y intactos
    cpx #HERO_X_MAX                     ; compara X com 240: C=1 se X >= 240 (chegou na borda). A, X, Y intactos
    bcc @done                           ; C=0 (X < 240)? ainda há espaço: termina. A, X, Y intactos
    lda #$01                            ; A <- 1 (esquerda). X, Y intactos
    sta hero_dir                        ; [hero_dir] <- A (1): a partir do próximo quadro anda para a esquerda. A, X, Y intactos
    rts                                 ; volta (RTS duplicado: mais barato que um JMP @done). A=1, X=240, Y intacto
@go_left:
    dec hero_x                          ; [hero_x] <- [hero_x] - 1: anda para a esquerda. DEC já ajusta Z (Z=1 se chegou a 0). A, X, Y intactos
    bne @done                           ; Z=0 (hero_x != 0)? ainda há espaço: termina. A, X, Y intactos
    lda #$00                            ; A <- 0 (direita). X, Y intactos
    sta hero_dir                        ; [hero_dir] <- A (0): volta a andar para a direita. A, X, Y intactos
@done:
    rts                                 ; volta ao chamador. Y intacto

; ------------------------------------------------------------------------------
;  update_hero - escreve as posições X e Y dos 4 sprites na OAM sombra
;  Posição de cada sprite = posição do herói + deslocamento (tabelas hero_off_x/y)
;  X = deslocamento em oam_buf (0,4,8,12)   Y = número do sprite (0..3)
;  Altera: A, X, Y
; ------------------------------------------------------------------------------
update_hero:
    ldx #$00                            ; X <- 0: início do sprite 0 dentro de oam_buf. A, Y intactos
    ldy #$00                            ; Y <- 0: sprite 0 nas tabelas de deslocamento. A, X intactos
@loop:
    lda hero_y                          ; A <- [hero_y] (Zero Page). X, Y intactos
    clc                                 ; C <- 0: ADC soma o carry; sem CLC o resultado sairia errado. A, X, Y intactos
    adc hero_off_y,y                    ; A <- A + [hero_off_y + Y] (0 ou 8). C=0 pois não passa de 255. X, Y intactos
    sta oam_buf,x                       ; [oam_buf+X] <- A: byte 0 do sprite = posição Y. A, X, Y intactos
    lda hero_x                          ; A <- [hero_x] (Zero Page). X, Y intactos
    clc                                 ; C <- 0 (prepara a soma). A, X, Y intactos
    adc hero_off_x,y                    ; A <- A + [hero_off_x + Y] (0 ou 8). X, Y intactos
    sta oam_buf+3,x                     ; [oam_buf+3+X] <- A: byte 3 do sprite = posição X. A, X, Y intactos
    inx                                 ; X <- X + 1 (1º de 4 INX = próximo sprite). A, Y intactos
    inx                                 ; X <- X + 1 (2º). A, Y intactos
    inx                                 ; X <- X + 1 (3º). A, Y intactos
    inx                                 ; X <- X + 1 (4º). A, Y intactos
    iny                                 ; Y <- Y + 1: próximo sprite. A, X intactos
    cpy #HERO_SPRITES                   ; compara Y com 4. A, X, Y intactos
    bne @loop                           ; Z=0 (Y != 4)? repete. A, X, Y intactos
    rts                                 ; volta ao chamador. A = X do último sprite, X=16, Y=4

; ==============================================================================
;  DADOS SOMENTE-LEITURA (ficam na PRG-ROM, logo após o código)
; ==============================================================================
.segment "RODATA"                       ; dados constantes

hero_off_x: .byte 0, 8, 0, 8            ; deslocamento X de cada sprite do herói: esq, dir, esq, dir
hero_off_y: .byte 0, 0, 8, 8            ; deslocamento Y de cada sprite do herói: cima, cima, baixo, baixo

.ifdef USE_NEXXT_FILES                  ; compilando com -D USE_NEXXT_FILES: usa os arquivos exportados do NEXXT
palette_data:                           ; rótulo: endereço da paleta na ROM
    .incbin "gfx/bg.pal"                ; 16 bytes: 4 paletas de fundo  (arquivo salvo pelo NEXXT)
    .incbin "gfx/spr.pal"               ; 16 bytes: 4 paletas de sprite (arquivo salvo pelo NEXXT)
scene:                                  ; rótulo: endereço da nametable na ROM
    .incbin "gfx/scene.nam"             ; 1024 bytes: 960 tiles + 64 atributos (salvo pelo NEXXT)
.else                                   ; caso normal: dados escritos à mão em texto (didático)
.include "palette.inc"                  ; define palette_data: 32 bytes de cores
.include "scene.inc"                    ; define scene: 960 bytes de tiles + 64 de atributos
.endif                                  ; fim da escolha

; ==============================================================================
;  CHR-ROM: a arte em si (tiles de 8x8 pixels, 16 bytes cada)
; ==============================================================================
.segment "CHR_BG"                       ; tabela de padrões 0 (PPU $0000-$0FFF): tiles do FUNDO
.ifdef USE_NEXXT_FILES                  ; modo NEXXT: um único arquivo de 8 KB cobre as duas tabelas
    .incbin "gfx/tiles.chr"             ; 8192 bytes: fundo ($0000) + sprites ($1000), salvo pelo NEXXT
.else                                   ; caso normal: tiles escritos em binário
.include "chr_bg.inc"                   ; tiles de fundo: vazio, tijolo, grama, terra, nuvem, barras, coração
.segment "CHR_SPR"                      ; tabela de padrões 1 (PPU $1000-$1FFF): tiles dos SPRITES
.include "chr_spr.inc"                  ; tiles do herói (4 tiles = 16x16 pixels)
.endif                                  ; fim da escolha

; ==============================================================================
;  VETORES - 6 bytes nos endereços $FFFA-$FFFF: onde a CPU procura as 3 "portas de entrada"
; ==============================================================================
.segment "VECTORS"                      ; o nes.cfg posiciona este segmento em $FFFA
    .word nmi                           ; $FFFA-$FFFB: endereço da rotina de NMI (início de cada vblank)
    .word reset                         ; $FFFC-$FFFD: endereço da rotina de RESET (liga / botão reset)
    .word irq                           ; $FFFE-$FFFF: endereço da rotina de IRQ/BRK
