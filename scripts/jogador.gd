extends CharacterBody2D

enum PlayerState {
	walk, 
	idle,
	jump,
	run,
	hurt,
	attack,
}

@export var vida_maxima: int = 5
var vida: int

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

@export var tempo_hurt: float = 0.4
var tempo_no_hurt: float = 0.0


var direction = 0

const SPEED = 150.0
const SPEED_RUN = 200.0
const JUMP_VELOCITY = -400.0

var jump_count = 0
var max_jump_count = 2

var status: PlayerState

func _ready() -> void:
	vida = vida_maxima
	go_to_idle_state()

@onready var area_golpe: Area2D = $AreaGolpe
@export var dano_do_golpe: int = 2
@export var quadro_do_golpe: int = 3
var golpe_aplicado: bool = false


func go_to_attack_state() -> void:
	status = PlayerState.attack
	anim.play("attack")
	velocity.x = 0
	golpe_aplicado = false
	area_golpe.monitoring = true


func attack_state() -> void:
	# O dano sai no quadro em que o cano chega, nao durante a animacao toda.
	# Ligada o tempo todo, a area mataria o zumbi so de encostar nele.
	if not golpe_aplicado and anim.frame >= quadro_do_golpe:
		golpe_aplicado = true
		for corpo in area_golpe.get_overlapping_bodies():
			# corpo != self: a area de golpe encosta no proprio colisor do
			# jogador, e como ele tem levar_dano, sem esta guarda ele se
			# acerta a cada golpe.
			if corpo != self and corpo.has_method("levar_dano"):
				corpo.levar_dano(dano_do_golpe)

	# A saida deste estado e o fim da animacao -- por isso ela precisa estar
	# sem loop.
	if not anim.is_playing():
		area_golpe.monitoring = false
		go_to_idle_state()
		return

func levar_dano(quantidade: int) -> void:
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
	set_physics_process(false)


func go_to_hurt_state() -> void:
	status = PlayerState.hurt
	anim.play("hurt")
	tempo_no_hurt = 0.0
	velocity.x = 0
	# Apanhou no meio do golpe: a area sai junto.
	area_golpe.monitoring = false
	anim.modulate = Color(1, 0.4, 0.4)
	
func hurt_state() -> void:
	tempo_no_hurt += get_physics_process_delta_time()
	if tempo_no_hurt >= tempo_hurt:
		go_to_idle_state()
		return



func go_to_idle_state():
	anim.modulate = Color(1, 1, 1)
	status = PlayerState.idle
	anim.play("idle")
	
func go_to_walk_state():
	status = PlayerState.walk
	anim.play("walk")
	

func go_to_jump_state():
	jump_count+=1
	
	status = PlayerState.jump
	anim.play("jump")
	velocity.y = JUMP_VELOCITY

func go_to_run_state():
	status = PlayerState.run
	anim.play("run")

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
		return#collision_shape.shape.radios = 6
	#collision_shape.shape.height = 16 
	#collision_shape.shape.position.y =-1

	
func walk_state():
	move()
	if velocity.x == 0:
		go_to_idle_state()
		return
	
	# A seta que ENTRA no run mora aqui, no estado de origem. Escrever esta
	# condicao dentro do run_state() faz um laco fechado: para entrar no run
	# seria preciso ja estar no run.
	if Input.is_action_just_pressed("attack"):
		go_to_attack_state()
		return
	
	if Input.is_action_pressed("run"):
		go_to_run_state()
		return
	
	if Input.is_action_just_pressed("jump"):
		go_to_jump_state()
		return

func run_state():
	move(SPEED_RUN)
	
	if velocity.x == 0:
		go_to_idle_state()
		return
	
	# is_action_pressed, e nao just_pressed: o Shift fica segurado.
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
		jump_count=0
		if velocity.x == 0:
			go_to_idle_state()
		else:
			go_to_walk_state()

		return
		
	
		

	
# A velocidade e parametro, com o andar como padrao. E o que permite o run sem
# tocar nos outros estados, e o que substitui o "velocity.x *= 2" -- que nao
# funcionava: parado, velocity.x e 0, e 0 * 2 continua 0.
func move(vel: float = SPEED):
	
	update_direction()
	
	if direction:
		velocity.x = direction * vel
	else:
		velocity.x = move_toward(velocity.x, 0, vel)
		
	

func update_direction():
	direction = Input.get_axis("left", "right")
	if direction > 0:
		anim.flip_h = false
		area_golpe.position.x = abs(area_golpe.position.x)
	elif direction < 0:
		anim.flip_h = true
		area_golpe.position.x = -abs(area_golpe.position.x)
		
		
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
	
	

	
	
	
	
	
	
#func _physics_process(delta: float) -> void:
	## Add the gravity.
	#if not is_on_floor():
		#velocity += get_gravity() * delta
		#
#
	## Handle jump.
	#if Input.is_action_just_pressed("jump") and is_on_floor():
		#velocity.y = JUMP_VELOCITY
#
	## Get the input direction and handle the movement/deceleration.
	## As good practice, you should replace UI actions with custom gameplay actions.
	#var direction := Input.get_axis("left", "right")
	#if direction:
		#velocity.x = direction * SPEED
	#else:
		#velocity.x = move_toward(velocity.x, 0, SPEED)
	#
	#if is_on_floor():
		#if direction > 0:
			#anim.flip_h = false
			#anim.play("walk")
		#elif direction < 0:
			#anim.flip_h = true
			#anim.play("walk")
		#else:
			#anim.play("idle")
	#else:
		#anim.play("jump")
		#if direction > 0:
			#anim.flip_h = false
		#elif direction < 0:
			#anim.flip_h = true
			#
			#
	#move_and_slide()


func _on_area_golpe_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
