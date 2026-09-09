extends CharacterBody2D

## O zumbi — Aula 06
##
## Compare este arquivo com o jogador.gd, lado a lado. O enum, o status, o
## match e as go_to_* são os mesmos. **A máquina de estados não sabe se quem
## decide é uma pessoa no teclado ou o próprio jogo** — e é por isso que ela
## serve para os dois.
##
## A única diferença de fundo: no jogador a troca de estado vem do Input; aqui
## vem da distância até o jogador.
##
## Os três tipos de zumbi (lento, rápido e grande) usam ESTE script. O que muda
## entre eles são os @export, ajustados no Inspetor de cada cena.


enum ZumbiState { idle, chase, attack, hurt, death }

var status: ZumbiState


# ---------------------------------------------------------------------------
# Nós da cena
# ---------------------------------------------------------------------------

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
# O alcance do golpe. O deslocamento tem que estar NESTE nó, não no colisor
# filho: a linha que espelha a área faz abs(position.x), e abs(0) é 0.
@onready var area_ataque: Area2D = $AreaAtaque


# ---------------------------------------------------------------------------
# O que diferencia um zumbi do outro
#
# Este bloco é a aula inteira resumida: três inimigos com comportamentos
# distintos, um script só. Nada aqui está escrito no meio do código.
# ---------------------------------------------------------------------------

@export var vida_maxima: int = 3
@export var velocidade: float = 40.0
@export var dano: int = 1

# Cuidado com as duas distâncias, porque elas dependem de outras coisas:
#  - a visão precisa caber na tela (288 px), senão ele persegue antes de aparecer;
#  - a área de ataque precisa alcançar `distancia_de_ataque - 12`, senão ele
#    ataca no vazio para sempre, com a animação tocando certinho.
@export var distancia_de_ataque: float = 60.0
@export var distancia_de_visao: float = 170.0

# O nome da animação de andar é @export porque o zumbi rápido tem "run" e os
# outros têm "walk". Escrito dentro do chase_state(), este caso exigiria um
# segundo script.
@export var animacao_de_andar: String = "walk"

@export var tempo_entre_ataques: float = 1.2   # o cooldown do golpe
@export var tempo_hurt: float = 0.25
@export var quadro_do_golpe: int = 4           # o quadro em que o braço chega


# ---------------------------------------------------------------------------
# Memória
# ---------------------------------------------------------------------------

var vida: int
var tempo_do_ataque: float = 0.0
var tempo_no_hurt: float = 0.0
# Um quadro de animação dura vários passos de física. Sem esta trava, o mesmo
# soco tiraria vida seis ou sete vezes.
var golpe_aplicado: bool = false


func _ready() -> void:
	vida = vida_maxima
	go_to_idle_state()


## Acha o jogador pelo GRUPO, não por caminho de nó nem por referência guardada.
## Se o jogador mudar de lugar na cena, o zumbi continua achando. Só pode haver
## um nó no grupo "player" — a câmera usa o mesmo mecanismo.
func alvo() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	match status:
		ZumbiState.idle:
			idle_state()
		ZumbiState.chase:
			chase_state()
		ZumbiState.attack:
			attack_state()
		ZumbiState.hurt:
			hurt_state()
		ZumbiState.death:
			pass          # morte é o estado do qual não se sai

	move_and_slide()


# ---------------------------------------------------------------------------
# idle — parado, esperando
# ---------------------------------------------------------------------------

func go_to_idle_state() -> void:
	status = ZumbiState.idle
	anim.play("idle")
	velocity.x = 0


func idle_state() -> void:
	var p := alvo()
	if p == null:
		return

	# A condição de entrada é uma DISTÂNCIA, não uma tecla. É o único ponto em
	# que esta máquina difere da do jogador.
	if global_position.distance_to(p.global_position) <= distancia_de_visao:
		go_to_chase_state()


# ---------------------------------------------------------------------------
# chase — perseguindo
# ---------------------------------------------------------------------------

func go_to_chase_state() -> void:
	status = ZumbiState.chase
	anim.play(animacao_de_andar)


func chase_state() -> void:
	var p := alvo()
	if p == null:
		go_to_idle_state()
		return

	var distancia := global_position.distance_to(p.global_position)

	# As saídas vêm antes do movimento: não faz sentido andar num quadro em que
	# o estado já vai mudar.
	if distancia > distancia_de_visao:
		go_to_idle_state()
		return

	if distancia <= distancia_de_ataque:
		go_to_attack_state()
		return

	# signf devolve -1 ou 1, conforme o jogador esteja à esquerda ou à direita.
	# São as duas direções da aula: não existe sprite virado para a esquerda.
	var lado := signf(p.global_position.x - global_position.x)
	velocity.x = lado * velocidade
	olhar_para(lado)


## Espelha sprite e área de ataque juntos. O flip_h sozinho viraria só o
## desenho, e o zumbi bateria à direita olhando para a esquerda.
func olhar_para(lado: float) -> void:
	if lado == 0:
		return
	anim.flip_h = lado < 0
	area_ataque.position.x = abs(area_ataque.position.x) * lado


# ---------------------------------------------------------------------------
# attack — golpeando
# ---------------------------------------------------------------------------

func go_to_attack_state() -> void:
	status = ZumbiState.attack
	anim.play("attack")
	velocity.x = 0
	tempo_do_ataque = 0.0
	golpe_aplicado = false

	# A direção é congelada AQUI, no início do golpe, e não no último quadro de
	# perseguição. Durante o ataque o chase_state() não roda, então sem esta
	# linha ele bateria para o lado onde você estava.
	var p := alvo()
	if p != null:
		olhar_para(signf(p.global_position.x - global_position.x))

	area_ataque.monitoring = true


func attack_state() -> void:
	tempo_do_ataque += get_physics_process_delta_time()

	# O dano sai NUM QUADRO da animação — o instante em que o braço chega — e
	# não durante os dois segundos do estado. Ligada o tempo todo, a área não
	# representa um golpe: representa "estar perto dele", e o jogador não teria
	# como se aproximar entre um ataque e outro.
	#
	# Repare que a lógica é o contrário do sinal body_entered: aqui o zumbi
	# PERGUNTA quem está dentro, no momento em que quer saber.
	if not golpe_aplicado and anim.frame >= quadro_do_golpe:
		golpe_aplicado = true
		for corpo in area_ataque.get_overlapping_bodies():
			if corpo != self and corpo.is_in_group("player") and corpo.has_method("levar_dano"):
				corpo.levar_dano(dano)

	# Terminado o cooldown, ele decide: ataca de novo se você continua perto,
	# ou volta a perseguir se você saiu.
	if tempo_do_ataque >= tempo_entre_ataques:
		area_ataque.monitoring = false
		var p := alvo()
		if p != null and global_position.distance_to(p.global_position) <= distancia_de_ataque:
			go_to_attack_state()
		else:
			go_to_chase_state()
		return


# ---------------------------------------------------------------------------
# hurt e death
# ---------------------------------------------------------------------------

func levar_dano(quantidade: int) -> void:
	# Já morto ou já piscando: ignora. Sem isto, um golpe do jogador tiraria
	# vida várias vezes durante a mesma animação.
	if status == ZumbiState.death or status == ZumbiState.hurt:
		return

	vida -= quantidade

	if vida <= 0:
		go_to_death_state()
		return

	go_to_hurt_state()


func go_to_hurt_state() -> void:
	status = ZumbiState.hurt
	anim.play("hurt")
	velocity.x = 0
	tempo_no_hurt = 0.0
	# Apanhou no meio do golpe: o soco dele foi interrompido.
	area_ataque.monitoring = false


func hurt_state() -> void:
	tempo_no_hurt += get_physics_process_delta_time()
	if tempo_no_hurt >= tempo_hurt:
		go_to_chase_state()
		return


func go_to_death_state() -> void:
	status = ZumbiState.death
	anim.play("death")
	velocity.x = 0
	area_ataque.monitoring = false

	# set_deferred, e não `disabled = true`: desligar um colisor no meio do
	# passo de física trava a Godot com erro em vermelho.
	$CollisionShape2D.set_deferred("disabled", true)

	# E parar a física, porque desligar o colisor faz is_on_floor() virar falso.
	# Sem esta linha a gravidade continua somando e o cadáver AFUNDA no chão
	# durante a animação de morte.
	set_physics_process(false)

	# O await segura o queue_free() até a animação terminar. Só funciona com a
	# animação de death SEM loop — em loop, o sinal nunca é emitido e o zumbi
	# fica morrendo para sempre.
	await anim.animation_finished
	queue_free()
