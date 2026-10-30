; ==============================================================================
;  nes.inc  -  nomes para os registradores de hardware do NES
;
;  Aqui só existem CONSTANTES (NOME = valor). Nada disto gera código nem ocupa
;  espaço na ROM: o assembler apenas troca o nome pelo número quando você o usa.
;  Isso evita "números mágicos" como $2006 espalhados pelo programa.
; ==============================================================================

; ------------------------------------------------------------------------------
;  Registradores da PPU (a "placa de vídeo" do NES) - visíveis para a CPU
; ------------------------------------------------------------------------------
PPUCTRL     = $2000     ; escrita : NMI, tamanho do sprite, tabelas de padrões, incremento
PPUMASK     = $2001     ; escrita : liga/desliga fundo e sprites
PPUSTATUS   = $2002     ; leitura : bit 7 = vblank; ler também zera o "latch" de $2005/$2006
OAMADDR     = $2003     ; escrita : endereço inicial dentro da OAM (memória de sprites)
OAMDATA     = $2004     ; leitura/escrita : byte da OAM
PPUSCROLL   = $2005     ; escrita x2 : scroll X e depois scroll Y
PPUADDR     = $2006     ; escrita x2 : endereço da VRAM (byte ALTO primeiro, depois BAIXO)
PPUDATA     = $2007     ; leitura/escrita : dado da VRAM; o endereço avança sozinho

; ------------------------------------------------------------------------------
;  Registradores do APU / E-S (aqui só usamos para "silenciar" interrupções)
; ------------------------------------------------------------------------------
DMC_FREQ    = $4010     ; escrita : bit 7 = IRQ do canal DMC (0 = desligado)
OAMDMA      = $4014     ; escrita : número da PÁGINA da RAM a copiar para a OAM (256 bytes)
APU_FRAME   = $4017     ; escrita : bit 6 = 1 desliga o IRQ do contador de quadros do APU

; ------------------------------------------------------------------------------
;  Endereços na VRAM (espaço de endereçamento da PPU - NÃO é o da CPU!)
; ------------------------------------------------------------------------------
PPU_NAMETABLE0  = $2000 ; nametable 0: 960 bytes de tiles + 64 bytes de atributos
PPU_PALETTE     = $3F00 ; RAM de paletas: 16 bytes de fundo + 16 bytes de sprites

; ------------------------------------------------------------------------------
;  Bits do PPUCTRL ($2000)      V P H B S I N N
; ------------------------------------------------------------------------------
PPUCTRL_NMI       = %10000000   ; bit 7: gera NMI no começo de cada vblank
PPUCTRL_SPR_8X16  = %00100000   ; bit 5: sprites 8x16 (se 0 -> 8x8)
PPUCTRL_BG_1000   = %00010000   ; bit 4: fundo usa a tabela de padrões em $1000 (se 0 -> $0000)
PPUCTRL_SPR_1000  = %00001000   ; bit 3: sprites 8x8 usam a tabela em $1000 (se 0 -> $0000)
PPUCTRL_INC32     = %00000100   ; bit 2: após cada acesso a $2007 o endereço soma 32 (se 0 -> soma 1)

; ------------------------------------------------------------------------------
;  Bits do PPUMASK ($2001)      B G R s b M m g   (B,G,R = ênfase de cor; g = tons de cinza)
; ------------------------------------------------------------------------------
PPUMASK_SPR       = %00010000   ; bit 4: mostrar sprites
PPUMASK_BG        = %00001000   ; bit 3: mostrar fundo
PPUMASK_SPR_LEFT  = %00000100   ; bit 2: mostrar sprites nos 8 pixels mais à esquerda
PPUMASK_BG_LEFT   = %00000010   ; bit 1: mostrar fundo nos 8 pixels mais à esquerda
