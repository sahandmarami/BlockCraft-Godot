extends SceneTree
## Headless integration sim: boots main scene, starts a game, pokes the player,
## tests joystick direction, block drops, inventory, animals, night, death,
## respawn and save. Run:
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
        if frames == 300 and main.mobs:
                # animals should be seeded right after world creation
                var animals := 0
                var kinds := {}
                for m in main.mobs.mobs:
                        if not main.mobs.KINDS[m.kind].hostile:
                                animals += 1
                                kinds[m.kind] = true
                print("SIM-ANIMALS n=%d kinds=%s" % [animals, str(kinds.keys())])
        if frames == 315 and main.hud:
                # joystick inversion test: drag UP must be forward (y > 0)
                main.hud._update_joy(Vector2(110, 110 - 60))
                var up_y: float = main.hud.joy_vec.y
                main.hud._update_joy(Vector2(110, 110 + 60))
                var down_y: float = main.hud.joy_vec.y
                main.hud.joy_vec = Vector2.ZERO
                var ok := up_y > 0.5 and down_y < -0.5
                print("SIM-JOY up=%.2f down=%.2f -> %s" % [up_y, down_y, "OK" if ok else "INVERTED-FAIL"])
        if frames == 320 and main.player:
                main.player.do_break()
        if frames == 330 and main.player:
                var n: int = main.player.count_of(Blocks.DIRT)
                print("SIM-DROP dirt_after_break=%d -> %s" % [n, "OK" if n > 32 else "FAIL"])
        if frames == 335 and main.player:
                var before: int = main.player.count_of(Blocks.DIRT)
                main.player.do_place(Blocks.DIRT)
                var after: int = main.player.count_of(Blocks.DIRT)
                var res := "OK" if after == before - 1 else ("NO-TARGET (consistent)" if after == before else "FAIL")
                print("SIM-PLACE before=%d after=%d -> %s" % [before, after, res])
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
                print("  inv=", main.player.inv, " hotbar=", main.player.hotbar)
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
                print("  inv=", main.player.inv, " hotbar=", main.player.hotbar)
                main.save_game()
                print("SIM-OK")
                return true
        if frames > 2000:
                print("SIM-TIMEOUT")
                return true
        return false
