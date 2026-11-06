#!/usr/bin/env python3
"""
chr_dump.py - mostra tiles de um arquivo .chr (o que o NEXXT exporta) "em bits".

Para cada tile imprime:  plano 0 | plano 1 (em binário e hexa) | os pixels como números 0-3.
Isso é a Aula 6 do tutorial em forma de ferramenta: serve para conferir se a arte exportada
tem o formato esperado e para entender como pixels viram bytes.

Uso:
    python tools/chr_dump.py gfx/tiles.chr 9              tile $09 da tabela de padrões 0
    python tools/chr_dump.py gfx/tiles.chr 0-9            faixa de tiles ($00 a $09)
    python tools/chr_dump.py gfx/tiles.chr 0-3 --bank 1   tiles $00-$03 da tabela 1 (offset $1000)
    python tools/chr_dump.py gfx/tiles.chr '$08'          aceita decimal, $hex ou 0xhex
    python tools/chr_dump.py gfx/tiles.chr --info         só o resumo do arquivo
"""
import sys, argparse


def num(s):
    s = s.strip()
    if s.startswith('$'):
        return int(s[1:], 16)
    return int(s, 0)


def tiles_from(spec):
    if '-' in spec[1:]:
        a, b = spec.split('-', 1)
        return range(num(a), num(b) + 1)
    return [num(spec)]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('arquivo')
    ap.add_argument('tiles', nargs='*', help="número ou faixa (ex.: 9, 0-9, $08)")
    ap.add_argument('--bank', type=int, default=0, choices=(0, 1), help="tabela de padrões: 0 = $0000, 1 = $1000")
    ap.add_argument('--info', action='store_true')
    args = ap.parse_args()

    data = open(args.arquivo, 'rb').read()
    print("arquivo: %s  tamanho: %d bytes = %d tiles" % (args.arquivo, len(data), len(data) // 16))
    if len(data) == 8192:
        print("         8 KB = duas tabelas de padrões (tabela 0 em $0000 + tabela 1 em $1000): é o que o cabeçalho iNES deste projeto espera")
    elif len(data) == 4096:
        print("         4 KB = UMA tabela de padrões (256 tiles)")
    else:
        print("         ATENÇÃO: tamanho incomum; o esperado é 4096 ou 8192 bytes")
    if args.info or not args.tiles:
        return

    for spec in args.tiles:
        for t in tiles_from(spec):
            off = args.bank * 0x1000 + t * 16
            if off + 16 > len(data):
                print("tile $%02X da tabela %d está fora do arquivo" % (t, args.bank))
                continue
            p0, p1 = data[off:off + 8], data[off + 8:off + 16]
            print()
            print("Tile $%02X (tabela %d)   offset no arquivo = %d*16 + %d = $%04X" % (t, args.bank, t, args.bank * 0x1000, off))
            print("  linha   plano 0     plano 1    hexa   pixels (0-3)")
            for y in range(8):
                pix = ''.join(str((((p1[y] >> (7 - x)) & 1) << 1) | ((p0[y] >> (7 - x)) & 1)) for x in range(8))
                print("   %d     %s  %s   %02X %02X   %s" % (
                    y, format(p0[y], '08b'), format(p1[y], '08b'), p0[y], p1[y], ' '.join(pix)))
            print("  16 bytes: " + ' '.join('%02X' % b for b in data[off:off + 16]))


if __name__ == '__main__':
    main()
