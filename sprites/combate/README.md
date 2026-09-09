# Sprites do combate — Aula 06

Quatro personagens para a fase de combate: um jogador e três zumbis.

## Como cada arquivo está montado

Uma **tira horizontal por animação**, no mesmo formato das folhas do pinguim que você já usou.
Cada personagem tem a sua célula, e **todas as animações dele usam a mesma** — é o que impede o
sprite de pular de tamanho ao trocar de estado.

| Personagem | Célula | Animações |
|---|---|---|
| `sobrevivente` | 68 × 64 | `idle` 8 · `walk` 8 · `run` 8 · `jump` 7 · `attack` 7 · `hurt` 7 · `death` 7 |
| `zumbi_lento` | 70 × 67 | `idle` 8 · `walk` 8 · `attack` 6 · `hurt` 7 · `death` 7 |
| `zumbi_rapido` | 70 × 67 | `idle` 8 · **`run` 8** · `attack` 6 · `hurt` 7 · `death` 7 |
| `zumbi_grande` | 71 × 68 | `idle` 8 · `walk` 8 · `attack` 7 · `hurt` 7 · `death` 7 |

O `sprite.json` de cada pasta repete essa informação, para consulta rápida.

**O zumbi rápido tem `run`, não `walk`.** Não é descuido: no script do zumbi o nome da animação vem
da variável exportada `animacao_de_andar`, e é justamente esse caso que mostra por que o nome não
pode ficar escrito dentro da máquina de estados.

## Como usar na Godot

No `AnimatedSprite2D`, para cada animação:

1. **Add frames from Sprite Sheet** e escolha o arquivo, por exemplo `walk.png`.
2. Na janela que abre, informe **Horizontal = número de quadros** e **Vertical = 1**. O número está
   na tabela acima.
3. Confirme.

Depois, no painel de animação, **desmarque o loop em `attack`, `hurt` e `death`**. As três precisam
terminar:

- o `attack` do jogador sai do estado quando a animação acaba — em loop, ele ataca para sempre;
- o `death` do zumbi tem um `await` antes de remover o nó — em loop, o zumbi nunca some da fase.

## Uma direção só, de propósito

Cada tira traz **apenas o personagem virado para a direita**. A esquerda não é outro arquivo: é
`anim.flip_h = true` no código. Duas direções, um conjunto de sprites.

## De onde vieram

Gerados na PixelLab e importados com normalização: as animações saem do app em células de tamanhos
diferentes (no zumbi lento vieram 64, 88 e 92), e aqui foram levadas todas para a mesma célula,
**ancoradas pelo pé** do primeiro quadro de cada animação — a base, e não o centro, porque é o pé
que toca o chão e precisa ficar parado quando o estado troca.

O `jump` do sobrevivente veio depois dos outros, em três quartos (`south-east`), e foi encaixado na
mesma célula 68 × 64 pela mesma âncora. No quadro do ápice, 7 pixels do topo do cabelo ficaram de
fora — a alternativa era aumentar a célula e obrigar a reimportar as outras seis animações.

O sobrevivente veio em vista lateral pura, com essa exceção. Os zumbis vieram em três quartos, virados para a direita:
a silhueta lê bem em movimento, mas se um dia forem regerados, vale pedir perfil puro para casar
melhor com o jogador.
