extends CharacterBody2D

## O sobrevivente — Aula 06
##
## Este script é a máquina de estados da Aula 05 com três estados novos:
## run, hurt e attack. A estrutura é a mesma de sempre e vale reler antes de
## acrescentar qualquer coisa:
##
##   enum  -> a lista do que ele pode estar fazendo
##   status -> o que ele está fazendo AGORA
##   match  -> chama a função do estado atual, uma vez por quadro
##   go_to_*() -> a ENTRADA de cada estado: troca o status e toca a animação
##   *_state() -> o que acontece enquanto ele está lá, e as saídas
##
## A regra que evita o erro mais comum: **a condição que entra num estado mora
## no estado de ORIGEM**. `walk -> run` é escrita dentro do walk_state().


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

enum PlayerState {
	walk,
	idle,
	jump,
	run,
	hurt,
	attack,
}

var status: PlayerState


# ---------------------------------------------------------------------------
# Nós da cena
# ---------------------------------------------------------------------------

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
# A área do golpe. Nasce desligada no Inspetor e só liga durante o ataque.
@onready var area_golpe: Area2D = $AreaGolpe


# ---------------------------------------------------------------------------
# Números ajustáveis pelo Inspetor
#
# Tudo o que se equilibra jogando é @export. Mudar valor no Inspetor com o jogo
# rodando é muito mais rápido do que parar, editar o script e rodar de novo.
# ---------------------------------------------------------------------------

@export var vida_maxima: int = 5
@export var tempo_hurt: float = 0.4      # quanto tempo fica piscando e invulnerável
@export var dano_do_golpe: int = 2
@export var quadro_do_golpe: int = 3     # o quadro da animação em que o cano chega

const SPEED = 150.0
const SPEED_RUN = 200.0
const JUMP_VELOCITY = -400.0             # altura = 400²/(2*980) = 82 px, uns 5 tiles


# ---------------------------------------------------------------------------
# Memória
# ---------------------------------------------------------------------------

var vida: int
var direction = 0
var jump_count = 0
var max_jump_count = 2
var tempo_no_hurt: float = 0.0
# Um quadro de animação dura vários passos de física. Sem esta trava, o mesmo
# golpe tiraria vida seis ou sete vezes.
var golpe_aplicado: bool = false


func _ready() -> void:
	vida = vida_maxima
	go_to_idle_state()


# ---------------------------------------------------------------------------
# O laço principal: gravidade -> estado atual -> mover
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	match status:
		PlayerState.idle:
			idle_state()
		PlayerState.walk:
			walk_state()
		PlayerState.jump:
			jump_state()
		PlayerState.run:
			run_state()
		PlayerState.hurt:
			hurt_state()
		PlayerState.attack:
			attack_state()

	move_and_slide()


# ---------------------------------------------------------------------------
# Entradas dos estados
# ---------------------------------------------------------------------------

func go_to_idle_state():
	# Devolve a cor normal: quem chega aqui pode estar vindo do hurt, que deixa
	# o sprite avermelhado.
	anim.modulate = Color(1, 1, 1)
	status = PlayerState.idle
	anim.play("idle")


func go_to_walk_state():
	status = PlayerState.walk
	anim.play("walk")


func go_to_run_state():
	status = PlayerState.run
	anim.play("run")


func go_to_jump_state():
	jump_count += 1
	status = PlayerState.jump
	anim.play("jump")
	velocity.y = JUMP_VELOCITY


func go_to_hurt_state() -> void:
	status = PlayerState.hurt
	anim.play("hurt")
	tempo_no_hurt = 0.0
	velocity.x = 0
	anim.modulate = Color(1, 0.4, 0.4)
	# Apanhou no meio do próprio golpe: a área sai junto. Sem isto ela ficaria
	# ligada esperando um ataque que já foi interrompido.
	area_golpe.monitoring = false


func go_to_attack_state() -> void:
	status = PlayerState.attack
	anim.play("attack")
	velocity.x = 0          # atacar imobiliza — é o custo do golpe
	golpe_aplicado = false
	area_golpe.monitoring = true


# ---------------------------------------------------------------------------
# Os estados
# ---------------------------------------------------------------------------

func idle_state():
	move()

	if velocity.x != 0:
		go_to_walk_state()
		return

	if Input.is_action_just_pressed("attack"):
		go_to_attack_state()
		return

	if Input.is_action_just_pressed("jump"):
		go_to_jump_state()
		return


func walk_state():
	move()

	if velocity.x == 0:
		go_to_idle_state()
		return

	if Input.is_action_just_pressed("attack"):
		go_to_attack_state()
		return

	# A seta que ENTRA no run mora aqui, no estado de origem. Escrever esta
	# condição dentro do run_state() faz um laço fechado: para entrar no run
	# seria preciso já estar no run — e o botão nunca funcionaria.
	if Input.is_action_pressed("run"):
		go_to_run_state()
		return

	if Input.is_action_just_pressed("jump"):
		go_to_jump_state()
		return


func run_state():
	move(SPEED_RUN)

	# Três saídas: parou, soltou o Shift, pulou. Estado não é "animação
	# tocando": é um conjunto de condições de saída.
	if velocity.x == 0:
		go_to_idle_state()
		return

	# is_action_pressed, e não just_pressed: o Shift fica segurado.
	if not Input.is_action_pressed("run"):
		go_to_walk_state()
		return

	if Input.is_action_just_pressed("attack"):
		go_to_attack_state()
		return

	if Input.is_action_just_pressed("jump"):
		go_to_jump_state()
		return


func jump_state():
	move()

	if Input.is_action_just_pressed("jump") and jump_count < max_jump_count:
		go_to_jump_state()
		return

	if is_on_floor():
		jump_count = 0
		if velocity.x == 0:
			go_to_idle_state()
		else:
			go_to_walk_state()
		return


func hurt_state() -> void:
	# Este estado sai SOZINHO, pelo tempo. Nenhum dos estados da aula passada
	# fazia isso — idle, walk e jump só trocam quando você aperta algo.
	tempo_no_hurt += get_physics_process_delta_time()
	if tempo_no_hurt >= tempo_hurt:
		go_to_idle_state()
		return


func attack_state() -> void:
	# O dano sai NUM QUADRO da animação — o instante em que o cano chega — e não
	# durante os 7 quadros. Ligada o tempo todo, a área mataria o zumbi só de
	# você passar perto com o botão apertado.
	if not golpe_aplicado and anim.frame >= quadro_do_golpe:
		golpe_aplicado = true
		for corpo in area_golpe.get_overlapping_bodies():
			# corpo != self: a área do golpe encosta no colisor do próprio
			# jogador, e como ele tem levar_dano() ele passaria no teste e se
			# acertaria a cada golpe. Afastar a área "resolveria", mas ficaria
			# dependendo de dois pixels de folga.
			if corpo != self and corpo.has_method("levar_dano"):
				corpo.levar_dano(dano_do_golpe)

	# A saída aqui é o FIM DA ANIMAÇÃO — nem tecla, nem tempo. Por isso a
	# animação de attack precisa estar sem loop: em loop, is_playing() nunca
	# fica falso e o personagem ataca para sempre.
	if not anim.is_playing():
		area_golpe.monitoring = false
		go_to_idle_state()
		return


# ---------------------------------------------------------------------------
# Vida e dano
# ---------------------------------------------------------------------------

func levar_dano(quantidade: int) -> void:
	# Recusar dano durante o hurt é o que cria a invulnerabilidade temporária.
	# Sem isso, encostar num zumbi tiraria vida sessenta vezes por segundo.
	if status == PlayerState.hurt:
		return

	vida -= quantidade
	print("vida: ", vida)

	if vida <= 0:
		morrer()
		return

	go_to_hurt_state()


func morrer() -> void:
	status = PlayerState.hurt
	anim.play("death")
	velocity.x = 0
	# Morte é o estado sem saída: desligar o _physics_process é o jeito mais
	# curto de dizer isso. Nenhuma entrada é lida, nenhum estado troca.
	set_physics_process(false)


# ---------------------------------------------------------------------------
# Movimento
# ---------------------------------------------------------------------------

# A velocidade é PARÂMETRO, com o andar como padrão. É o que permite o run sem
# tocar nos outros estados — e o que substitui o "velocity.x *= 2", que não
# funcionava: parado, velocity.x é 0, e 0 * 2 continua 0.
func move(vel: float = SPEED):
	update_direction()

	if direction:
		velocity.x = direction * vel
	else:
		velocity.x = move_toward(velocity.x, 0, vel)


func update_direction():
	direction = Input.get_axis("left", "right")

	# O flip_h espelha só o DESENHO. A área do golpe é outro nó e precisa ser
	# movida à mão, senão você vira para a esquerda e continua batendo à
	# direita.
	if direction > 0:
		anim.flip_h = false
		area_golpe.position.x = abs(area_golpe.position.x)
	elif direction < 0:
		anim.flip_h = true
		area_golpe.position.x = -abs(area_golpe.position.x)
