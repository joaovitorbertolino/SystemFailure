# Do zero ao pixel: gráficos no NES com Assembly 6502

**ca65 (assembler) + NEXXT Studio (arte) + Mesen (emulador)** — tutorial para quem vai produzir os gráficos
do jogo e precisa entender o que acontece "por baixo dos panos".

> Este material acompanha o projeto desta pasta. **Tudo o que é mostrado aqui existe no código**
> (`src/main.asm` etc.) e foi executado/verificado. Quando algo não pôde ser verificado, está dito claramente
> (veja a [seção de limites da verificação](#limites-da-verificação)).

## Sumário

| Aula | Assunto | Você sai sabendo… |
|---|---|---|
| 0 | Preparação | instalar e compilar o projeto |
| 1 | Mapa mental | quem faz o quê: CPU, PPU, cartucho |
| 2 | Bits, hexa e a notação do ca65 | ler `$FF`, `%1010`, `#`, `<`, `>` |
| 3 | A CPU 6502 | A, X, Y, flags, modos de endereçamento, **Zero Page** |
| 4 | Mapas de memória | onde cada coisa mora (CPU e PPU) |
| 5 | Como o NES desenha | quadro, vblank, NMI e os 5 "blocos" gráficos |
| 6 | **O tile em bits** | converter pixels ↔ bytes (sua aula principal) |
| 7 | Cores | paletas e tabela de atributos (a regra dos 16×16) |
| 8 | Sprites e OAM | 4 bytes por sprite, herói 16×16, DMA |
| 9 | Anatomia do projeto ca65 | cabeçalho iNES, segmentos, `nes.cfg`, build |
| 10 | Passeio pelo `main.asm` | por que cada bloco existe |
| 11 | NEXXT → ROM | exportar `.chr/.nam/.pal` e usar no código |
| 12 | Mesen | inspecionar tiles, paletas, OAM e depurar A/X/Y |
| 13 | Problemas comuns | sintoma → causa → correção |
| 14 | Exercícios e próximos passos | praticar |

---

## Aula 0 — Preparação

### Ferramentas

| Ferramenta | Para quê | Onde obter |
|---|---|---|
| **cc65** (traz `ca65` e `ld65`) | montar e linkar o código | <https://cc65.github.io/> — Windows: baixe o *snapshot* zip; Linux: `sudo apt install cc65`; macOS: `brew install cc65` |
| **Mesen** (recomendado: Mesen 2) | rodar e **depurar** a ROM | <https://github.com/SourMesen/Mesen2> |
| **NEXXT Studio** | desenhar tiles, paletas, telas | <https://frankengraphics.itch.io/nexxt> |
| Editor de texto | escrever o `.asm` | qualquer um (VS Code, Notepad++…). Salve **em UTF-8** |

**Windows:** extraia o cc65 (por exemplo em `C:\cc65`) e adicione `C:\cc65\bin` ao `PATH`.
Teste num terminal novo: `ca65 --version` e `ld65 --version`.

### Compilar e rodar

```text
make              (Linux/macOS/WSL)        ou        build.bat      (Windows)
```

Isso gera `build/hello_chr.nes`. Abra no Mesen (File → Open, ou arraste o arquivo para a janela).
Você deve ver: 3 corações, 2 nuvens, 4 blocos listrados com **cores diferentes**, chão de grama/terra/tijolo
e um herói vermelho andando de um lado para o outro (compare com `docs/preview.png`).

**ROM de conferência:** `docs/rom_de_conferencia.nes` é a ROM que o *meu simulador de verificação* montou a partir
deste mesmo código. Você pode abri-la no Mesen **antes** de instalar o cc65, só para ver o resultado esperado.
Depois de compilar a sua, compare as duas:

```text
Linux/macOS/WSL:   cmp build/hello_chr.nes docs/rom_de_conferencia.nes
Windows (cmd):     fc /b build\hello_chr.nes docs\rom_de_conferencia.nes
```

Se forem idênticas, o `ca65`/`ld65` reais geraram exatamente os mesmos 40 976 bytes. Se **diferirem**, isso não é
necessariamente um erro seu (o simulador não é o `ca65`): mande o resultado da comparação e eu investigo.

### Estrutura da pasta

```text
nes-tutorial/
├── nes.cfg              ← mapa de memória do cartucho (usado pelo ld65)
├── Makefile / build.bat ← comandos de compilação
├── src/
│   ├── main.asm         ← o programa (TODA linha comentada: A, X, Y)
│   ├── nes.inc          ← nomes dos registradores (PPUCTRL, PPUADDR…)
│   ├── chr_bg.inc       ← tiles do FUNDO escritos em BINÁRIO
│   ├── chr_spr.inc      ← tiles dos SPRITES (herói) em BINÁRIO
│   ├── palette.inc      ← 32 bytes de cores
│   └── scene.inc        ← nametable (mapa de tiles) + atributos
├── gfx/                 ← os MESMOS dados em binário, para abrir no NEXXT
│   ├── tiles.chr (8192 B)   scene.nam (1024 B)   bg.pal (16 B)   spr.pal (16 B)
├── tools/chr_dump.py    ← mostra um tile do .chr em bits (Aula 6)
├── docs/
│   ├── preview.png          ← como a tela deve ficar
│   ├── chr_sheet.png        ← os tiles de cada tabela de padrões
│   └── rom_de_conferencia.nes ← ROM esperada (ver abaixo)
└── build/               ← saída da compilação (gerada por você)
```

**Divisão de trabalho sugerida para o grupo:** quem faz a arte mexe em `gfx/` (NEXXT) ou nos `src/*.inc`;
quem programa mexe em `src/main.asm`. O `main.asm` não precisa mudar quando a arte muda.

---

## Aula 1 — Mapa mental: quem faz o quê

O NES tem **dois "cérebros"** que conversam por poucos registradores:

```text
            ┌──────────────────────────  CARTUCHO  ──────────────────────────┐
            │  PRG-ROM: código + dados (32 KB)      CHR-ROM: gráficos (8 KB)  │
            └─────────────┬───────────────────────────────────┬───────────────┘
                          │ barramento da CPU                 │ barramento da PPU
  ┌──────────────┐   ┌────▼────────────┐  $2000-$2007   ┌─────▼──────────────┐
  │  RAM  2 KB   │◄─►│   CPU  2A03     │───────────────►│   PPU  2C02        │──► TV
  │ $0000-$07FF  │   │ (6502 + áudio)  │   DMA  $4014   │ VRAM 2 KB (telas)  │
  └──────────────┘   └─────────────────┘───────────────►│ Paletas 32 B       │
                                                        │ OAM 256 B (sprites)│
                                                        └────────────────────┘
```

* **CPU (6502):** executa o *seu* código. **Não desenha nada.** Só consegue *escrever dados* na PPU.
* **PPU:** é a "placa de vídeo". Sozinha, 60 vezes por segundo, lê **tiles (CHR)**, **mapa (nametable)**,
  **cores (paleta)** e **sprites (OAM)** e monta a imagem de 256×240 pixels.
* **Cartucho:** guarda o programa (PRG) e os desenhos (CHR). No mapper 0 (NROM, o nosso), tudo é ROM fixa.

Por isso, "produzir gráficos" no NES significa **preparar dados nos formatos que a PPU entende** e
**entregá-los a ela** na hora certa. O resto da aula 1 é o caminho que seus arquivos percorrem:

```text
 NEXXT ─► tiles.chr / scene.nam / *.pal ─┐
                                         ├─► ca65 ─► main.o ─► ld65 (+ nes.cfg) ─► jogo.nes ─► Mesen
 seu código  src/main.asm ───────────────┘
   (assembler: texto → código de máquina)        (linker: coloca tudo nos endereços certos)
```

---

## Aula 2 — Bits, hexadecimal e a notação do ca65

Um byte tem 8 bits (0–255). Em gráficos de NES, **cada bit é um pixel (em um plano)**, então dominar
binário é obrigatório para quem faz a arte.

| Decimal | Hexa | Binário | Observação |
|---:|:---:|:---:|---|
| 0 | `$00` | `%00000000` | tile vazio |
| 8 | `$08` | `%00001000` | |
| 15 | `$0F` | `%00001111` | **cor preta segura** do NES |
| 128 | `$80` | `%10000000` | bit 7 ligado (ex.: NMI no `PPUCTRL`) |
| 255 | `$FF` | `%11111111` | 8 pixels ligados |

**Cada dígito hexa = 4 bits** (um *nibble*): `$A5` = `%1010 0101`. Decore `0–F` ↔ `0000–1111`.

### Notação do ca65

| Escrita | Significa | Exemplo |
|---|---|---|
| `$1F` | hexadecimal | `lda $1F` |
| `%1010` | binário | `.byte %11110000` |
| `31` | decimal | `ldx #31` |
| `#valor` | **imediato** (o próprio número) | `lda #$3F` → A recebe $3F |
| sem `#` | **endereço** (conteúdo da memória) | `lda $3F` → A recebe o byte que está em $003F |
| `<expr` / `>expr` | byte **baixo** / **alto** de 16 bits | `<$3F00` = `$00`, `>$3F00` = `$3F` |
| `;` | comentário até o fim da linha | |
| `nome:` | rótulo (endereço simbólico) | `reset:` |
| `@nome:` | rótulo **local** (vale até o próximo rótulo normal) | `@loop:` |
| `NOME = valor` | constante (não gera bytes) | `PPUCTRL = $2000` |
| `.byte`, `.word`, `.res` | dados: bytes, palavras de 16 bits, reservar espaço | |

> **A pegadinha nº 1 de quem começa:** esquecer o `#`. `lda #$10` carrega o número 16; `lda $10` carrega o
> **conteúdo do endereço** `$0010`. Parece quase igual, faz coisas totalmente diferentes.

### Montando valores de registradores com bits

O `PPUCTRL` ($2000) é um byte em que cada bit liga uma função. Em vez de decorar `$88`, o projeto nomeia os bits
(`src/nes.inc`) e combina com OR (`|`):

```asm
lda #(PPUCTRL_NMI | PPUCTRL_SPR_1000)   ; %10000000 | %00001000 = %10001000 = $88
sta PPUCTRL
```

Ligar o bit 7 (NMI) e o bit 3 (sprites usam a tabela de padrões em `$1000`). Os demais ficam 0.
Esse raciocínio — *"qual bit faz o quê"* — é o mesmo que você vai usar para ler tiles na Aula 6.

---

## Aula 3 — A CPU 6502 em 20 minutos

O NES usa o **Ricoh 2A03**: um núcleo MOS 6502 (≈ 1,79 MHz no NTSC) + circuito de áudio. É uma CPU de **8 bits**
com **endereços de 16 bits** (64 KB de espaço).

### 3.1 Registradores — a sua "bancada de trabalho"

| Reg. | Bits | Para quê | Dica |
|:---:|:---:|---|---|
| **A** | 8 | **Acumulador**: quase toda conta e toda carga/gravação passa por ele | só ele faz `ADC`, `AND`… |
| **X** | 8 | **Índice**: contador de laço, deslocamento em tabelas | `lda tabela,x` |
| **Y** | 8 | **Índice**: igual ao X, e usado no modo `(ptr),y` | `lda (ptr),y` |
| **SP** | 8 | **Ponteiro da pilha** (pilha vive em `$0100–$01FF`) | `ldx #$FF` / `txs` |
| **PC** | 16 | **Contador de programa**: endereço da próxima instrução | `jmp`, `jsr`, `rts` mexem nele |
| **P** | 8 | **Flags** (bandeirinhas de estado) | abaixo |

Flags do registrador **P** (`N V – B D I Z C`):

| Bit | Flag | Significa | Quem usa |
|:---:|:---:|---|---|
| 7 | **N** | resultado **negativo** (bit 7 = 1) | `bmi` / `bpl` |
| 6 | **V** | estouro com sinal | `bvs` / `bvc` |
| 5 | – | sempre 1 | |
| 4 | B | "break": só existe na cópia empilhada | |
| 3 | **D** | modo decimal | **sem efeito no NES** (veja abaixo) |
| 2 | **I** | 1 = ignora IRQ | `sei` / `cli` |
| 1 | **Z** | resultado **zero** | `beq` / `bne` |
| 0 | **C** | **carry** (vai-um / "maior ou igual" após `cmp`) | `bcc` / `bcs` |

> **Modo decimal:** o 2A03 tem a flag D, mas o circuito decimal foi **removido**: `ADC`/`SBC` são sempre binários,
> mesmo com `SED`. Por isso este projeto **não usa `SED` nem `CLD`** (muitos tutoriais colocam `CLD` por hábito de
> outros 6502; aqui é desnecessário).

### 3.2 As instruções que usamos (cada uma faz *uma* coisa pequena)

| Grupo | Instruções | O que fazem |
|---|---|---|
| Carregar | `lda` `ldx` `ldy` | registrador ← valor/memória (ajusta **N**, **Z**) |
| Guardar | `sta` `stx` `sty` | memória ← registrador (**não** mexe em flags) |
| Transferir | `tax` `tay` `txa` `tya` `txs` | copia entre registradores (`tya`: A←Y) |
| Contar | `inx` `iny` `dex` `dey` `inc` `dec` | +1 / −1 (nos registradores ou direto na memória) |
| Somar/subtrair | `adc` `sbc` | A ← A ± valor ± carry → **sempre** `clc` antes do `adc` e `sec` antes do `sbc` |
| Lógica de bits | `and` `ora` `eor` | máscara, liga bits, inverte bits |
| Comparar | `cmp` `cpx` `cpy` `bit` | só ajustam flags (não guardam resultado) |
| Desviar | `beq` `bne` `bcc` `bcs` `bpl` `bmi` `jmp` | pular se a condição valer / sempre |
| Sub-rotinas | `jsr` `rts` `rti` | chamar / voltar / voltar de interrupção |
| Pilha | `pha` `pla` | empilha / desempilha A |
| Sistema | `sei` `clc` `sec` `nop` | |

**Como ler uma comparação:** `cmp #10` calcula `A − 10` só para as flags. Depois:

| Quero saber se… | Use |
|---|---|
| A == 10 | `beq` (Z=1) |
| A != 10 | `bne` (Z=0) |
| A ≥ 10 (sem sinal) | `bcs` (C=1) |
| A < 10 (sem sinal) | `bcc` (C=0) |

### 3.3 Modos de endereçamento (o *mesmo* `lda` com jeitos diferentes de achar o dado)

| Modo | Sintaxe ca65 | Bytes | Ciclos* | O que acontece | Exemplo do projeto |
|---|---|:---:|:---:|---|---|
| Implícito | `inx` | 1 | 2 | sem operando | `inx` |
| Imediato | `lda #$3F` | 2 | 2 | A ← **o número** | `lda #HERO_Y_START` |
| **Zero Page** | `lda hero_x` | **2** | **3** | A ← byte em `$00xx` | `lda hero_dir` |
| Zero Page,X | `sta $00,x` | 2 | 4 | endereço = `$00xx + X` (não passa de `$FF`) | limpeza da RAM |
| Absoluto | `sta PPUDATA` | 3 | 4 | A ← byte no endereço de 16 bits | `sta $2007` |
| Absoluto,X / ,Y | `lda palette_data,x` | 3 | 4 (+1)† | endereço + X (ou Y) | cópia da paleta |
| **(zp),Y** | `lda (ptr),y` | **2** | 5 (+1)† | lê o ponteiro de 16 bits em `ptr`/`ptr+1`, soma Y | cópia da nametable |
| (zp,X) | `lda (ptr,x)` | 2 | 6 | indexa o ponteiro (não usamos) | |
| Relativo | `bne @loop` | 2 | 2 (+1/+2)‡ | PC ± 127 bytes | todos os desvios |

\* ciclos do `lda`/`sta` simples (não é igual para todas as instruções). † +1 se a soma cruza para outra página
(`$xxFF`→`$yy00`). ‡ +1 se o desvio é tomado, +1 se cruza página.

### 3.4 Zero Page: o recurso mais valioso do 6502

A **Zero Page** são os endereços `$0000–$00FF`. Como o byte alto é sempre `$00`, o código só precisa carregar
**1 byte de endereço** em vez de 2. Resultado, medido nesta ROM:

| Instrução | Zero Page | Absoluto | Economia |
|---|---|---|---|
| `inc hero_x` | `E6 03` → 2 B, 5 ciclos | `EE 03 00` → 3 B, 6 ciclos | 1 B + 1 ciclo **por uso** |
| `sta hero_x` | `85 03` → 2 B, 3 ciclos | `8D 03 00` → 3 B, 4 ciclos | idem |
| `lda (ptr),y` | só existe com ponteiro **na** Zero Page | — | obrigatório |

Regras práticas para o grupo:

1. **Guarde na Zero Page o que é usado o tempo todo:** posições, contadores, flags, ponteiros, temporários.
2. **Coloque fora dela o que é grande ou raro:** mapas de fase, buffers (a cópia da OAM em `$0200` *tem* que ser
   uma página inteira por causa do DMA).
3. **A Zero Page tem só 256 bytes** e o jogo inteiro divide isso. Anote um mapa de quem usa o quê.
4. **Declare ANTES de usar.** No ca65:

   ```asm
   .segment "ZEROPAGE"      ; segmento mapeado em $0000 pelo nes.cfg
   hero_x:  .res 1          ; reserva 1 byte (o assembler sabe que é endereço de Zero Page)
   ptr:     .res 2          ; 2 bytes: ponteiro de 16 bits
   ```

   Se o assembler encontrar o nome *depois* do uso, em instruções que têm as duas formas (`lda`, `sta`, `inc`…)
   ele escolhe a forma **absoluta** (3 bytes, +1 ciclo), porque ainda não sabe que o endereço cabe em 1 byte.
   O programa funciona, mas perde a otimização sem nenhum aviso — só o *listing* denuncia. Também é possível
   forçar o modo: `lda z:hero_x` (Zero Page) ou `lda a:hero_x` (absoluto).
5. **Confira no listing:** `ca65 -l build/main.lst …` mostra os bytes gerados. Opcodes de Zero Page: `A5` (lda),
   `85` (sta), `E6` (inc). Os de endereço absoluto: `AD`, `8D`, `EE`.

Neste projeto: **291 bytes de código e 6 bytes de Zero Page** (`ptr`, `nmi_ready`, `hero_x`, `hero_y`, `hero_dir`).

### 3.5 A pilha

A pilha ocupa `$0100–$01FF` e **cresce para baixo**. `jsr` empilha o endereço de retorno (2 bytes), `rts`
desempilha. Uma interrupção (NMI) empilha PC e P (3 bytes). `pha`/`pla` empilham/desempilham A.
Por isso, no reset fazemos `ldx #$FF` / `txs`: a pilha começa vazia no topo da página 1.

---

## Aula 4 — Mapas de memória: onde cada coisa mora

São **dois espaços de endereço diferentes**. Um erro clássico é confundir `$2000` da CPU (registrador da PPU) com
`$2000` da PPU (nametable).

### 4.1 Espaço da CPU (o que o seu código enxerga)

| Faixa | Tamanho | Conteúdo |
|---|---:|---|
| `$0000–$00FF` | 256 B | **Zero Page** |
| `$0100–$01FF` | 256 B | **Pilha** |
| `$0200–$02FF` | 256 B | convenção: **cópia da OAM** (`oam_buf`) para o DMA |
| `$0300–$07FF` | 1280 B | RAM geral |
| `$0800–$1FFF` | – | *espelhos* dos 2 KB de RAM (os mesmos bytes repetidos) |
| `$2000–$2007` | 8 B | **registradores da PPU** (espelhados até `$3FFF`) |
| `$4000–$4017` | – | APU e E/S — `$4014` = **OAM DMA**, `$4016/$4017` = controles |
| `$8000–$FFFF` | 32 KB | **PRG-ROM** (o seu programa) |
| `$FFFA–$FFFF` | 6 B | **vetores**: NMI (`$FFFA`), RESET (`$FFFC`), IRQ/BRK (`$FFFE`) |

### 4.2 Espaço da PPU (só acessível *através* de `$2006` + `$2007`)

| Faixa | Conteúdo |
|---|---|
| `$0000–$0FFF` | **Tabela de padrões 0** — 256 tiles × 16 bytes (CHR) |
| `$1000–$1FFF` | **Tabela de padrões 1** — outros 256 tiles |
| `$2000–$23BF` | **Nametable 0**: 960 bytes = 32 colunas × 30 linhas de números de tile |
| `$23C0–$23FF` | **Tabela de atributos** da nametable 0 (64 bytes) |
| `$2400–$27FF` | Nametable 1 (+ atributos em `$27C0`) |
| `$2800–$2BFF` / `$2C00–$2FFF` | Nametables 2 e 3 |
| `$3000–$3EFF` | espelho de `$2000–$2EFF` |
| `$3F00–$3F0F` | **Paletas de fundo** (4 paletas × 4 cores) |
| `$3F10–$3F1F` | **Paletas de sprite** (4 × 4) |
| `$3F20–$3FFF` | espelhos da área de paletas |

A **OAM** (sprites, 256 bytes) é uma memória *separada*, fora desse mapa, acessada por `$2003/$2004/$4014`.

Pontos que costumam pegar o iniciante:

* **Só existem 2 KB de VRAM para telas**, então só há 2 nametables "de verdade". As 4 do mapa são espelhadas
  conforme o cabeçalho iNES: **espelhamento vertical** (bit 0 do byte 6 = 1) faz `$2000=$2800` e `$2400=$2C00`
  — ideal para *scroll horizontal*. O projeto usa só `$2000`.
* **Espelho das paletas:** `$3F10`, `$3F14`, `$3F18`, `$3F1C` são **o mesmo byte** que `$3F00`, `$3F04`, `$3F08`,
  `$3F0C`. Por isso nas 32 cores do projeto, os bytes de índice 0 e 16 valem ambos `$21` (céu): se fossem
  diferentes, o último escrito venceria e mudaria a cor de fundo de **toda** a tela.
* **Cor 0 de qualquer paleta** = "sem cor": no fundo mostra a cor universal de `$3F00`; num sprite, é transparente.

---

## Aula 5 — Como o NES desenha a tela

### 5.1 O ritmo: quadros, scanlines e vblank

A PPU desenha a imagem linha por linha (*scanlines*), 60 vezes por segundo (NTSC):

```text
 linhas 0–239    imagem visível (a PPU lê VRAM/OAM sem parar → você NÃO pode mexer na VRAM agora)
 linha  240      pós-renderização
 linhas 241–260  VBLANK  ← ~2273 ciclos da CPU de "intervalo vertical": a janela segura para escrever
 linha  261      pré-renderização
        (1 quadro ≈ 29 780 ciclos da CPU)
```

* No início do vblank o bit 7 de `$2002` (PPUSTATUS) vira 1. Ler `$2002` o zera.
* Se o bit 7 de `$2000` (PPUCTRL) estiver ligado, a PPU também dispara uma **NMI** (interrupção não-mascarável):
  a CPU para o que estava fazendo e salta para o endereço em `$FFFA`.
* **Regra de ouro:** com a renderização ligada, só escreva em `$2006/$2007` **dentro do vblank** (na NMI). Com a
  renderização desligada (`$2001 = 0`), pode a qualquer hora. Por isso o `main.asm` copia paleta e nametable
  *antes* de ligar a PPU.
* **Orçamento do vblank:** ~2273 ciclos. O DMA da OAM sozinho gasta 513–514. Copiar a nametable inteira
  custa **~14 700 ciclos** (medido), cerca de metade de um quadro: só cabe com a tela desligada. Em jogo,
  atualiza-se poucos bytes por quadro.

### 5.2 Os 5 blocos de dados gráficos

| # | Bloco | Onde | Formato | Quem cria (na equipe) |
|:-:|---|---|---|---|
| 1 | **Tiles** (padrões, "CHR") | CHR-ROM (PPU `$0000–$1FFF`) | 8×8 px, **2 bits por pixel**, 16 bytes | arte (NEXXT: `.chr`) |
| 2 | **Nametable** (mapa) | VRAM `$2000…` | 960 bytes: *qual tile* em cada célula 8×8 | arte (NEXXT: `.nam`) |
| 3 | **Atributos** | VRAM `$23C0…` | 64 bytes: *qual paleta* em cada bloco 16×16 | arte (NEXXT: parte do `.nam`) |
| 4 | **Paletas** | VRAM `$3F00…` | 32 bytes: índices da paleta de 64 cores | arte (NEXXT: `.pal`) |
| 5 | **Sprites** (OAM) | RAM da PPU, 256 B | 64 sprites × 4 bytes | código (posição) + arte (tiles) |

**Pipeline de um pixel de fundo:** nametable diz *"nesta célula use o tile $02"* → o tile $02 diz *"este pixel é
o valor 2"* → a tabela de atributos diz *"esta região usa a paleta 1"* → a paleta 1, posição 2, diz *"cor $2A"* →
a PPU converte `$2A` em RGB. **Os tiles não têm cor**; têm só números de 0 a 3.

### 5.3 Limites que o artista precisa respeitar

| Limite | Valor |
|---|---|
| Resolução | **256 × 240** px (TVs NTSC cortam ~8 linhas em cima e embaixo — *overscan*) |
| Cores por pixel de um tile | **4** (valores 0–3) |
| Cores simultâneas na tela | **25** = 1 de fundo universal + 4×3 (fundo) + 4×3 (sprites) |
| Cores no total | **64** possíveis (várias repetidas/pretas); prefira `$0F` como preto — `$0D` pode dar problema em algumas TVs |
| Tiles disponíveis (mapper 0) | **256 por tabela × 2** tabelas = 512. O fundo lê de **uma** tabela (bit 4 do `PPUCTRL`) e os sprites 8×8 de **uma** tabela (bit 3); podem ser a mesma ou diferentes |
| **Fundo: paleta por região** | **16×16 px** (2×2 tiles) — *a regra que mais surpreende o artista* |
| Sprites | **64** no total, **8 por linha** de tela (os excedentes somem/piscam) |
| Sprite: paleta | 1 paleta de sprite para cada sprite 8×8 (ou 8×16) |

---

## Aula 6 — O tile em bits (a sua aula principal)

### 6.1 A regra

Um **tile** é um quadrado de **8×8 pixels**. Cada pixel vale **0, 1, 2 ou 3** (2 bits). Logo:

> 64 pixels × 2 bits = 128 bits = **16 bytes por tile**

Os 16 bytes **não** guardam os 2 bits de cada pixel juntos. Eles guardam **dois "planos"** (imagens de 1 bit):

```text
 bytes 0–7   = PLANO 0  → o bit BAIXO (bit 0) de cada pixel     (uma linha de 8 pixels por byte)
 bytes 8–15  = PLANO 1  → o bit ALTO  (bit 1) de cada pixel

 Dentro de cada byte:  bit 7 = pixel mais à ESQUERDA  …  bit 0 = pixel mais à DIREITA

 valor do pixel  =  (bit do plano 1) × 2  +  (bit do plano 0)
```

| plano 1 | plano 0 | valor do pixel | cor usada (índice na paleta) |
|:---:|:---:|:---:|---|
| 0 | 0 | **0** | cor 0 (fundo universal / transparente no sprite) |
| 0 | 1 | **1** | cor 1 |
| 1 | 0 | **2** | cor 2 |
| 1 | 1 | **3** | cor 3 |

### 6.2 Exemplo mínimo: uma linha de pixels

Tile `$08` do projeto (barras de cor). A linha, da esquerda para a direita: **`0 0 1 1 2 2 3 3`**.

```text
 pixel (valor):        0    0    1    1    2    2    3    3
 em binário (hi lo):  00   00   01   01   10   10   11   11
                      ││   ││   ││   ││   ││   ││   ││   ││
 plano 0 (bits "lo"):  0    0    1    1    0    0    1    1   →  %00110011 = $33
 plano 1 (bits "hi"):  0    0    0    0    1    1    1    1   →  %00001111 = $0F
```

As 8 linhas desse tile são iguais, então os 16 bytes são `33 33 33 33 33 33 33 33  0F 0F 0F 0F 0F 0F 0F 0F`.
E no código-fonte (`src/chr_bg.inc`) elas aparecem **como o desenho**:

```asm
    .byte %00110011        ; linha 0   pixels: 0 0 1 1 2 2 3 3      ← plano 0
    ; ... (mais 7 linhas iguais) ...
    .byte %00001111        ; linha 0   pixels: 0 0 1 1 2 2 3 3      ← plano 1
```

**Para ler ao contrário** (bytes → pixels), faça o caminho inverso: junte o bit 7 do plano 1 com o bit 7 do
plano 0 para o pixel 0; os bits 6 para o pixel 1; e assim por diante.

### 6.3 Exemplo completo: o coração (tile `$09`)

Desenhado com valores 0–3 (1 = contorno, 2 = corpo, 3 = brilho):

| linha | pixels | plano 0 | plano 1 | hexa (p0 p1) |
|:-:|---|:-:|:-:|:-:|
| 0 | `0 1 1 0 0 1 1 0` | `01100110` | `00000000` | `66 00` |
| 1 | `1 2 2 1 1 2 2 1` | `10011001` | `01100110` | `99 66` |
| 2 | `1 2 3 2 2 2 2 1` | `10100001` | `01111110` | `A1 7E` |
| 3 | `1 2 2 2 2 2 2 1` | `10000001` | `01111110` | `81 7E` |
| 4 | `0 1 2 2 2 2 1 0` | `01000010` | `00111100` | `42 3C` |
| 5 | `0 0 1 2 2 1 0 0` | `00100100` | `00011000` | `24 18` |
| 6 | `0 0 0 1 1 0 0 0` | `00011000` | `00000000` | `18 00` |
| 7 | `0 0 0 0 0 0 0 0` | `00000000` | `00000000` | `00 00` |

Confira a linha 2 sozinho: pixels `1 2 3 2 2 2 2 1` → bits baixos `1 0 1 0 0 0 0 1` = `%10100001` = `$A1`;
bits altos `0 1 1 1 1 1 1 0` = `%01111110` = `$7E`. ✔

Os 16 bytes em ordem no arquivo: `66 99 A1 81 42 24 18 00` **+** `00 66 7E 7E 3C 18 00 00`.

### 6.4 Onde o tile fica no arquivo `.chr`

```text
 deslocamento no arquivo = (tabela × 4096) + (número do tile × 16)

 tile $09 da tabela 0  →  0×4096 + 9×16   = 144  = $0090
 tile $00 da tabela 1  →  1×4096 + 0×16   = 4096 = $1000   (primeiro tile do herói)
 arquivo de 8192 bytes →  512 tiles (256 por tabela)
```

O projeto tem `tools/chr_dump.py`, que faz esse trabalho por você e **mostra o tile em bits** (use no
`gfx/tiles.chr` ou no arquivo que o NEXXT exportar):

```text
$ python tools/chr_dump.py gfx/tiles.chr '$09'
Tile $09 (tabela 0)   offset no arquivo = 9*16 + 0 = $0090
  linha   plano 0     plano 1    hexa   pixels (0-3)
   2     10100001  01111110   A1 7E   1 2 3 2 2 2 2 1
   ...
  16 bytes: 66 99 A1 81 42 24 18 00 00 66 7E 7E 3C 18 00 00
```

(Sem Python? Qualquer editor hexadecimal serve, por exemplo o HxD no Windows: vá ao *offset* `0x90` e leia 16
bytes. Ou veja o tile no **Tile Viewer do Mesen**, Aula 12.)

### 6.5 O que o tile NÃO tem: cor

O tile guarda só números 0–3. **Quem dá a cor é a paleta**, escolhida pela tabela de atributos (fundo) ou
pelo sprite. Veja no `docs/preview.png` os 4 blocos listrados: **são o mesmo tile `$08`**, desenhado com 4
paletas diferentes. O NEXXT faz a conversão cor ↔ valor 0–3 sozinho, mas você precisa saber disso para entender
porque "a mesma arte muda de cor".

### 6.6 Sprites 8×16 (para saber que existe)

Com o bit 5 do `PPUCTRL` ligado, cada sprite tem 8×16 pixels e usa **dois tiles consecutivos**; o bit 0 do
número do tile escolhe a tabela de padrões. Este projeto usa o modo comum 8×8 (um herói 16×16 = 4 sprites).

---

## Aula 7 — Cores: paletas e tabela de atributos

### 7.1 A paleta mestra (64 cores)

A PPU não guarda RGB: guarda **um número de 0 a $3F** que ela traduz para uma cor da "paleta mestra". Pense no
número como `linha:coluna` (`$LC`):

| Dígito da esquerda (L) = brilho | Dígito da direita (C) = matiz |
|---|---|
| `0` escuro · `1` médio · `2` claro · `3` pastel | `0` cinza · `1` azul · `2` azul-violeta · `3` violeta · `4` magenta · `5` rosa · `6` vermelho · `7` marrom/laranja · `8` oliva/amarelo · `9` verde-amarelo · `A` verde · `B` verde-água · `C` ciano · `D–F` preto/cinza |

Exemplos do projeto: `$21` azul-céu · `$30` branco · `$31` azul pálido · `$16` vermelho · `$17` marrom ·
`$27` laranja · `$37` creme · `$1A`/`$2A` verdes · `$0F` **preto seguro** (evite `$0D`).
O RGB exato varia conforme a paleta escolhida no emulador/NEXXT; o *número* é sempre o mesmo.

### 7.2 A RAM de paletas ($3F00–$3F1F): 8 paletas × 4 cores

```text
 $3F00  [ univ ][ c1 ][ c2 ][ c3 ]   ← fundo 0        $3F10  [ univ ][ c1 ][ c2 ][ c3 ]  ← sprite 0
 $3F04  [ (x)  ][ c1 ][ c2 ][ c3 ]   ← fundo 1        $3F14  [ (x)  ][ c1 ][ c2 ][ c3 ]  ← sprite 1
 $3F08  [ (x)  ][ c1 ][ c2 ][ c3 ]   ← fundo 2        $3F18  [ (x)  ][ c1 ][ c2 ][ c3 ]  ← sprite 2
 $3F0C  [ (x)  ][ c1 ][ c2 ][ c3 ]   ← fundo 3        $3F1C  [ (x)  ][ c1 ][ c2 ][ c3 ]  ← sprite 3

 (univ) = cor de fundo UNIVERSAL de $3F00 (a cor 0 de TODAS as paletas de fundo)
 (x)    = posição que não é usada para desenhar: no fundo, a cor 0 é sempre a universal;
          no sprite, a cor 0 é transparente
 $3F10/14/18/1C = espelhos de $3F00/04/08/0C → escreva o MESMO valor nos dois
```

No projeto (`src/palette.inc`):

```asm
palette_data:
    .byte $21,$30,$31,$11     ; fundo 0: céu/nuvem        (cor 0 = $21 azul-céu)
    .byte $21,$1A,$2A,$17     ; fundo 1: grama/terra
    .byte $21,$17,$27,$37     ; fundo 2: tijolo
    .byte $21,$16,$26,$36     ; fundo 3: vermelhos (coração)
    .byte $21,$0F,$16,$30     ; sprite 0: herói (preto, vermelho, branco)
    ...
```

### 7.3 A tabela de atributos: qual paleta em cada região de **16×16 pixels**

A nametable diz *qual tile*; a **tabela de atributos** (64 bytes, logo após os 960 da nametable) diz *qual
paleta de fundo (0–3)*. Cada byte cobre uma área de **4×4 tiles (32×32 px)** dividida em **quatro quadrantes de
2×2 tiles (16×16 px)**, 2 bits por quadrante:

```text
        byte de atributo  =  %DD CC BB AA
                              │  │  │  └─ AA (bits 1-0): quadrante superior ESQUERDO  (TL)
                              │  │  └──── BB (bits 3-2): quadrante superior DIREITO   (TR)
                              │  └─────── CC (bits 5-4): quadrante inferior ESQUERDO  (BL)
                              └────────── DD (bits 7-6): quadrante inferior DIREITO   (BR)

              ┌──────── 32 px ────────┐
              │  TL 16×16 │ TR 16×16  │      cada quadrante = 2×2 tiles = UMA só paleta
              ├───────────┼───────────┤
              │  BL 16×16 │ BR 16×16  │
              └───────────┴───────────┘
```

Para o tile na coluna `col` (0–31) e linha `row` (0–29):

```text
 índice do byte   = (row / 4) × 8 + (col / 4)                  (divisões inteiras)
 quadrante        = ((row mod 4) / 2) × 2 + ((col mod 4) / 2)   0=TL  1=TR  2=BL  3=BR
 deslocamento     = quadrante × 2                              (para onde os 2 bits ficam no byte)
```

**Exemplo 1 — os corações** (linha 1, colunas 2, 3 e 4, paleta 3 = vermelhos):

* colunas 2–3, linha 1 → byte `(1/4)×8 + (2/4) = 0`, quadrante `((1 mod 4)/2)×2 + ((2 mod 4)/2) = 1` (TR)
  → `3 << 2` = `%00001100` = **`$0C`**
* coluna 4 → byte 1, quadrante TL → `3 << 0` = `%00000011` = **`$03`**

É exatamente o que está na 1ª linha de atributos em `src/scene.inc`: `%00001100,%00000011,…`.

**Exemplo 2 — o chão.** Linhas 26 (grama) e 27 (terra) caem no *mesmo* quadrante vertical (linhas 26–27 =
metade inferior da faixa 24–27), então **precisam usar a mesma paleta** (a 1: verdes e marrom). Por isso a terra
usa uma cor da paleta da grama. Atributo: BL e BR = 1 → `%01010000` = `$50`, repetido nos 8 bytes dessa faixa.
Os tijolos (linhas 28–29) usam a paleta 2 nos quadrantes de cima da faixa seguinte → `%00001010` = `$0A`.

**Exemplo 3 — os quatro blocos listrados** (linhas 12–13): o mesmo tile `$08`, mudando só os 2 bits do
quadrante: paleta 0 (`$00`), 1 em TR (`$04`), 2 em TL (`$02`), 3 em TR (`$0C`).

> **Regra de ouro para o artista:** *dentro de cada bloco 16×16 só pode haver UMA paleta de fundo.* Se o desenho
> pede duas paletas numa mesma região de 16×16, redesenhe (ou mude a divisão dos tiles). O NEXXT tem uma
> ferramenta de verificação de atributos (*Attribute checker*, nome sujeito à versão) para achar violações.
> Sprites não têm essa limitação: cada sprite escolhe sua paleta.

---

## Aula 8 — Sprites e a OAM

### 8.1 Um sprite = 4 bytes

A OAM tem 256 bytes = **64 sprites × 4 bytes**:

| Byte | Campo | Significado |
|:-:|---|---|
| 0 | **Y** | posição vertical do topo **menos 1** (o sprite aparece em `Y+1`). Valores `≥ $EF` ficam fora da tela (escondidos) |
| 1 | **Tile** | número do tile (da tabela escolhida em `PPUCTRL` bit 3) |
| 2 | **Atributos** | `V H P - - - C C` |
| 3 | **X** | posição horizontal do lado esquerdo |

Byte de atributos: bit 7 `V` = espelhar vertical · bit 6 `H` = espelhar horizontal · bit 5 `P` = 1 atrás do
fundo · bits 1–0 `CC` = paleta de sprite (0–3).

### 8.2 O herói 16×16 (metasprite)

O herói são 4 sprites 8×8 (tiles `$00 $01 / $02 $03` da tabela 1), com deslocamentos fixos:

```text
   sprite 0 (tile $00)  (x+0, y+0)  │  sprite 1 (tile $01)  (x+8, y+0)
   ─────────────────────────────────┼─────────────────────────────────
   sprite 2 (tile $02)  (x+0, y+8)  │  sprite 3 (tile $03)  (x+8, y+8)
```

No código: duas tabelas pequenas (`hero_off_x: 0,8,0,8` e `hero_off_y: 0,0,8,8`) e um laço que soma
`hero_x/hero_y` ao deslocamento (veja `update_hero`). Os bytes na OAM (valores reais lidos da simulação, herói em x=134):

```text
 sprite 0:  BF 00 00 86      Y=191  tile=$00  atrib=0  X=134
 sprite 1:  BF 01 00 8E      X=142 (134+8)
 sprite 2:  C7 02 00 86      Y=199 (191+8)
 sprite 3:  C7 03 00 8E
```

### 8.3 A cópia sombra e o DMA

Escrever sprite a sprite em `$2003/$2004` é lento. O padrão é manter uma **cópia na RAM** (`oam_buf`, em `$0200`)
que o jogo altera à vontade, e a cada vblank mandar a página inteira de uma vez:

```asm
lda #$00
sta OAMADDR      ; começa no sprite 0
lda #>oam_buf    ; $02 = número da página da RAM
sta OAMDMA       ; $4014: copia $0200-$02FF para a OAM (CPU pausa ~513 ciclos)
```

Detalhes importantes:

* O DMA copia **uma página inteira**; por isso `oam_buf` ocupa os 256 bytes de `$0200` e **não** a Zero Page.
* Na inicialização, os 64 sprites são escondidos com `Y = $FE`. Se deixasse zero, 60 sprites inúteis apareceriam
  no canto superior esquerdo (Y=0, tile 0).
* **Antes de ligar a PPU**, o projeto já faz um DMA (de sprites escondidos): a OAM da PPU começa com lixo
  aleatório no power-on e, sem isso, apareceria "sujeira" por 1 quadro.
* **Limite de 8 sprites por linha:** se mais de 8 sprites cruzarem a mesma linha, os excedentes não são
  desenhados naquela linha (por isso personagens grandes "piscam" quando muitos ficam lado a lado).

---

## Aula 9 — Anatomia de um projeto ca65

### 9.1 O pipeline de compilação

```text
 src/main.asm ──(ca65)──► build/main.o ──(ld65 + nes.cfg)──► build/hello_chr.nes
   + nes.inc                 código de máquina                  ROM iNES final
   + *.inc                   com endereços "relativos"          + hello_chr.dbg (símbolos p/ Mesen)
                                                                + hello_chr.map (onde caiu cada segmento)
```

Os comandos reais (estão no `Makefile` e no `build.bat`):

```text
ca65 --cpu 6502 -g -I src -o build/main.o src/main.asm
ld65 -C nes.cfg -o build/hello_chr.nes --dbgfile build/hello_chr.dbg -m build/hello_chr.map build/main.o
```

| Opção | Para quê |
|---|---|
| `--cpu 6502` | só aceita instruções do 6502 original (o NES não tem as do 65C02) |
| `-g` | grava informação de depuração (nomes de rótulos, linhas) |
| `-I src` | pasta onde procurar os `.include` |
| `-D USE_NEXXT_FILES=1` | define um símbolo para a compilação condicional (`make nexxt`) |
| `-C nes.cfg` | arquivo de configuração do linker |
| `--dbgfile` | arquivo de símbolos para o Mesen — **use o mesmo nome base da ROM** (`hello_chr.nes` ↔ `hello_chr.dbg`) |
| `-m` | relatório de mapa de memória |

Para ver o código de máquina que o assembler gerou (ótimo para conferir Zero Page vs absoluto), acrescente a
opção de listagem ao `ca65`, por exemplo `-l build/main.lst` (em versões muito antigas do cc65 a sintaxe da
opção `-l` pode ser diferente; veja `ca65 --help`).

### 9.2 O cabeçalho iNES (16 bytes no começo do `.nes`)

O emulador lê estes 16 bytes para saber como montar o "cartucho". Em `src/main.asm`:

| Byte(s) | Valor | Significado |
|:-:|:-:|---|
| 0–3 | `4E 45 53 1A` | texto `NES` + `$1A` (assinatura) |
| 4 | `02` | PRG-ROM: 2 × 16 KB = **32 KB** |
| 5 | `01` | CHR-ROM: 1 × 8 KB = **8 KB** |
| 6 | `01` | bit 0 = espelhamento (1 = vertical) · bit 1 bateria · bit 2 trainer · bit 3 4 telas · bits 4–7 = mapper (parte baixa) |
| 7 | `00` | bits 4–7 = mapper (parte alta) → **mapper 0 (NROM)** |
| 8–15 | `00…` | não usados |

Conferência rápida: o arquivo deve ter **16 + 32768 + 8192 = 40 976 bytes**. Se o tamanho for outro, o emulador
rejeita a ROM ou mostra lixo.

### 9.3 Segmentos: como o código "escolhe" onde cada coisa vai

No `.asm`, `.segment "NOME"` diz "o que vier a seguir pertence ao segmento NOME". O `nes.cfg` diz **onde** cada
segmento vai parar. Resumo do `nes.cfg` deste projeto:

| Segmento (no .asm) | Vai para | Endereço | Conteúdo |
|---|---|---|---|
| `HEADER` | arquivo (início) | – | 16 bytes iNES |
| `ZEROPAGE` | RAM | `$0000…` | variáveis rápidas (não vai para o arquivo) |
| `OAM` | RAM | `$0200` | cópia dos sprites (alinhada em página) |
| `CODE` | PRG-ROM | `$8000…` | instruções |
| `RODATA` | PRG-ROM | logo após `CODE` | paletas, nametable, tabelas |
| `VECTORS` | PRG-ROM | **`$FFFA`** | endereços de NMI, RESET, IRQ |
| `CHR_BG` | CHR-ROM | PPU `$0000` | tiles do fundo |
| `CHR_SPR` | CHR-ROM | PPU `$1000` | tiles dos sprites |

Trechos que vale entender no `nes.cfg`:

```text
PRG:  file = %O, start = $8000, size = $8000, type = ro, fill = yes, fillval = $FF;
         └ %O = arquivo de saída       └ fill = preenche o que sobra até o tamanho total
VECTORS: load = PRG, type = ro, start = $FFFA;      ← força os 6 bytes finais da ROM
OAM:     load = OAMBUF, type = bss, align = $100;   ← garante endereço terminado em 00 (exigência do DMA)
CHR_SPR: load = CHR, type = ro, start = $1000, optional = yes;
```

Uma consequência prática para quem faz arte: **tile não declarado em `chr_*.inc` fica zerado** (o linker
preenche), então a tabela de padrões tem sempre 4 KB mesmo com poucos tiles desenhados.

### 9.4 Os vetores: as três "portas de entrada" da CPU

A CPU, ao ligar, lê o endereço guardado em `$FFFC` e começa a executar lá. Os outros dois cobrem interrupções:

```asm
.segment "VECTORS"
    .word nmi        ; $FFFA: início do vblank (se PPUCTRL bit 7 = 1)
    .word reset      ; $FFFC: ao ligar / apertar RESET
    .word irq        ; $FFFE: IRQ e instrução BRK
```

`.word nmi` grava o **endereço** (16 bits, little-endian: byte baixo primeiro) do rótulo `nmi`. Sem estes 6 bytes
corretos, a ROM não executa nada.

---

## Aula 10 — Passeio pelo `main.asm`

> Abra `src/main.asm` ao lado. **Todas as linhas já têm comentário** dizendo o que acontece com A, X e Y. Aqui
> está o *porquê* de cada bloco.

### 10.1 Linha do tempo de uma execução

```text
 ligar ─► reset ─► espera vblank #1 ─► limpa RAM ─► espera vblank #2
        ─► load_palettes ─► load_nametable ─► init_hero ─► variáveis do herói
        ─► espera vblank #3 ─► scroll=0 ─► DMA da OAM ─► PPUCTRL (NMI on) ─► PPUMASK (liga imagem)
        ─► laço principal: [espera NMI ─► move_hero ─► update_hero] repetindo
   NMI (60×/s, assíncrona): empilha A ─► DMA da OAM ─► nmi_ready=1 ─► desempilha A ─► RTI
```

(Medido na simulação: a imagem aparece no 3º quadro e o herói só no **5º**. O 1º NMI faz o DMA ainda com os
sprites escondidos; o primeiro `update_hero` só chega à PPU no NMI seguinte — a latência de 1 quadro entre
"calcular" e "ver" que você vai encontrar em todo jogo de NES.)

### 10.2 Bloco 1 — Inicialização (`reset`)

| Instrução(ões) | Por quê |
|---|---|
| `sei` | desliga IRQ: não usamos |
| `ldx #$40` / `stx APU_FRAME` | `$4017` bit 6 = 1: desliga o IRQ do contador de quadros do APU |
| `ldx #$FF` / `txs` | pilha vazia no topo de `$0100–$01FF` |
| `inx` | X volta a 0 (truque: `$FF + 1 = $00`) e já vira o zero para os próximos `stx` |
| `stx PPUCTRL` / `stx PPUMASK` / `stx DMC_FREQ` | NMI off, imagem off, IRQ do DMC off |
| `bit PPUSTATUS` / `bpl` (×2) | **espera 2 vblanks**: a PPU ignora `$2000/$2001/$2005/$2006` por ~29 658 ciclos após ligar |
| laço `@clear_ram` | a RAM liga com **conteúdo indefinido**; zera tudo e esconde os sprites (`$FE`) |

Sem **CLD**: no 2A03 o modo decimal não existe. O `BIT $2002` lê o bit 7 do PPUSTATUS para a flag **N**; por isso
o `bpl` ("branch if plus", N=0) significa "ainda não é vblank".

### 10.3 Bloco 2 — Copiar dados para a PPU

**Paletas** (`load_palettes`): `bit $2002` (zera o latch) → escreve `$3F` e depois `$00` em `$2006` (endereço
`$3F00`) → 32 vezes `lda tabela,x` / `sta $2007`. Cada escrita em `$2007` avança o endereço sozinha.

**Por que dois `sta $2006`?** É um registrador de 8 bits que recebe um endereço de 14 bits: o **1º** write é o
byte **alto**, o **2º** o **baixo**. Um "latch" interno alterna entre os dois; ler `$2002` o reinicia.
Se você esquecer o `bit PPUSTATUS`, o 1º write pode ser interpretado como o 2º e o endereço sai errado.

**Nametable** (`load_nametable`): usa o ponteiro `ptr` na Zero Page:

```asm
    lda #<scene        ; byte baixo do endereço do rótulo "scene"
    sta ptr
    lda #>scene        ; byte alto
    sta ptr+1
    ldx #4             ; 4 páginas de 256 bytes = 1024
    ldy #0
@copy:
    lda (ptr),y        ; lê da ROM: endereço = ptr (16 bits) + Y
    sta PPUDATA
    iny
    bne @copy          ; 256 voltas (Y: 0→255→0)
    inc ptr+1          ; próxima página
    dex
    bne @copy
```

Padrão clássico de dois laços aninhados: **Y** percorre os bytes de uma página, **X** conta as páginas. `(ptr),y`
é o *único* modo capaz de ler de um endereço de 16 bits que muda durante a execução — por isso `ptr` tem que
estar na Zero Page. Custo medido: ~14 700 ciclos (≈ metade de um quadro) → só com a imagem desligada.

### 10.4 Bloco 3 — O herói

* **`init_hero`** (executa 1 vez): escreve tile e atributo dos 4 sprites. O truque `tya` / `sta` usa o contador
  Y como número do tile (sprite 0 → tile 0 … sprite 3 → tile 3), e **X avança de 4 em 4** (quatro `inx`) porque
  cada sprite tem 4 bytes.
* **`move_hero`** (todo quadro): 1 pixel por quadro; a direção fica em `hero_dir`. Dois detalhes de eficiência:
  `inc`/`dec` agem **direto na memória** (sem passar por A) e **`dec` já ajusta a flag Z**, dispensando um `cmp #0`.
  Há um `rts` duplicado (mais barato que um `jmp @done`).
* **`update_hero`** (todo quadro): `X` = deslocamento em `oam_buf` (0, 4, 8, 12) e `Y` = nº do sprite (0–3) para
  indexar `hero_off_x/hero_off_y`. Note o `clc` antes de cada `adc`: **sempre** zere o carry antes de somar.

### 10.5 Bloco 4 — Ligar a imagem com segurança

```asm
@wait_vblank3:
    bit PPUSTATUS        ; espera mais um vblank
    bpl @wait_vblank3
    sta PPUSCROLL        ; (A = 0) scroll X = 0
    sta PPUSCROLL        ;          scroll Y = 0
    sta OAMADDR          ;          OAM começa em 0
    lda #>oam_buf
    sta OAMDMA           ; DMA inicial: sprites escondidos
    lda #(PPUCTRL_NMI | PPUCTRL_SPR_1000)
    sta PPUCTRL          ; liga NMI (sprites usam $1000, fundo $0000)
    lda #(PPUMASK_BG | PPUMASK_SPR | PPUMASK_BG_LEFT | PPUMASK_SPR_LEFT)
    sta PPUMASK          ; $1E: mostra fundo e sprites
```

* Por que esperar outro vblank? Ligar a renderização no meio de um quadro mostra lixo no primeiro quadro.
* Por que escrever o scroll? Os `sta $2006` da cópia mexem nos registradores internos de scroll da PPU; sem
  zerar o scroll, a imagem pode nascer deslocada.
* Por que o DMA antes? A OAM da PPU liga com lixo.
* Repare como **A vale 0 durante três `sta` seguidos**: reaproveitar o valor de A evita recarregar (2 ciclos cada).

### 10.6 Bloco 5 — O ritmo do jogo (NMI + laço principal)

```text
 laço principal:                               NMI (a cada vblank):
   espera nmi_ready != 0  ◄──── nmi_ready=1 ─────  pha ; DMA da OAM ; nmi_ready=1 ; pla ; rti
   nmi_ready = 0
   move_hero ; update_hero      (≈ 223 ciclos)      (≈ 550 ciclos, quase todos do DMA)
   volta a esperar
```

* O NMI só salva/restaura **A**, porque só usa A. Regra: *salve apenas o que você altera*. O teste automático
  desta aula confirmou que A, X, Y, SP e PC voltam idênticos após 400 NMIs, interrompendo o programa em qualquer ponto.
* O jogo escreve em `oam_buf` (RAM) à vontade; o **DMA no próximo NMI** leva tudo à PPU. Por isso o
  herói aparece 1 quadro "atrasado" em relação ao cálculo — comum e invisível.
* O orçamento: ≈ 550 ciclos de NMI + 223 do trabalho = ≈ 770 dos ~29 780 de um quadro. Sobra muito.

---

## Aula 11 — Do NEXXT à ROM

O **NEXXT Studio** (FrankenGraphics, sucessor do clássico *NES Screen Tool*) é o "Photoshop" do NES: ele
só deixa você desenhar o que o hardware aceita (4 cores por tile, paletas, atributos 16×16…) e exporta
**arquivos binários** que entram no projeto tal como estão.

> **Sobre os nomes de menu:** o NEXXT muda de aparência entre versões (a 3.7.7 reorganizou os menus de
> abrir/salvar binários e há uma opção de voltar à organização clássica). Os nomes abaixo seguem os
> guias públicos (menu **File → Patterns** para CHR, **File → Palettes** para paletas); se na sua versão estiverem
> em outro lugar, procure por *CHR/Patterns*, *Nametable* e *Palette* no menu **File**.

### 11.1 Os quatro arquivos que importam

| Arquivo | O que é | Tamanho esperado | Vai para… | No projeto |
|---|---|---:|---|---|
| `tiles.chr` | os tiles (as duas tabelas de padrões) | **8192 B** (ou 4096 B se for uma só tabela) | CHR-ROM | `gfx/tiles.chr` → segmento `CHR_BG` |
| `scene.nam` | nametable: 960 B de tiles **+ 64 B de atributos** | **1024 B** | PPU `$2000` | `gfx/scene.nam` → `scene:` |
| `bg.pal` | 4 paletas de fundo | **16 B** | PPU `$3F00` | `gfx/bg.pal` |
| `spr.pal` | 4 paletas de sprite | **16 B** | PPU `$3F10` | `gfx/spr.pal` |

**Confira sempre o tamanho** do arquivo exportado no explorador de arquivos. Se o `.nam` tiver 960 bytes, faltam
os atributos (cores erradas); se a paleta tiver 32 bytes, ela contém fundo + sprites juntos.

### 11.2 Receita

1. **Abra no NEXXT os arquivos deste projeto** para ver como é um projeto "pronto": *File → Patterns → Open CHR*
   (`gfx/tiles.chr`), *File → Palettes → Open palettes* (`gfx/bg.pal`, depois `gfx/spr.pal`), e abra
   `gfx/scene.nam` como nametable. Você verá o mesmo que no `docs/preview.png`.
2. **Desenhe** tiles (editor de pixels), escolha cores nas paletas (clique numa cor da paleta mestra), pinte a tela
   com os tiles. Mantenha em mente os limites da Aula 5.3 e a regra de 16×16 da Aula 7.3.
3. **Escolha as tabelas:** o NEXXT trabalha com o CHR de 8 KB dividido em duas metades de 4 KB (a interface pode
   chamá-las de "bancos" ou "tabelas"). **A metade que você usa para o fundo tem que ser a que o código manda a PPU ler
   para o fundo** (`PPUCTRL` bit 4) — neste projeto: fundo = 1ª metade (`$0000`), sprites = 2ª metade (`$1000`)
   (`PPUCTRL_SPR_1000`).
4. **Salve** CHR, nametable e paletas **nas mesmas pastas e com os mesmos nomes** de `gfx/`.
5. **Compile com os arquivos binários:**

   ```text
   make nexxt              (ou  build.bat nexxt  no Windows)      →  build/hello_chr_nexxt.nes
   ```

   Isso compila com `-D USE_NEXXT_FILES=1` (gerando arquivos próprios, `hello_chr_nexxt.*`, para não misturar
   com a versão de texto), o que troca, em `main.asm`, os `.include` de texto por:

   ```asm
   palette_data:
       .incbin "gfx/bg.pal"        ; 16 bytes
       .incbin "gfx/spr.pal"       ; 16 bytes  → juntas: 32 bytes contíguos
   scene:
       .incbin "gfx/scene.nam"     ; 1024 bytes
   .segment "CHR_BG"
       .incbin "gfx/tiles.chr"     ; 8192 bytes: as duas tabelas
   ```

   `.incbin` copia o arquivo, byte a byte, para dentro da ROM. Os caminhos são relativos à pasta onde você
   roda o `ca65` (a raiz do projeto).
6. **Rode no Mesen** e compare.

> **Prova de que os dois caminhos são equivalentes:** compilando com os `.inc` de texto e com os arquivos
> `gfx/*` (gerados dos mesmos dados), as duas ROMs ficam **idênticas byte a byte**. Ou seja, `chr_bg.inc` *é* o
> `tiles.chr`, só escrito de um jeito legível.

### 11.3 Quando usar o quê

| Situação | Melhor |
|---|---|
| Aprender / depurar / mexer em um tile de cada vez | editar o `.inc` em binário (você *vê* os bits) |
| Produzir arte de verdade, telas inteiras | NEXXT + `.incbin` |
| Reaproveitar um tile entre fundo e sprite | duplicá-lo nas duas tabelas (cada tabela é independente) |

### 11.4 Armadilhas que o NEXXT não impede

* **Mais de 256 tiles únicos numa tabela:** não cabe. O NEXXT avisa; otimize repetindo tiles.
* **Tile `$00`:** é conveniente que seja o "vazio" (tudo 0), porque a RAM da nametable começa zerada e o código
  usa `$00` como "sem nada".
* **Paletas fora de ordem:** o código copia **32 bytes seguidos** para `$3F00`; se `bg.pal` e `spr.pal` forem
  incluídos na ordem errada, os sprites ficarão com as cores do fundo.
* **Cor `$0D`:** preto "mais preto que preto"; use `$0F`.
* **Byte 16 ≠ byte 0 da paleta** (espelho!): a cor de fundo da tela inteira muda para a cor 0 do sprite 0.
  O NEXXT normalmente mantém a cor universal única; se editar à mão, confira.

---

## Aula 12 — Mesen: ver os bits funcionando

O Mesen é um emulador **com ferramentas de desenvolvedor**. Os nomes das janelas abaixo são os do **Mesen 2**,
menu **Debug**; no Mesen original (0.9.x) existem equivalentes com nomes ligeiramente diferentes (por exemplo
um *PPU Viewer* com abas). Se não achar um item, procure por *Viewer* no menu Debug.

| Janela | O que mostra | Use para |
|---|---|---|
| **Tile Viewer** | as tabelas de padrões (CHR) como figuras; escolha a paleta para colorir | conferir se seus tiles chegaram e na tabela certa (`$0000`/`$1000`) |
| **Tilemap Viewer** | as nametables como a PPU as monta (com a grade de atributos) | conferir o mapa e os blocos 16×16 de paleta |
| **Sprite Viewer** | os 64 sprites da OAM (X, Y, tile, atributos) | ver o herói, achar sprites perdidos |
| **Palette Viewer** | as 32 cores da RAM de paletas | conferir `palette_data` e o espelho `$3F10` |
| **Memory Viewer / Memory Tools** | RAM da CPU, memória da PPU (VRAM), OAM, CHR, PRG | ler os bytes crus (`$0200` = `oam_buf`, Zero Page = `hero_x`…) |
| **Debugger** | disassembly, registradores A/X/Y/SP/PC/flags, breakpoints, passo a passo | **acompanhar o que cada instrução faz com A, X e Y** |
| **Event Viewer** | quando cada escrita em `$2000–$2007` acontece no quadro | provar que você escreve só no vblank |

### 12.1 Receita de inspeção (5 minutos)

1. Abra `build/hello_chr.nes`.
2. **Tile Viewer:** veja a tabela `$0000` (10 tiles: `$00` vazio, tijolo, grama, terra, 4 da nuvem, barras e coração) e
   a tabela `$1000` (os 4 tiles do herói). Compare com `docs/chr_sheet.png`.
3. **Palette Viewer:** 16 cores de fundo e 16 de sprite. A primeira cor de cada uma das 4 paletas de fundo é `$21`
   (céu); nas de sprite aparecem `$0F`, `$16`/`$1A`/`$12`/`$28` e `$30`.
4. **Tilemap Viewer:** ligue a exibição de atributos/grade; veja a divisão em 16×16.
5. **Sprite Viewer:** 4 sprites ativos, o restante com Y=`$FE`.
6. **Memory Viewer** → CPU: vá para `$0000`: `hero_x` está em `$03` e aumenta a cada quadro; `$0200` mostra a OAM.

### 12.2 Receita de depuração passo a passo (para ver A, X e Y)

1. Compile com `-g` e `--dbgfile` (já é o padrão do Makefile). O arquivo `.dbg` deve ter **o mesmo nome base da
   ROM** (`hello_chr.nes` / `hello_chr.dbg`) e ficar na mesma pasta.
2. No Debugger do Mesen, carregue os símbolos (o Mesen 2 costuma carregar o `.dbg` sozinho; no Mesen original use
   *File → Workspace → Import labels* ou equivalente). Com isso aparecem nomes como `load_palettes` e
   `hero_x` no lugar de números, e dá para alternar para a **visão de código-fonte** (*source view*).
3. Coloque um **breakpoint** em `load_palettes` (clique na linha ou use a lista de breakpoints, endereço = o do
   rótulo; no `.map` gerado pelo `ld65` você vê o endereço).
4. Execute e use *Step Into* (passo a passo). Na janela de registradores observe **A, X, Y, SP, PC e as flags
   N V Z C** mudarem a cada instrução: é exatamente o que os comentários do `main.asm` descrevem.
5. Experimentos que ensinam muito:
   * Em `load_palettes`, veja **X** subir de 0 a 32 e **A** receber cada byte de `palette_data`.
   * Em `load_nametable`, veja **Y** completar 256 voltas, depois `ptr+1` (Zero Page `$01`) subir e **X** contar 4→0.
     (No projeto como entregue, `scene` está em `$814B`: `ptr` começa como `$4B`/`$81` e `ptr+1` termina em `$85`. Se
     você alterar o código, esses endereços mudam — consulte o `.map`.)
   * Em `update_hero`, veja **X** pular de 4 em 4 e **Y** de 1 em 1.
   * Altere `hero_x` direto na Memory Viewer e veja o herói teleportar.

> **Dica de ouro:** dependendo da versão, o Mesen permite **editar** tiles em tempo de execução (procure uma opção
> de editar tile no menu de contexto do Tile Viewer). Serve para experimentar, mas a edição **não é salva no arquivo
> `.chr`**: refaça a mudança no NEXXT ou no `.inc`.

---

## Aula 13 — Problemas comuns: sintoma → causa → correção

| Sintoma | Causa provável | Correção |
|---|---|---|
| Tela totalmente **preta** | NMI/PPUMASK não ligados; vetores errados; ROM com tamanho errado | confira `PPUMASK=$1E`, os 6 bytes finais (`.word nmi/reset/irq`) e o tamanho 40 976 |
| Tela de **uma cor só** | paleta não carregada, ou carregada com renderização ligada | `load_palettes` **antes** de ligar a PPU; confira no Palette Viewer |
| **Cores trocadas** (grama azul…) | atributo errado ou paleta fora de ordem | Tilemap Viewer com grade; confira a conta da Aula 7.3 |
| Cor de fundo muda depois de carregar sprites | byte 16 da paleta ≠ byte 0 (espelho `$3F10`) | igualar os dois valores |
| **Tiles errados** / desenhos "embaralhados" | tabela de padrões trocada (bit 3/4 do `PPUCTRL`) ou CHR deslocada | confira `PPUCTRL` e qual metade do CHR tem o fundo |
| Imagem **deslocada** / começa no meio | scroll não zerado após escrever em `$2006` | `bit $2002` + dois `sta $2005` (zeros) depois da cópia |
| **Lixo** na tela por 1 quadro ao ligar | PPU ligada no meio do quadro, ou sem DMA inicial da OAM | ligar a PPU dentro do vblank; DMA da sombra antes |
| 60 sprites **no canto superior esquerdo** | OAM zerada em vez de `$FE` | esconder com Y=`$EF…$FF` |
| Sprite aparece **1 pixel mais baixo** | o byte Y da OAM é "linha − 1" | normal; compense na constante inicial (`HERO_Y_START`) |
| Sprite some/pisca quando há vários na linha | limite de **8 sprites por scanline** | reduzir sprites na mesma linha / alternar a ordem |
| Escritas na VRAM "não pegam" | renderização ligada fora do vblank, ou nos primeiros ~29 658 ciclos | espere 2 vblanks no reset; escreva no NMI |
| Erro de faixa (*Range error*) em `lda (ptr),y` | `ptr` foi reservado **fora** da Zero Page (ex.: em RAM comum); o modo `(zp),y` só aceita endereço de 1 byte | reserve `ptr` em `.segment "ZEROPAGE"` |
| `Range error` no assembler | número maior que o campo (ex.: `lda #256`) | revise o valor / use `<` e `>` |
| ROM abre mas **trava** logo | `rts` sem `jsr` correspondente, pilha corrompida, `jmp` errado | conferir com o debugger; limpar a pilha só no reset |
| Mesen não mostra nomes (labels) | `.dbg` com nome diferente da ROM | `hello_chr.nes` ↔ `hello_chr.dbg` |
| `ld65: Segment ... overflows memory area` | dados maiores que o espaço do `nes.cfg` | revise tamanhos (32 KB PRG, 8 KB CHR) |

---

## Aula 14 — Exercícios e próximos passos

Faça na ordem; cada um mexe em *uma* coisa. Use o Mesen para conferir.

**Nível 1 — arte (só `src/*.inc` ou NEXXT)**
1. Mude a cor do herói: troque `$16` por outro valor na paleta de sprite 0 (`palette.inc`). Qual número dá azul?
2. Mude o atributo do herói de `0` para `1` em `init_hero` (`lda #$01`): ele fica verde sem mexer no tile.
3. **Desenhe um novo tile à mão:** em `src/chr_bg.inc`, no bloco "Tile $08" (barras), troque os 8 bytes do plano 0
   por um xadrez (`%10101010` e `%01010101` alternando linha a linha) e os 8 do plano 1 por zeros. Quais valores de
   pixel você vai ver? (Resposta: só 0 e 1.) Preveja o desenho **antes** de compilar e confira no Tile Viewer.
4. Desenhe uma estrela 8×8 no NEXXT, salve o `.chr`, use-a na nametable e rode `make nexxt`.

**Nível 2 — cores e atributos**
5. Faça a **nuvem da esquerda** (colunas 8–9, linhas 3–4) usar a paleta 3 (vermelha). Quais bytes da tabela de
   atributos mudam, e para quais valores? Faça a conta da Aula 7.3 *antes* de editar. Dica: a nuvem cruza a
   divisa entre duas faixas de 32 px, então não basta um byte.
   *(Gabarito, conferido na simulação: o byte de índice 2 vira `%00110000` — quadrante inferior esquerdo — e o
   de índice 10 vira `%00000011` — quadrante superior esquerdo. Com só um deles, metade da nuvem fica azul.)*
6. Troque a grama por tijolo mantendo a terra: o que acontece com as cores e por quê (regra 16×16)?

**Nível 3 — código**
7. Faça o herói andar **2 pixels** por quadro (duas mudanças pequenas em `move_hero`).
8. Faça o herói **espelhar** ao mudar de direção: bit 6 do atributo (`%01000000`) e **trocar** os tiles esquerdo/direito
   (`$00`↔`$01`, `$02`↔`$03`). Dica: o byte de atributos de cada um dos 4 sprites vale `0` ou `$40`.
9. Esconda o herói apertando um botão: leia o controle 1 em `$4016` (estude a rotina de leitura: *strobe* em
   `$4016` e 8 leituras).
10. **Animação:** crie um 2º quadro de animação em outros 4 tiles e alterne a cada 8 quadros usando um contador
    na Zero Page (`frame_cnt`).

**Próximos passos de estudo:** leitura de controle, colisão com o fundo (consultar a nametable), scroll
(`$2005`, vários nametables), sprite 0 hit, música/efeitos no APU, mapeadores com *bank switching* (CHR maior),
compressão RLE de telas.

---

## Apêndice A — Registradores da PPU (cola)

| Endereço | Nome | R/W | Bits / uso |
|---|---|:-:|---|
| `$2000` | **PPUCTRL** | W | `V P H B S I N N` — **V** NMI on · **H** sprites 8×16 · **B** fundo usa `$1000` · **S** sprites usam `$1000` · **I** incremento (0: +1, 1: +32) · **NN** nametable base (0=`$2000` … 3=`$2C00`) |
| `$2001` | **PPUMASK** | W | `B G R s b M m g` — **s** mostrar sprites (`%00010000`) · **b** mostrar fundo (`%00001000`) · **M** sprites nos 8 px da esquerda · **m** fundo nos 8 px da esquerda · **g** tons de cinza · **R G B** ênfase de cor |
| `$2002` | **PPUSTATUS** | R | `V S O – – – – –` — **V** vblank (zera ao ler) · **S** sprite 0 hit · **O** overflow de sprites. Ler também reinicia o latch de `$2005/$2006` |
| `$2003` | OAMADDR | W | endereço inicial na OAM |
| `$2004` | OAMDATA | R/W | byte da OAM (lento: prefira o DMA) |
| `$2005` | **PPUSCROLL** | W×2 | 1ª escrita: scroll X · 2ª: scroll Y |
| `$2006` | **PPUADDR** | W×2 | 1ª escrita: byte **alto** · 2ª: byte **baixo** do endereço da VRAM |
| `$2007` | **PPUDATA** | R/W | dado da VRAM; endereço avança +1 ou +32 (`PPUCTRL` bit 2) |
| `$4014` | **OAMDMA** | W | página da RAM (`$XX` → copia `$XX00–$XXFF`) para a OAM; ~513 ciclos |

Receita universal para escrever na VRAM (com a imagem desligada ou no vblank):

```asm
    bit PPUSTATUS      ; reinicia o latch
    lda #>ENDERECO     ; byte alto
    sta PPUADDR
    lda #<ENDERECO     ; byte baixo
    sta PPUADDR
    ; ... agora cada  sta PPUDATA  grava um byte e avança o endereço
```

## Apêndice B — Glossário

| Termo | Significado |
|---|---|
| **CHR** | dados gráficos (tiles); ROM no cartucho |
| **PRG** | programa (código + dados) do cartucho |
| **Tile** | quadrado 8×8 px, 2 bits por pixel, 16 bytes |
| **Pattern table** | tabela de 256 tiles (4 KB); são 2 (`$0000` e `$1000`) |
| **Nametable** | mapa 32×30 de números de tile (960 B) |
| **Attribute table** | 64 B que escolhem a paleta de cada bloco 16×16 |
| **OAM** | memória de 64 sprites × 4 bytes |
| **DMA** | cópia automática da RAM para a OAM (`$4014`) |
| **vblank** | intervalo vertical: janela segura para mexer na VRAM |
| **NMI** | interrupção disparada pela PPU no início do vblank |
| **Zero Page** | endereços `$0000–$00FF`: acesso mais curto e rápido |
| **Mapper** | circuito do cartucho para trocar bancos; **mapper 0 (NROM)** não troca nada |
| **Segmento** | bloco nomeado do código/dados que o linker posiciona |
| **iNES** | formato de arquivo `.nes` (cabeçalho de 16 bytes + PRG + CHR) |

## Apêndice C — Instruções por ciclos (as mais usadas)

| Instrução | Imediato | Zero Page | ZP,X | Absoluto | Abs,X / Abs,Y | (zp),Y |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| `lda` | 2 | **3** | 4 | 4 | 4 (+1) | 5 (+1) |
| `sta` | – | **3** | 4 | 4 | 5 | 6 |
| `ldx` / `ldy` | 2 | **3** | 4 | 4 | 4 (+1) | – |
| `inc` / `dec` | – | **5** | 6 | 6 | 7 | – |
| `adc` / `sbc` / `and` / `ora` / `cmp` | 2 | **3** | 4 | 4 | 4 (+1) | 5 (+1) |

Implícitas (`inx`, `iny`, `tax`, `clc`…): 2 · `bne/beq…`: 2 (+1 se tomado, +1 se cruzar página) ·
`jsr`: 6 · `rts`: 6 · `rti`: 6 · `jmp`: 3 · `pha`: 3 · `pla`: 4 · NMI (entrada): 7.

## Apêndice D — Referências

* Manual do ca65 (diretivas, expressões): <https://cc65.github.io/doc/ca65.html>
* Manual do ld65 (formato do `nes.cfg`): <https://cc65.github.io/doc/ld65.html>
* Wiki NESdev (hardware do NES, em inglês): <https://www.nesdev.org/wiki/>
* NEXXT Studio: <https://frankengraphics.itch.io/nexxt>
* Mesen 2: <https://github.com/SourMesen/Mesen2>
* NES Starter Kit — guia que usa NEXXT e Mesen em um projeto ca65: <https://nes-starter-kit.nes.science/>

---

## Limites da verificação

Seja crítico com este material como o seria com qualquer fonte. O que foi e o que **não** foi verificado:

**Verificado (executado):**

* O código foi **montado, linkado e executado** num simulador de verificação escrito para este projeto
  (mini-montador do subconjunto de ca65 que o projeto usa + linker que lê o seu `nes.cfg` + CPU 6502 + PPU
  simplificada). Resultados: ROM de 40 976 bytes com cabeçalho e vetores corretos; imagem (`docs/preview.png`)
  com fundo, atributos, paletas e herói; herói percorre 0–240 nos dois sentidos; o NMI preserva A, X, Y, SP e PC
  em 400 interrupções; nenhuma escrita na VRAM com a imagem ligada fora do vblank.
* Todas as variáveis da Zero Page geram instruções de 2 bytes (`85 03`, `A5 02`, `E6 03`, `B1 00`…).
* Não há `SED`/`CLD`; todas as 139 instruções de `main.asm` têm comentário que cita A, X ou Y.
* Compilar com `.inc` de texto e com `.incbin` dos arquivos de `gfx/` gera ROMs **idênticas**.
* Os bytes do coração, das barras e da OAM que aparecem nas aulas foram extraídos do próprio projeto.

**NÃO verificado (por favor, confirme na sua máquina):**

* O **`ca65`/`ld65` reais e o Mesen não estavam disponíveis** no ambiente onde este material foi preparado
  (sem acesso à rede). O simulador é uma ferramenta própria e **não é** um substituto: ele aceita só as
  diretivas que o projeto usa, e eu as escolhi por serem básicas e conhecidas, mas a primeira compilação real é o
  teste definitivo. Se o `ca65`/`ld65` apontarem um erro, **copie a mensagem completa** (arquivo e linha) — é
  fácil de corrigir.
* A **precisão do simulador** é limitada (não modela sprite 0, timing exato de dot, glitches de PPU). Para o que
  o projeto faz, é suficiente; não use o resultado como prova de comportamento em hardware real.
* **Menus do NEXXT e do Mesen** mudam entre versões; os nomes foram tirados de guias públicos e podem diferir.
* As cores do `docs/preview.png` usam uma paleta aproximada; no Mesen os tons serão ligeiramente diferentes.
