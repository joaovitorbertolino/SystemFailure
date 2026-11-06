; =============================================================================
;  main.s - SystemFailure (AOC / NES)
;  Mostra a tela inicial (title screen) feita no NEXXT.
;  Baseado no esqueleto original do grupo, agora carregando paleta + nametable.
; =============================================================================


.segment "HEADER"
.byte "NES", $1A
.byte 2                 ; 2 x 16KB PRG
.byte 1                 ; 1 x 8KB CHR
.byte $00
.byte $00
.res 8, $00


.segment "ZEROPAGE"
ptr: .res 2             ; ponteiro de 16 bits p/ copiar a nametable

.segment "CODE"

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

    ; -------- carrega a paleta (32 bytes) em $3F00 --------
    lda $2002           ; reseta o latch de endereço
    lda #$3F
    sta $2006
    lda #$00
    sta $2006
    ldx #$00
load_palette:
    lda titleScreen_palette, x
    sta $2007
    inx
    cpx #$20            ; 32 bytes
    bne load_palette

    ; -------- carrega a nametable (1024 bytes) em $2000 --------
    lda $2002
    lda #$20
    sta $2006           ; endereço alto = $2000 (nametable 0)
    lda #$00
    sta $2006

    lda #<titleScreen_nametable
    sta ptr
    lda #>titleScreen_nametable
    sta ptr+1

    ldx #$04            ; 4 páginas de 256 bytes = 1024
    ldy #$00
load_nt:
    lda (ptr), y
    sta $2007
    iny
    bne load_nt
    inc ptr+1
    dex
    bne load_nt

    ; -------- reseta o scroll pra tela não deslizar --------
    lda #$00
    sta $2005
    sta $2005

    ; -------- liga a renderização do fundo --------
    lda #%00001110      ; mostra o background (e sprites)
    sta $2001
    lda #%10000000      ; liga NMI (opcional por enquanto)
    sta $2000

loop:
    jmp loop

; -------- NMI: por enquanto só reseta o scroll a cada quadro --------
nmi:
    lda #$00
    sta $2005
    sta $2005
    rti

; -----------------------------------------------------------------------------
; Dados de gráficos (arquivos exportados do NEXXT)
; -----------------------------------------------------------------------------
.segment "RODATA"
titleScreen_palette:
    .incbin "assets/TitleScreen/title.pal"
titleScreen_nametable:
    .incbin "assets/TitleScreen/title.nam"

.segment "VECTORS"
.word nmi               ; $FFFA = NMI
.word reset             ; $FFFC = RESET
.word reset             ; $FFFE = IRQ

.segment "CHARS"
.incbin "assets/TitleScreen/title.chr"
.incbin "assets/TitleScreen/title.chr"   ; duplica p/ preencher os 8KB de CHR