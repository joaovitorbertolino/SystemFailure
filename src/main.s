; =============================================================================
;  main.s - SystemFailure (AOC / NES)
;  Tela inicial -> START -> Spawn com o personagem andando.
; =============================================================================

.segment "HEADER"
.byte "NES", $1A
.byte 2                 ; 2 x 16KB PRG
.byte 1                 ; 1 x 8KB CHR
.byte $00
.byte $00
.res 8, $00

; -----------------------------------------------------------------------------
; Constantes
; -----------------------------------------------------------------------------
; botoes (cada bit de pad1)
BTN_A      = %10000000
BTN_B      = %01000000
BTN_SELECT = %00100000
BTN_START  = %00010000
BTN_UP     = %00001000
BTN_DOWN   = %00000100
BTN_LEFT   = %00000010
BTN_RIGHT  = %00000001

; PPUCTRL ($2000)
;   bit 7 = liga NMI
;   bit 4 = tiles do fundo:   0 = $0000 | 1 = $1000
;   bit 3 = tiles dos sprites: 0 = $0000 | 1 = $1000
PPUCTRL_TITLE = %10000000   ; fundo na pattern table 0, sprites na 0
PPUCTRL_GAME  = %10010000   ; fundo na pattern table 1 (Spawn), sprites na 0

; PPUMASK ($2001)
;   bit 4 = mostra sprites | bit 3 = mostra fundo
;   bits 2 e 1 = mostra sprites/fundo nos 8 pixels da esquerda
PPUMASK_ON = %00011110

; copia da OAM na RAM: 64 sprites x 4 bytes, de $0200 a $02FF.
; NAO use essa pagina da RAM pra outra coisa.
OAM = $0200

; direcoes do personagem
DIR_DOWN  = 0
DIR_UP    = 1
DIR_RIGHT = 2
DIR_LEFT  = 3

; personagem
PLAYER_START_X = 56     ; posicao inicial no Spawn (em pixels, canto de cima/esquerda)
PLAYER_START_Y = 48
ATTACK_FRAMES  = 12     ; quantos quadros dura um ataque (12 = 0,2 segundo)

; limites de movimento (PROVISORIO: so impede de sair da tela.
; a colisao com as paredes do mapa vem depois)
MIN_X = 16
MAX_X = 224
MIN_Y = 40
MAX_Y = 208

; -----------------------------------------------------------------------------
; Variaveis na zero page
; -----------------------------------------------------------------------------
.segment "ZEROPAGE"
ptr:          .res 2    ; ponteiro p/ copiar paleta e nametable
pad1:         .res 1    ; botoes do controle 1 neste quadro
pad1_old:     .res 1    ; botoes no quadro anterior
game_state:   .res 1    ; 0 = tela inicial | 1 = jogo
nmi_ready:    .res 1    ; o NMI poe 1 aqui a cada quadro

player_x:     .res 1    ; posicao X do personagem (pixels)
player_y:     .res 1    ; posicao Y do personagem (pixels)
player_dir:   .res 1    ; DIR_DOWN / DIR_UP / DIR_RIGHT / DIR_LEFT
moving:       .res 1    ; 1 se andou neste quadro
anim_timer:   .res 1    ; conta quadros, usado nas animacoes
attack_timer: .res 1    ; > 0 enquanto o ataque acontece
tile_base:    .res 1    ; tile de cima/esquerda do quadro atual
attr_tmp:     .res 1    ; atributo dos 4 sprites (paleta + espelhamento)

.segment "CODE"

; =============================================================================
; RESET
; =============================================================================
reset:
    sei
    cld
    ldx #$40
    stx $4017
    ldx #$FF
    txs
    inx                 ; x = 0
    stx $2000
    stx $2001
    stx $4010

vblankwait:
    bit $2002
    bpl vblankwait

    ; --- zera a RAM (menos a pagina da OAM) ---
    lda #$00
clear_ram:
    sta $0000, x
    sta $0100, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    inx
    bne clear_ram

    ; --- esconde os 64 sprites (Y = $FF fica fora da tela) ---
    lda #$FF
clear_oam:
    sta OAM, x
    inx
    bne clear_oam

vblankwait2:
    bit $2002
    bpl vblankwait2

    ; estado inicial = tela inicial (0). A RAM ja foi zerada.
    ; comeca fingindo que TODOS os botoes ja estavam apertados, assim
    ; um botao segurado quando o jogo liga nao conta como "apertou agora".
    lda #$FF
    sta pad1
    sta pad1_old

    ; paleta da tela inicial
    lda #<titleScreen_palette
    sta ptr
    lda #>titleScreen_palette
    sta ptr+1
    jsr load_palette

    ; nametable da tela inicial
    lda #<titleScreen_nametable
    sta ptr
    lda #>titleScreen_nametable
    sta ptr+1
    jsr load_nametable

    lda #$00
    sta $2005
    sta $2005

    lda #PPUMASK_ON
    sta $2001
    lda #PPUCTRL_TITLE
    sta $2000

; =============================================================================
; LOOP PRINCIPAL (roda 1 vez por quadro)
; =============================================================================
main_loop:
wait_frame:
    lda nmi_ready
    beq wait_frame
    lda #0
    sta nmi_ready

    jsr read_controller

    lda game_state
    bne state_game

; ---- estado 0: tela inicial ----
state_title:
    lda pad1
    and #BTN_START
    beq main_loop           ; START nao esta apertado

    lda pad1_old
    and #BTN_START
    bne main_loop           ; ja estava apertado no quadro anterior

    jsr start_game
    jmp main_loop

; ---- estado 1: jogo ----
state_game:
    jsr update_player       ; le o controle e move o personagem
    jsr draw_player         ; escreve os 4 sprites na copia da OAM
    jmp main_loop

; =============================================================================
; start_game: troca da tela inicial para o Spawn
; =============================================================================
.proc start_game
    lda #$00
    sta $2000               ; desliga NMI
    sta $2001               ; desliga renderizacao

    ; paleta do Spawn (fundo)
    lda #<game_palette
    sta ptr
    lda #>game_palette
    sta ptr+1
    jsr load_palette

    ; paletas dos sprites (sobrescreve a parte de sprites da paleta do Spawn)
    jsr load_sprite_palettes

    ; nametable do Spawn
    lda #<game_nametable
    sta ptr
    lda #>game_nametable
    sta ptr+1
    jsr load_nametable

    ; personagem comeca parado, olhando pra baixo
    lda #PLAYER_START_X
    sta player_x
    lda #PLAYER_START_Y
    sta player_y
    lda #DIR_DOWN
    sta player_dir
    lda #0
    sta moving
    sta anim_timer
    sta attack_timer
    jsr draw_player

    lda #1
    sta game_state

    lda #$00
    sta $2005
    sta $2005
    lda #PPUMASK_ON
    sta $2001
    lda #PPUCTRL_GAME
    sta $2000
    rts
.endproc

; =============================================================================
; update_player: ataque e movimento
; =============================================================================
.proc update_player
    inc anim_timer          ; relogio das animacoes (da a volta em 255)

    ; --- ataque em andamento? enquanto ataca, nao anda ---
    lda attack_timer
    beq @check_attack
    dec attack_timer
    rts

@check_attack:
    ; apertou A agora? (solto no quadro anterior, apertado neste)
    lda pad1
    and #BTN_A
    beq @move
    lda pad1_old
    and #BTN_A
    bne @move
    lda #ATTACK_FRAMES
    sta attack_timer
    lda #0
    sta moving
    rts

@move:
    lda #0
    sta moving

    ; --- cima ---
    lda pad1
    and #BTN_UP
    beq @not_up
    lda #DIR_UP
    sta player_dir
    lda #1
    sta moving
    lda player_y
    cmp #MIN_Y+1            ; y <= MIN_Y ? entao nao sobe mais
    bcc @not_up
    dec player_y
@not_up:

    ; --- baixo ---
    lda pad1
    and #BTN_DOWN
    beq @not_down
    lda #DIR_DOWN
    sta player_dir
    lda #1
    sta moving
    lda player_y
    cmp #MAX_Y              ; y >= MAX_Y ? entao nao desce mais
    bcs @not_down
    inc player_y
@not_down:

    ; --- esquerda ---
    lda pad1
    and #BTN_LEFT
    beq @not_left
    lda #DIR_LEFT
    sta player_dir
    lda #1
    sta moving
    lda player_x
    cmp #MIN_X+1
    bcc @not_left
    dec player_x
@not_left:

    ; --- direita ---
    lda pad1
    and #BTN_RIGHT
    beq @not_right
    lda #DIR_RIGHT
    sta player_dir
    lda #1
    sta moving
    lda player_x
    cmp #MAX_X
    bcs @not_right
    inc player_x
@not_right:
    rts
.endproc

; =============================================================================
; draw_player: escolhe o quadro e escreve os 4 sprites na OAM ($0200-$020F)
;
;   sprite 0 = cima/esquerda   sprite 1 = cima/direita
;   sprite 2 = baixo/esquerda  sprite 3 = baixo/direita
; =============================================================================
.proc draw_player
    ldx player_dir          ; X = direcao (indice das tabelas abaixo)

    ; --- escolhe o tile de cima/esquerda do quadro ---
    lda attack_timer
    beq @not_attacking
    lda tiles_attack, x
    jmp @got_tile

@not_attacking:
    lda moving
    beq @idle
    lda anim_timer
    and #%00001000          ; troca o passo a cada 8 quadros
    bne @walk2
    lda tiles_walk1, x
    jmp @got_tile
@walk2:
    lda tiles_walk2, x
    jmp @got_tile

@idle:
    lda anim_timer
    and #%00100000          ; respira a cada 32 quadros
    bne @idle2
    lda tiles_idle1, x
    jmp @got_tile
@idle2:
    lda tiles_idle2, x

@got_tile:
    sta tile_base
    lda attr_by_dir, x      ; paleta 0, espelhado so pra esquerda
    sta attr_tmp

    ; --- Y dos 4 sprites ---
    lda player_y
    sta OAM+0
    sta OAM+4
    clc
    adc #8
    sta OAM+8
    sta OAM+12

    ; --- X dos 4 sprites ---
    lda player_x
    sta OAM+3
    sta OAM+11
    clc
    adc #8
    sta OAM+7
    sta OAM+15

    ; --- atributos ---
    lda attr_tmp
    sta OAM+2
    sta OAM+6
    sta OAM+10
    sta OAM+14

    ; --- tiles ---
    ; normal:     esq = T,   dir = T+1   (e +$10 embaixo)
    ; espelhado:  esq = T+1, dir = T     (o desenho inteiro vira)
    lda attr_tmp
    bne @flipped

    lda tile_base
    sta OAM+1               ; cima/esq  = T
    clc
    adc #$01
    sta OAM+5               ; cima/dir  = T+1
    clc
    adc #$0F
    sta OAM+9               ; baixo/esq = T+$10
    clc
    adc #$01
    sta OAM+13              ; baixo/dir = T+$11
    rts

@flipped:
    lda tile_base
    sta OAM+5               ; cima/dir  = T
    clc
    adc #$01
    sta OAM+1               ; cima/esq  = T+1
    clc
    adc #$0F
    sta OAM+13              ; baixo/dir = T+$10
    clc
    adc #$01
    sta OAM+9               ; baixo/esq = T+$11
    rts
.endproc

; =============================================================================
; read_controller: le o controle 1 em pad1 (e guarda o anterior em pad1_old)
; =============================================================================
.proc read_controller
    lda pad1
    sta pad1_old

    lda #$01
    sta $4016
    lda #$00
    sta $4016

    ldx #$08
loop:
    lda $4016
    lsr a
    rol pad1
    dex
    bne loop
    rts
.endproc

; =============================================================================
; load_palette: copia 32 bytes (ptr) para $3F00
; =============================================================================
.proc load_palette
    lda $2002
    lda #$3F
    sta $2006
    lda #$00
    sta $2006
    ldy #$00
loop:
    lda (ptr), y
    sta $2007
    iny
    cpy #$20
    bne loop
    rts
.endproc

; =============================================================================
; load_sprite_palettes: copia as 4 paletas de sprite (16 bytes) para $3F10
; =============================================================================
.proc load_sprite_palettes
    lda $2002
    lda #$3F
    sta $2006
    lda #$10
    sta $2006
    ldx #$00
loop:
    lda sprite_palettes, x
    sta $2007
    inx
    cpx #$10
    bne loop
    rts
.endproc

; =============================================================================
; load_nametable: copia 1024 bytes (ptr) para $2000
; =============================================================================
.proc load_nametable
    lda $2002
    lda #$20
    sta $2006
    lda #$00
    sta $2006

    ldx #$04
    ldy #$00
loop:
    lda (ptr), y
    sta $2007
    iny
    bne loop
    inc ptr+1
    dex
    bne loop
    rts
.endproc

; =============================================================================
; NMI: a cada quadro, envia os sprites pra PPU e avisa o loop principal
; =============================================================================
nmi:
    pha

    ; OAM DMA: copia a pagina $0200 inteira (64 sprites) para a PPU
    lda #$00
    sta $2003
    lda #>OAM               ; = $02
    sta $4014

    lda #$00
    sta $2005
    sta $2005

    lda #1
    sta nmi_ready

    pla
    rti

; -----------------------------------------------------------------------------
; Dados
; -----------------------------------------------------------------------------
.segment "RODATA"

; quadros do personagem: tile de cima/esquerda, por direcao
;                 baixo  cima   dir    esq (= dir espelhado)
tiles_walk1:  .byte $80,   $84,   $88,   $88
tiles_walk2:  .byte $82,   $86,   $8A,   $8A
tiles_idle1:  .byte $8C,   $A6,   $AA,   $AA
tiles_idle2:  .byte $8E,   $A8,   $AC,   $AC
tiles_attack: .byte $A0,   $A2,   $A4,   $A4
; atributo: bits 0-1 = paleta de sprite (0) | bit 6 = espelha na horizontal
attr_by_dir:  .byte $00,   $00,   $00,   $40

; as 4 paletas de sprite (combinadas com o grupo)
sprite_palettes:
    .byte $0F, $07, $37, $31    ; 0: personagem
    .byte $0F, $0B, $2A, $10    ; 1: inimigo parado
    .byte $0F, $06, $16, $30    ; 2: inimigo que persegue
    .byte $0F, $07, $10, $28    ; 3: itens

titleScreen_palette:
    .incbin "assets/TitleScreen/title.pal"
titleScreen_nametable:
    .incbin "assets/TitleScreen/title.nam"
game_palette:
    .incbin "assets/Quarto-2/quarto_2.pal"
game_nametable:
    .incbin "assets/Quarto-2/quarto_2.nam"

.segment "VECTORS"
.word nmi
.word reset
.word reset

; -----------------------------------------------------------------------------
; CHR-ROM (8KB = 2 pattern tables de 4KB)
; -----------------------------------------------------------------------------
.segment "CHARS"
.incbin "assets/Tiles/TitleSprites.chr"      ; $0000: tela inicial + sprites
.incbin "assets/Tiles/Rooms.chr"   ; $1000: salas