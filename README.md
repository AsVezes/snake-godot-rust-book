# Godot 4 + Rust — código complementar do livro Snake 2D

**Livro:** *Godot 4 + Rust: construa um Snake 2D passo a passo* (PT-BR)  
**Autor:** Elliot Veyran · **Selo:** As Vezes

Este repositório público disponibiliza o **código complementar** do livro: **16 checkpoints**, um laboratório independente de Rust para as preparações R1/R2, **6 patches de transição** e ferramentas de verificação. São fontes para acompanhar e comparar as etapas, não binários prontos.

## Obter o material

Use **Code → Download ZIP** nesta página e extraia o pacote. Leia o [guia PT-BR](README_PTBR.md) ou o [English reader guide](README_ENUS.md), que explicam as pastas, a continuidade do mesmo projeto e os comandos para cada edição. Alternativamente, clone o repositório com Git. O [MANIFEST.json](MANIFEST.json) registra a revisão de código e os hashes Git dos arquivos.

- [16 checkpoints](codigo/checkpoints/) — cada etapa é uma referência independente.
- [Laboratório Rust R1/R2](codigo/labs/snake_rust_lab/) — soluções de apoio, não substitui exercícios.
- [Patches de transição](codigo/transicoes/) — opcionais, conforme o texto do livro.
- [Ferramenta de verificação](codigo/tools/book_checkpoints.py).

**Importante:** o leitor desenvolve sempre o mesmo jogo em `meu-snake/`; não substitua seu projeto inteiro pela pasta de um checkpoint. A partir do 03, instale Rust/Cargo e compile a crate da etapa ou do seu próprio projeto. Os primeiros dois checkpoints são exclusivamente Godot.

## Licenciamento

O **código original** tem licença [MIT](LICENSE). Materiais e dependências de terceiros permanecem sob suas próprias licenças. A licença **não se estende** ao conteúdo do eBook ou à arte da capa; este repositório não inclui bibliotecas compiladas ou a engine Godot.

## Proveniência

Seleção controlada do código de referência da edição PT-BR. Revisão de origem (somente identificação dos fontes): `39fdbfe4754dc05edd9409831802feb48c1d5acf`. Os arquivos deste repositório têm seu próprio histórico Git e não expõem a documentação privada de produção.
