extends SceneTree
## Headless integration sim: boots main scene, starts a game, pokes the player,
## lets mobs spawn, saves, then quits. Run:
##   godot --headless --path . -s res://tests/sim.gd

var frames := 0
var main


func _initialize() -> void:
        var ms: Node = load("res://scenes/main.tscn").instantiate()
        root.add_child(ms)
        main = ms


func _process(_delta: float) -> bool:
        frames += 1
        if frames == 10:
                main.start_game(true)
        if frames == 200 and main.player:
                main.player.jump_req = true
                main.player.apply_look(300.0, 30.0)
        if frames == 250 and main.player:
                main.player.apply_look(0.0, 800.0)  # drag down = pitch down
        if frames == 320 and main.player:
                main.player.do_break()
        if frames == 340 and main.player:
                main.player.do_place(Blocks.STONE)
        if frames == 400 and main.player:
                main.player.do_break()
        if frames == 450 and main.world:
                main.world.tod = 0.7  # force night: zombies should spawn and hunt
        if frames == 460 and main.mobs and main.player:
                var z = main.mobs._make_mob("zombie", main.player.global_position + Vector3(3, 1.2, 3))
                main.mobs._mob_base_colors(z)
                main.mobs.mobs.append(z)
        if frames == 1000:
                if main.world == null or main.player == null:
                        print("SIM-FAIL: game not running")
                        return true
                print("SIM-NIGHT tod=%.3f mobs=%d hp=%d" % [main.world.tod, main.mobs.mobs.size(), main.player.hp])
                print("  kinds=", main.mobs.mobs.map(func(m): return m.kind))
        if frames == 1500:
                print("SIM-NIGHT2 tod=%.3f mobs=%d hp=%d dead=%s" % [main.world.tod, main.mobs.mobs.size(), main.player.hp, str(main.player.dead)])
        if frames == 1550 and main.player and not main.player.dead:
                main.player.take_damage(99, true)
        if frames == 1600:
                print("SIM-DEAD hp=%d dead=%s" % [main.player.hp, str(main.player.dead)])
                main.respawn()
        if frames == 1650:
                print("SIM-RESPAWN hp=%d dead=%s" % [main.player.hp, str(main.player.dead)])
                if main.world == null or main.player == null:
                        print("SIM-FAIL: game not running")
                        return true
                print("SIM-INFO tod=%.3f mobs=%d hp=%d pos=%s chunks=%d meshes=%d mods=%d" % [
                        main.world.tod, main.mobs.mobs.size(), main.player.hp,
                        str(main.player.global_position), main.world.cells.size(), main.world.meshes.size(),
                        main.world.mods.size()])
                var col := ""
                for y in range(16, 36):
                        col += str(y) + ":" + str(main.world.get_block(Vector3i(8, y, 8))) + " "
                print("COL(8,*,8) ", col)
                print("PLAYER free=", main.world.box_free(main.player.global_position, Vector3(0.3, 0.9, 0.3)),
                        " grounded=", main.player.grounded, " vel=", main.player.vel)
                var hit: Dictionary = main.world.raycast(main.player.eye_pos(), main.player.look_dir(), 6.0)
                print("RAY ", hit, " eye=", main.player.eye_pos(), " dir=", main.player.look_dir())
                main.save_game()
                print("SIM-OK")
                return true
        if frames > 2000:
                print("SIM-TIMEOUT")
                return true
        return false
