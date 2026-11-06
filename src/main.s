; =============================================================================
;  main.s - SystemFailure (AOC / NES)
;  Tela inicial + "PRESS START" para iniciar o jogo.
; =============================================================================

.segment "HEADER"
.byte "NES", $1A
.byte 2                 ; 2 x 16KB PRG
.byte 1                 ; 1 x 8KB CHR
.byte $00
.byte $00
.res 8, $00

; -----------------------------------------------------------------------------
; Variaveis na zero page
; -----------------------------------------------------------------------------
.segment "ZEROPAGE"
ptr:        .res 2      ; ponteiro p/ copiar a nametable
pad1:       .res 1      ; estado dos botoes do controle 1 (lido neste quadro)
pad1_old:   .res 1      ; estado dos botoes no quadro ANTERIOR
game_state: .res 1      ; 0 = tela inicial | 1 = jogo
nmi_ready:  .res 1      ; o NMI poe 1 aqui a cada quadro

; constantes dos botoes (cada bit)
BTN_A      = %10000000
BTN_B      = %01000000
BTN_SELECT = %00100000
BTN_START  = %00010000
BTN_UP     = %00001000
BTN_DOWN   = %00000100
BTN_LEFT   = %00000010
BTN_RIGHT  = %00000001

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
    inx
    stx $2000
    stx $2001
    stx $4010

vblankwait:
    bit $2002
    bpl vblankwait

vblankwait2:
    bit $2002
    bpl vblankwait2

    ; estado inicial = tela inicial (0)
    lda #0
    sta game_state
    sta nmi_ready

    ; comeca fingindo que TODOS os botoes ja estavam apertados.
    ; assim, um botao que ja esta segurado quando o jogo liga NAO conta
    ; como "apertou agora": o jogador precisa soltar e apertar de novo.
    lda #$FF
    sta pad1
    sta pad1_old

    jsr load_palette
    jsr load_title_screen   ; carrega a nametable da tela inicial

    ; reseta scroll
    lda #$00
    sta $2005
    sta $2005

    ; liga renderizacao + NMI
    lda #%00001110
    sta $2001
    lda #%10000000
    sta $2000

; =============================================================================
; LOOP PRINCIPAL
; =============================================================================
main_loop:
    ; espera o proximo quadro (o NMI avisa pondo 1 em nmi_ready)
wait_frame:
    lda nmi_ready
    beq wait_frame
    lda #0
    sta nmi_ready

    jsr read_controller     ; atualiza pad1 e pad1_old (1x por quadro)

    ; decide o que fazer conforme o estado atual
    lda game_state
    bne state_game          ; se != 0, esta no jogo

; ---- estado 0: tela inicial ----
state_title:
    ; detecta START recem-apertado (estava solto e agora pressionado)
    lda pad1
    and #BTN_START
    beq main_loop           ; START nao esta pressionado -> continua esperando

    lda pad1_old
    and #BTN_START
    bne main_loop           ; ja estava pressionado no quadro anterior -> ignora

    ; START foi apertado AGORA -> inicia o jogo
    jsr start_game
    jmp main_loop

; ---- estado 1: jogo ----
state_game:
    ; (por enquanto o jogo so mostra outra tela; a logica entra aqui depois)
    jmp main_loop

; =============================================================================
; start_game: troca da tela inicial para o jogo
; =============================================================================
.proc start_game
    ; desliga NMI e renderizacao antes de reescrever a nametable
    lda #$00
    sta $2000
    sta $2001

    jsr load_game_screen    ; carrega a tela/mapa do jogo

    ; marca estado = jogo
    lda #1
    sta game_state

    ; religa a renderizacao
    lda #$00
    sta $2005
    sta $2005
    lda #%00001110
    sta $2001
    lda #%10000000          ; religa o NMI
    sta $2000
    rts
.endproc

; =============================================================================
; read_controller: le o controle 1 e guarda em pad1 (e o anterior em pad1_old)
; =============================================================================
.proc read_controller
    ; guarda o estado do quadro anterior
    lda pad1
    sta pad1_old

    ; strobe: trava o estado atual dos botoes
    lda #$01
    sta $4016
    lda #$00
    sta $4016

    ; le os 8 botoes, 1 bit por vez, montando o byte em pad1
    ldx #$08
loop:
    lda $4016       ; bit 0 = estado do botao atual
    lsr a           ; joga o bit 0 para o carry
    rol pad1        ; entra o carry no bit baixo de pad1
    dex
    bne loop
    rts
.endproc

; =============================================================================
; load_palette: copia 32 bytes de paleta para $3F00
; =============================================================================
.proc load_palette
    lda $2002
    lda #$3F
    sta $2006
    lda #$00
    sta $2006
    ldx #$00
loop:
    lda titleScreen_palette, x
    sta $2007
    inx
    cpx #$20
    bne loop
    rts
.endproc

; =============================================================================
; load_title_screen: copia a nametable da TELA INICIAL para $2000
; =============================================================================
.proc load_title_screen
    lda $2002
    lda #$20
    sta $2006
    lda #$00
    sta $2006

    lda #<titleScreen_nametable
    sta ptr
    lda #>titleScreen_nametable
    sta ptr+1

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
; load_game_screen: copia a nametable do JOGO (mapa) para $2000
; =============================================================================
.proc load_game_screen
    lda $2002
    lda #$20
    sta $2006
    lda #$00
    sta $2006

    lda #<game_nametable
    sta ptr
    lda #>game_nametable
    sta ptr+1

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
; NMI: reseta o scroll a cada quadro
; =============================================================================
nmi:
    pha                     ; salva A (o NMI interrompe o loop a qualquer hora)

    lda #$00
    sta $2005
    sta $2005

    lda #1
    sta nmi_ready           ; avisa o loop principal: comecou um quadro novo

    pla                     ; restaura A
    rti

; -----------------------------------------------------------------------------
; Dados de graficos
; -----------------------------------------------------------------------------
.segment "RODATA"
titleScreen_palette:
    .incbin "assets/TitleScreen/title.pal"
titleScreen_nametable:
    .incbin "assets/TitleScreen/title.nam"
game_nametable:
    .incbin "assets/teste.nam"    ; tela de teste (trocar por quarto.nam depois)

.segment "VECTORS"
.word nmi
.word reset
.word reset

.segment "CHARS"
.incbin "assets/TitleScreen/title.chr"
.incbin "assets/TitleScreen/title.chr"
