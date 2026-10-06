# Fontes das 3 cidades

Esta pasta recebe os arquivos originais usados pelo merge automatico do Blender:

- `City 1.blend`
- `City 2(2).blend`
- `city cyles.zip`

Ao receber esses tres arquivos na branch `main`, o workflow **Merge 3 Cities** executa automaticamente e gera:

- `MAIN_CITY_3_CIDADES.blend`
- `MAIN_CITY_3_CIDADES.glb`

O merge mantem escala e rotacao originais, organiza em `CITY_1`, `CITY_2` e `CITY_3`, posiciona as cidades lado a lado e tenta alinhar estradas de borda usando somente translacao X/Y/Z.
