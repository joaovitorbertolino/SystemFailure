@echo off
rem ============================================================================
rem  build.bat - compila o projeto no Windows (precisa de ca65 e ld65 no PATH)
rem
rem  Uso:   build.bat           usa os .inc de texto (src\)      -> build\hello_chr.nes
rem         build.bat nexxt     usa os arquivos do NEXXT em gfx\ -> build\hello_chr_nexxt.nes
rem ============================================================================

if not exist build mkdir build

set NAME=hello_chr
set DEFS=
if /I "%1"=="nexxt" set NAME=hello_chr_nexxt
if /I "%1"=="nexxt" set DEFS=-D USE_NEXXT_FILES=1

rem 1) montar: .asm -> .o
ca65 --cpu 6502 -g -I src %DEFS% -o build\%NAME%.o src\main.asm
if errorlevel 1 goto erro

rem 2) linkar: .o + nes.cfg -> .nes   (o .dbg tem o mesmo nome da ROM: o Mesen acha sozinho)
ld65 -C nes.cfg -o build\%NAME%.nes --dbgfile build\%NAME%.dbg -m build\%NAME%.map build\%NAME%.o
if errorlevel 1 goto erro

echo.
echo Pronto: build\%NAME%.nes   (abra no Mesen)
goto fim

:erro
echo.
echo FALHOU. Leia a primeira mensagem de erro acima (arquivo e numero da linha).

:fim
