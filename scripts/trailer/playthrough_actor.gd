class_name PlaythroughActor
extends TrailerActor
## Plays the book from the title screen the way the game's own autoplay does (AutoplayDirector._run:
## the title, each level's route, Pell's raft on to the next level), with the trailer actor's game
## clock and live strokes, for an unbroken film of play. Changes from the QA run: the death test
## (a check that kills Orimi on the spot) is skipped; the title and a level's opening card are held
## long enough to read; talk lines are paced by the director for reading, so time with a talk panel
## open does not count against the route's waits (a verse-stone read at the QA run's pace would
## otherwise look unread and be cast again). Owner: trailer.

## Seconds the title screen and a level's opening card stay up.
const HOLD_CARD := 3.0


func play_book() -> void:
	await _run()


func _wait(seconds: float) -> void:
	if Game.state == Game.STATE_TITLE or bool(Game.main.get(&"intro_open")):
		seconds = maxf(seconds, HOLD_CARD)
	await super._wait(seconds)


func _wait_until(cond: Callable, timeout: float) -> bool:
	var talk: Node = Game.main.get(&"talk")
	var left := timeout
	var last := _now()
	while left > 0.0:
		if cond.call():
			return true
		await get_tree().physics_frame
		if not bool(talk.get(&"is_open")):
			left -= _now() - last
		last = _now()
	return cond.call()


func _step(s: Dictionary) -> void:
	if s.has("death_test"):
		return
	await super._step(s)


func _talk(person: Node) -> void:
	if person == null:
		return
	await _go(_before((person as Node3D).global_position, _player.global_position, 1.6))
	var talk: Node = Game.main.get(&"talk")
	person.call("talk")
	await _wait_until(func() -> bool: return bool(talk.get(&"is_open")), 3.0)
	if not await _wait_until(func() -> bool: return not bool(talk.get(&"is_open")), 90.0):
		_fail("talk with %s never ended" % person.name)
	await super._wait(0.4)
