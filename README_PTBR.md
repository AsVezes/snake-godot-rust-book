# Código complementar — Godot 4 + Rust: construa um Snake 2D passo a passo

Este pacote contém arquivos-fonte didáticos, 16 checkpoints, seis patches de
transição e o laboratório Rust opcional das preparações R1/R2. **Você
constrói um único jogo em `meu-snake/`**; os checkpoints são referências
independentes para comparação e diagnóstico, não pastas para substituir
seu trabalho a cada capítulo.

1. Extraia o ZIP preservando a estrutura `codigo/`; confira `MANIFEST.json`
   e `LICENSE.txt`.
2. Instale as ferramentas indicadas no Apêndice C do livro.
3. No capítulo 01, crie seu **próprio** projeto Godot em `meu-snake/godot/`
   e monte a cena conforme o texto. O checkpoint 01 serve para conferir.
4. No capítulo 02, abra **a mesma pasta** e evolua a cena. A partir do 03,
   crie `meu-snake/rust/` ao lado de `godot/` e compile **a sua crate**
   antes de abrir o Godot. Mantenha coerentes nome da crate e caminhos
   `Snake.gdextension`; patches são opcionais conforme cada capítulo.
5. A partir do capítulo 09, **preserve `godot/project.godot: config/name`**:
   mudar o nome pode redirecionar os arquivos do jogador em `user://`.
   Nos patches 09→10, 10→11 e 11→12, use
   `git apply --check --exclude=godot/project.godot` antes de
   `git apply --exclude=godot/project.godot`, conforme capítulo e
   Apêndice C (PowerShell no Windows). Nunca force um patch incompatível.
6. Em caso de erro, consulte o capítulo e o Apêndice B. O comando
   `codigo/tools/book_checkpoints.py` testa **referências independentes**,
   não valida automaticamente o `meu-snake/` montado pelo comprador.

O pacote contém fontes, não binários nem instaladores. A exportação é
ensinada no capítulo 16 e depende de ferramentas do seu sistema.

## Licenças e componentes de terceiros

A licença MIT em `LICENSE.txt` cobre o código original disponibilizado
por Elliot Veyran. As crates e o motor usados para compilar o jogo possuem
suas próprias licenças: godot-rust (`godot` 0.5.5) usa MPL-2.0;
`rusqlite` 0.37.0 e `libsqlite3-sys` 0.35.0 usam MIT; o código principal
de SQLite é de domínio público; o Godot Engine utiliza MIT.
Consulte: https://github.com/godot-rust/gdext ,
https://github.com/rusqlite/rusqlite e https://godotengine.org/license/ .
Este ZIP não inclui binários do motor nem cópias das dependências baixadas
pelo Cargo. Distribuir um executável exige verificar também os avisos
de copyright, textos das licenças e demais componentes realmente incluídos.
Esta lista é orientação para a edição, não um inventário jurídico exaustivo.
