extends Node2D
@onready var computer_sound: AudioStreamPlayer = %ComputerSound
@onready var prompt: LineEdit = %Prompt
@onready var text: RichTextLabel = %Text
@onready var music: AudioStreamPlayer = %Music
@onready var maze: TileMapLayer = %Maze
@onready var beep_error: AudioStreamPlayer = %BeepError

const WIN_SOUND = preload("uid://cig5v6bgp454a")
const LOSE_SOUND = preload("uid://c84u4ro5vrdo6")
const POWERUP = preload("uid://dhwiwl1vnbbsp")
const PICKUP = preload("uid://beded85y1pfcr")

const directions: Dictionary = {
	"north": Vector2i.UP,
	"east": Vector2i.RIGHT,
	"south": Vector2i.DOWN,
	"west": Vector2i.LEFT,
}
enum cell_type {WALL, EMPTY, PILL, ORB, TELEPORT}
var inventory: Array[String] = ["letter"]
@export var default_time: float = 5 * 60
@export var maze_location: Vector2i = Vector2i(0, 0)
var start_time: float
var seconds_left: float
var score: int = 0
var dead: bool = false
var won: bool = false
var current_location_was_new: bool = true
enum ghost_state {SCATTER, CHASING, FRIGHTENED, DEAD}
var monsters: Array [Dictionary] = [
	{"color": "red", "name": "Kyln-Ib", "nick": "the red death", "state": ghost_state.SCATTER, "pos": Vector2i(-4, -5)},
	{"color": "pink", "name": "Kyp'ni", "nick": "the poisonous one", "state": ghost_state.SCATTER, "pos": Vector2i(3, -5)},
	{"color": "cyan", "name": "Nyik", "nick": "the wise", "state": ghost_state.SCATTER, "pos": Vector2i(-4, 1)},
	{"color": "orange", "name": "Dy'lec", "nick": "the doubtful", "state": ghost_state.SCATTER, "pos": Vector2i(3, 1)},
]
var alive_monsters : int = len(monsters)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	computer_sound.play()
	start_time = Time.get_unix_time_from_system()	
	text.text = get_start_text()
	text.text += update_seconds_left()	
	prompt.grab_focus.call_deferred()
	inventory = ["letter"]
	score = 0
	randomize_monster_position()
	#for m in monsters:
	#	print_debug(m.pos)
	dead = false

func restart_game():
	get_tree().reload_current_scene()

func randomize_monster_position():
	for m in monsters:
		if randf() > 0.5:
			m.pos += Vector2i(0, 2)

func error_beep():
	beep_error.play()

func get_start_text() -> String:
	return """
***********************
Orbs of Power: The Maze
***********************

You awake alone in a dungeon.
You have one letter in your inventory.
You have 2 ways: east or west from here.
There are no enemies in view.

Type 'help' to get a list of available commands.

"""

func get_help() -> String:
	return """
Commands:

 * [b]help[/b]: Shows valid commands (this text!)
 * [b]north[/b]: Goes up one step
 * [b]south[/b]: Goes down one step
 * [b]west[/b]: Goes right one step
 * [b]east[/b]: Goes left one step
 * [b]describe[/b]: Describes the current location
 * [b]take[/b] <item>: Adds item to inventory, if available
 * [b]use[/b] <item>: Uses item from inventory, if available
 * [b]inventory[/b]: List items available in your inventory
 * [b]restart[/b]: Restarts & resets the timer to try again

Copyright (c) Iota Urn-Wait 1978
"""
func use_orb() -> String:
	var checking_tile_location : Vector2i
	var possible_ways: Array[String] = get_possible_ways()
	var killed_monsters: bool = false
	var description : String = ""
	for w in possible_ways:
		checking_tile_location = maze_location + directions[w]
		var monsters_at_location: Array[Dictionary] = list_monsters_at(checking_tile_location)
		for m in monsters_at_location:
			if m.state == ghost_state.DEAD:  # it cannot kill a dead ghost
				continue
			description += "The " + m.color + " demon " + m.name + ", " + \
						   m.nick + ", DIES due to the energy " + \
			               "of your ORB while shouting waka-waka!\n\n"
			m.state = ghost_state.DEAD
			alive_monsters -= 1
			killed_monsters = true
	if not killed_monsters:
		description = "You cannot use your ORB here, there are no monsters nearby."
	else:
		if alive_monsters <= 0:
			text.text = description
			win()
			return ""
		inventory.erase("orb")
		description += "Your orb gets consumed after usage. You have " + \
						str(inventory.count("orb")) + " orb(s) left."
		music.stream = POWERUP
		music.play()
	return description

func read_letter() -> String:
	return """
Dear player,
I trapped you in my impossible maze (buah, ha ha)!
The only way to exit is by finding the 4 secret orbs
of power and use them against the 4 undead demons
that hide in this terrible maze:

 * Kyln-Ib, the red death
 * Kyp'ni, the poisonous one
 * Nyik, the wise
 * Dy'lec, the doubtful

Good luck, adventurer, alas, be quick, as my patience
is low: spend more than 5 minutes wandering on my
maze and you will go mad and die, joining my horde of
undead slaves!
"""

func use_item(cmd: String) -> String:
	var split_cmd = cmd.split(" ")
	if split_cmd.size() < 2:
		error_beep()
		return "You need something to use!\n"
	var item = split_cmd[1]
	if item not in inventory:
		error_beep()
		return "You don't have a(n) " + item + " in your inventory!\n"

	if item == "letter":
		return read_letter()
	elif item == "orb":
		return use_orb()
	else:
		error_beep()
		return "You cannot use " + item + " here."

func take_item(cmd: String):
	var split_cmd = cmd.split(" ")
	if split_cmd.size() < 2:
		error_beep()
		return "You need something to take!\n"
	var item = split_cmd[1]

	if item == "orb" and get_tile(maze_location) == cell_type.ORB:
		maze.set_cell(maze_location, 0, Vector2(0, 0))
		inventory.append("orb")
		music.stream = PICKUP
		music.play()
		return "You carefully take an ORB of power and put it in your pocket.\n"
	else:
		error_beep()
		return "There is no " + item + " to take here!\n"

func get_cmd_not_recognized() -> String:
	error_beep()
	return "Command not recognized. " + \
	       "Type 'help' for the list of available commands."

func list_inventory() -> String:
	var output: String = "You have " + str(len(inventory)) + \
	                     " item(s) in your inventory:\n\n"
	for item: String in inventory:
		output += ("* " + item + "\n")
	return output

func die(monsters_that_killed_you: Array[Dictionary] = []) -> void:
	dead = true
	if len(monsters_that_killed_you) == 0:
		text.text = "You ran out of time, and DIED of madness."
	elif len(monsters_that_killed_you) == 1:
		var m = monsters_that_killed_you[0]
		text.text = "The demon known as " + m.name + \
					" ate your guts, and you DIED in pain while its disgusting " + \
					m.color + " saliva fully covered your remains."
	else:
		text.text = "The demons known as " + " and ".join(monsters_that_killed_you) + \
		            "commence to eat your guts, and you DIE among a multi-color frency."
	text.text += "\n\nType 'restart' to try again."
	music.stream = LOSE_SOUND
	music.play()

func win():
	won = true
	text.text += """
CONGRATULATIONS, you WON! You successfully navigated
my maze and used your witts to defeat the 4 deamons
with the orbs of power:

 * Kyln-Ib, the read death (also known as Blinky)
 * Kyp'ni, the poisonous one (also known as Pinky)
 * Nyik, the wise (also known as Inky)
 * Dy'lec, the doubtful (also known as Clyde)

You have demonstrated being the ultimate

             MAN of the PAC!
"""
	text.text += "\n\nType 'restart' to try again."
	music.stream = WIN_SOUND
	music.play()

func calculate_seconds_left() -> void:
	seconds_left = default_time - Time.get_unix_time_from_system() + start_time

func update_seconds_left() -> String:
	calculate_seconds_left()
	@warning_ignore("integer_division")
	return "You have %02d:%02d left\n\n" % [int(seconds_left) / 60, int(seconds_left) % 60]

func get_possible_ways() -> Array[String]:
	var possible_ways : Array[String] = []
	for k in directions.keys():
		if get_tile(maze_location + directions[k]) != cell_type.WALL:
			possible_ways.append(k)
	return possible_ways

func list_possible_ways() -> String:
	var possible_ways : Array[String] = get_possible_ways()
	var possible_ways_except_last: Array = possible_ways.duplicate()
	possible_ways_except_last.pop_back()
	return " or ".join([", ".join(possible_ways_except_last), possible_ways[-1]])

func get_tile(location: Vector2i) -> cell_type:
	if maze.get_cell_source_id(location) == -1:
		return cell_type.WALL
	elif maze.get_cell_atlas_coords(location) == Vector2i(0, 0):
		return cell_type.EMPTY
	elif maze.get_cell_atlas_coords(location) == Vector2i(1, 0):
		return cell_type.PILL
	elif maze.get_cell_atlas_coords(location) == Vector2i(2, 0):
		return cell_type.ORB
	elif maze.get_cell_atlas_coords(location) == Vector2i(3, 0):
		return cell_type.TELEPORT
	else:
		return cell_type.WALL

func list_monsters_at(pos: Vector2i) -> Array[Dictionary]:
	var monster_list: Array[Dictionary] = []
	for m in monsters:
		if m.pos == pos:
			monster_list.append(m)
	return monster_list

func describe_location() -> String:
	var description : String = ""
	var location : cell_type = get_tile(maze_location)
	if not current_location_was_new:
		description += "You find yourself BACK in a familiar location - you have been here before.\n"
	if location == cell_type.PILL:
		# eat the pill 
		maze.set_cell(maze_location, 0, Vector2i(0, 0))
	elif location == cell_type.ORB:
		description += "You find a giant ORB levitating 2 feet above the ground.\n"

	for m in list_monsters_at(maze_location):
		if m.state == ghost_state.DEAD:
			description += "You find the disgusting " + m.color + \
						   " remains of the dead deamon " + m.name + " here.\n"

	var possible_ways : Array[String] = get_possible_ways()
	var checking_tile_location : Vector2i
	var monster_list: Array[Dictionary] = []
	
	# check current location for dead bodies
	# Check surroundings
	for w in possible_ways:
		checking_tile_location = maze_location + directions[w]
		var monsters_at_location: Array[Dictionary] = list_monsters_at(checking_tile_location)
		for m in monsters_at_location:
			if m.state not in [ghost_state.DEAD]: # Ingore ghost's dead bodies
				description += "A terrible " + m.color + " DEMON is just to your " + w + "!\n"
				monster_list.append(m)

		if get_tile(checking_tile_location) == cell_type.ORB:
			description += "You can see a bright light coming from the " + w + ".\n"
	if len(monster_list) == 0:
		description += "There are no enemies in view.\n"

	if len(possible_ways) == 0:
		description += "You are trapped, there are no exits from here"
	elif len(possible_ways) == 1:
		description += "You find yourself in a dead end, and your only way is through the " + possible_ways[0] + "."
	else:
		description += "You have " + str(len(possible_ways)) + " ways from here: " + list_possible_ways() + "."
	return description

func move(dir: String) -> String:
	var possible_ways: = get_possible_ways()
	if dir in possible_ways:
		maze_location += directions[dir]
		current_location_was_new = false if get_tile(maze_location) == cell_type.EMPTY else true
		# Was there a monster there?
		var monster_alive_list: Array[Dictionary] = []
		var monster_list: Array[Dictionary] = list_monsters_at(maze_location)
		for m in monster_list:
			if m.state != ghost_state.DEAD:
				monster_alive_list.append(m)

		if len(monster_alive_list) > 0:
			die(monster_alive_list)
			return ""
		if get_tile(maze_location) == cell_type.TELEPORT:  # teleport hack
			maze_location = maze_location + Vector2i(6, 0) if maze_location.x < 0 else maze_location - Vector2i(6, 0)
			return "You move towards the " + dir + ".\n\n" + \
				   "You feel a chill when you arrive at this place, and a slight dizziness.\n" + \
				   describe_location()
		else:
			return "You move towards the " + dir + ".\n\n" + describe_location()
	else:
		error_beep()
		return "You cannot move towards " + dir + ", that direction is blocked.\nYour possible directions are: " + list_possible_ways() + "."

func _on_prompt_submit_cmd(cmd: String) -> void:
	text.text = "> " + cmd + "\n\n"
	
	if dead and not cmd.begins_with("h") and not cmd.begins_with('r'):
		error_beep()
		text.text = "YOU ARE DEAD, you cannot do that. Type 'restart' to start a new game."
		return
	elif won and not cmd.begins_with("h") and not cmd.begins_with('r'):
		error_beep()
		text.text = "YOU ALREADY WON, you cannot do that. Type 'restart' to start a new game."

	if not dead and not won:
		text.text += update_seconds_left()
		if seconds_left <= 0.0:
			die()
			return

	if cmd.begins_with("h"):
		text.text += get_help()
	elif cmd.begins_with("d"):
		text.text += describe_location()
	elif cmd.begins_with("n"):
		text.text += move("north")
	elif cmd.begins_with("e"):
		text.text += move("east")
	elif cmd.begins_with("s"):
		text.text += move("south")
	elif cmd.begins_with("w"):
		text.text += move("west")
	elif cmd.begins_with("u"):
		text.text += use_item(cmd)
	elif cmd.begins_with("t"):
		text.text += take_item(cmd)
	elif cmd.begins_with("i"):
		text.text += list_inventory()
	elif cmd.begins_with("r"):
		restart_game()
	else:
		text.text += get_cmd_not_recognized()
