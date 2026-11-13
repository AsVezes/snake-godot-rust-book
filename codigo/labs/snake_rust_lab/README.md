# Laboratório Rust — Preparações R1/R2

Este laboratório é o gabarito independente das Preparações R1 e R2 do livro.
Comece tentando os exercícios no projeto de estudos que você construiu;
consulte estes arquivos somente para conferir a solução e os testes.

Na pasta `codigo/labs/snake_rust_lab/`, com Rust e Cargo instalados:

```sh
cargo fmt --all -- --check
cargo test
cargo clippy --all-targets -- -D warnings
```

O módulo `src/lib.rs` contém `Cell`, `Direction`, `moved`, `LabSnake`,
`parse_score`, os exercícios `is_vertical`, `is_inside`, `length` e oito
testes de referência. Ele não contém Godot nem substitui o jogo acumulado
em `meu-snake/`. Para conferir sua própria solução, execute os comandos
na sua pasta de exercícios e compare os resultados com esta referência.

A licença do código original acompanha o pacote em `LICENSE.txt`.
Dependências externas eventualmente instaladas têm suas próprias licenças.
