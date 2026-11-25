import copy
import json
import math
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "engine"))

from heist_sim import HeistSimulation  # noqa: E402

DATA_PATH = os.path.join(HERE, "..", "data", "heist_rc1.json")


def load_data():
    with open(DATA_PATH, encoding="utf-8") as f:
        return json.load(f)


class FormulaTests(unittest.TestCase):
    def setUp(self):
        self.sim = HeistSimulation(load_data())
        self.matt = self.sim.state["crew"][0]

    def test_lockpick_on_door_formula(self):
        # Komplexitaet 35, TECH 65, base_time 15, base_noise 5
        r = self.sim.execute_tool(self.matt, "tool_lockpick", "node_backdoor")
        self.assertTrue(r["success"])
        self.assertAlmostEqual(r["duration_sec"], 11.47, places=2)
        # Lärm: 5 * (1+35/200) * (1-65/200) * Sneakers 0.4
        self.assertAlmostEqual(r["noise_db"], 1.6, places=1)

    def test_gatekeeping_refuses_too_complex_object(self):
        sim = HeistSimulation(load_data())
        sim.state["security_network"]["nodes"]["node_safe"]["complexity"] = 100
        r = sim.execute_tool(sim.state["crew"][0], "tool_lockpick", "node_safe")
        self.assertFalse(r["success"])

    def test_gear_reduces_evidence(self):
        r_plain = HeistSimulation(load_data())
        plain_char = copy.deepcopy(r_plain.state["crew"][0])
        plain_char["gear"] = []
        plain = r_plain.execute_tool(plain_char, "tool_crowbar", "node_backdoor")
        geared = HeistSimulation(load_data()).execute_tool(
            load_data()["mission_state"]["crew"][0], "tool_crowbar", "node_backdoor")
        # Handschuhe (0.2) * Sneakers (0.5) = 0.1 -> 20 * 0.1 = 2.0 statt 20
        self.assertAlmostEqual(geared["evidence"], 2.0, places=2)
        self.assertAlmostEqual(plain["evidence"], 20.0, places=2)


class ScenarioTests(unittest.TestCase):
    """Die drei Szenarien aus dem Gameplay-Ablauf der Spezifikation."""

    def test_brute_force_crowbar_triggers_mic_alarm(self):
        sim = HeistSimulation(load_data())
        # Hacker ohne Sneakers: Brecheisen ist laut, zerstoert die Tuer, Mikrofon schlaegt an.
        sim.execute_tool(sim.state["crew"][1], "tool_crowbar", "node_backdoor")
        self.assertTrue(sim.state["security_network"]["nodes"]["node_backdoor"]["is_destroyed"])
        self.assertEqual(sim.state["police_countdown_sec"], 60.0)
        self.assertTrue(any("sensor_mic_01" in e for e in sim.events))

    def test_crowbar_with_sneakers_is_silent_finding(self):
        # BEFUND RC1: Matts Sneakers (Laerm x0.4) machen das Brecheisen am Mikrofon vorbei leise.
        sim = HeistSimulation(load_data())
        r = sim.execute_tool(sim.state["crew"][0], "tool_crowbar", "node_backdoor")
        self.assertLess(r["noise_db"], 25)
        self.assertIsNone(sim.state["police_countdown_sec"])

    def test_quiet_lockpick_stays_under_mic_threshold(self):
        sim = HeistSimulation(load_data())
        sim.execute_tool(sim.state["crew"][0], "tool_lockpick", "node_backdoor")
        self.assertIsNone(sim.state["police_countdown_sec"])
        self.assertTrue(sim.state["security_network"]["sensors"]["sensor_mic_01"]["active"])

    def test_cut_phone_then_bypass_alarm_disables_mic(self):
        sim = HeistSimulation(load_data())
        matt, tech = sim.state["crew"][0], sim.state["crew"][1]
        sim.execute_tool(matt, "tool_wirecutters", "node_phone_box")
        self.assertFalse(sim.state["security_network"]["phone_line_intact"])
        sim.execute_tool(tech, "tool_bypass_kit", "node_alarm_panel")
        self.assertFalse(sim.state["security_network"]["sensors"]["sensor_mic_01"]["active"])
        self.assertTrue(sim.state["security_network"]["nodes"]["node_alarm_panel"]["is_bypassed"])


class AiTests(unittest.TestCase):
    def test_state_thresholds(self):
        sim = HeistSimulation(load_data())
        guard = sim.state["ai_entities"][0]
        sim.update_ai_suspicion(guard, 10)
        self.assertEqual(guard["state"], "ALERT")
        sim.update_ai_suspicion(guard, 40)
        self.assertEqual(guard["state"], "INVESTIGATE")

    def test_alarm_chain_with_cut_phone_adds_20s(self):
        sim = HeistSimulation(load_data())
        sim.state["security_network"]["phone_line_intact"] = False
        guard = sim.state["ai_entities"][0]
        sim.update_ai_suspicion(guard, 100)
        self.assertEqual(guard["state"], "ALARMED")
        # 60 s Polizeizeit + 4 s Reaktion + 20 s Sabotage-Bonus
        self.assertEqual(sim.state["police_countdown_sec"], 84.0)

    def test_street_patrol_alarm_is_fast(self):
        sim = HeistSimulation(load_data())
        patrol = sim.state["ai_entities"][1]
        sim.update_ai_suspicion(patrol, 100)
        self.assertAlmostEqual(sim.state["police_countdown_sec"], 12.0 + 1.5)

    def test_noise_makes_guard_investigate_not_alarm(self):
        sim = HeistSimulation(load_data())
        sim.execute_tool(sim.state["crew"][1], "tool_crowbar", "node_backdoor")
        guard = sim.state["ai_entities"][0]
        self.assertEqual(guard["state"], "INVESTIGATE")

    def test_destroyed_door_doubles_vision_effect(self):
        sim = HeistSimulation(load_data())
        guard = sim.state["ai_entities"][0]
        char = sim.state["crew"][1]  # ohne Sneakers, Vis 1.0
        base = sim.evaluate_vision(guard, char, (guard["pos"][0], guard["pos"][1]), False)
        guard["suspicion"] = 0.0
        guard["state"] = "PATROL"
        doubled = sim.evaluate_vision(guard, char, (guard["pos"][0], guard["pos"][1]), True)
        self.assertAlmostEqual(doubled, base * 2.5, places=6)

    def test_dark_suit_reduces_visibility(self):
        sim = HeistSimulation(load_data())
        guard = sim.state["ai_entities"][0]
        char = copy.deepcopy(sim.state["crew"][1])
        char["gear"] = ["gear_dark_suit"]
        v = sim.evaluate_vision(guard, char, guard["pos"], False)
        self.assertAlmostEqual(v, 40.0 * 0.7, places=6)

    def test_out_of_vision_range_is_zero(self):
        sim = HeistSimulation(load_data())
        guard = sim.state["ai_entities"][0]
        far = (guard["pos"][0] + 100, guard["pos"][1])
        self.assertEqual(sim.evaluate_vision(guard, sim.state["crew"][1], far), 0.0)

    def test_decay_lowers_suspicion_but_not_alarm(self):
        sim = HeistSimulation(load_data())
        guard = sim.state["ai_entities"][0]
        sim.update_ai_suspicion(guard, 20)
        sim.decay(5)
        self.assertEqual(guard["suspicion"], 10.0)
        sim.update_ai_suspicion(guard, 100)
        sim.decay(10)
        self.assertEqual(guard["state"], "ALARMED")


class TimingTests(unittest.TestCase):
    def test_escape_succeeds_if_driver_arrives_before_police(self):
        sim = HeistSimulation(load_data())
        sim.state["police_countdown_sec"] = 60.0
        sim.call_getaway_driver()
        self.assertTrue(sim.escape_possible())

    def test_escape_fails_if_police_arrives_first(self):
        sim = HeistSimulation(load_data())
        sim.state["police_countdown_sec"] = 10.0
        sim.call_getaway_driver()
        self.assertFalse(sim.escape_possible())

    def test_police_countdown_ticks_to_zero(self):
        sim = HeistSimulation(load_data())
        sim.state["police_countdown_sec"] = 2.0
        self.assertFalse(sim.tick_police(1.0))
        self.assertTrue(sim.tick_police(1.5))
        self.assertEqual(sim.state["police_countdown_sec"], 0.0)


class DataTests(unittest.TestCase):
    def test_input_data_is_not_mutated(self):
        data = load_data()
        snapshot = copy.deepcopy(data)
        sim = HeistSimulation(data)
        sim.execute_tool(sim.state["crew"][0], "tool_crowbar", "node_backdoor")
        self.assertEqual(data, snapshot)

    def test_json_file_is_valid_and_complete(self):
        data = load_data()
        self.assertIn("game_balancing_config", data)
        self.assertIn("mission_state", data)
        self.assertEqual(len(data["mission_state"]["ai_entities"]), 2)
        for ai in data["mission_state"]["ai_entities"]:
            self.assertTrue(all(math.isfinite(c) for c in ai["pos"]))


if __name__ == "__main__":
    unittest.main()
