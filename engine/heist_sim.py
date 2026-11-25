"""Der Einbruch - Simulations-Engine RC1.

Verbindet Werkzeug-/Sabotage-Formeln, Lärmausbreitung, KI-Wahrnehmung,
Alarm-Kette und Fluchtwagen-Timing. Reine Logik ohne Engine-Abhängigkeit,
damit sie in Godot später 1:1 portiert oder über Tests geprüft werden kann.

Alle Formeln entsprechen der RC1-Spezifikation (docs/GDD_RC1.md).
"""

import copy
import math

ALARM_STATES = ("PATROL", "ALERT", "INVESTIGATE", "ALARMED")
STREET_PATROL = "STREET_PATROL"
INDOOR_GUARD = "INDOOR_GUARD"


class HeistSimulation:
    def __init__(self, data):
        # Tiefe Kopie, damit die geladene Datei nie verändert wird.
        data = copy.deepcopy(data)
        self.cfg = data["game_balancing_config"]
        self.state = data["mission_state"]
        self.events = []  # Protokoll aller Ereignisse (für Tests und Debug-UI)

    # ------------------------------------------------------------------
    # Hilfsfunktionen
    # ------------------------------------------------------------------
    def _log(self, text):
        self.events.append(text)

    def _gear(self, char):
        return [self.cfg["passive_gear"][g] for g in char.get("gear", [])]

    def char_visibility(self, char):
        """Multiplikator für Sichtbarkeit (Kleidung). Kleinster Wert gewinnt."""
        mult = 1.0
        for g in self._gear(char):
            mult = min(mult, g["vis_mult"])
        return mult

    # ------------------------------------------------------------------
    # 1. WERKZEUG- & SABOTAGE-LOGIK
    # ------------------------------------------------------------------
    def execute_tool(self, char, tool_id, target_id):
        tool = self.cfg["tools"][tool_id]
        target = self.state["security_network"]["nodes"][target_id]
        skill = char["skills"].get(tool["type"], 1)

        # Objektwert je nach Werkzeugtyp: Komplexität (TECH/ELEKTRONIK) oder Widerstand (FORCE)
        if tool["type"] in ("TECH", "ELECTRONICS"):
            obj_val = target.get("complexity", 0)
        else:
            obj_val = target.get("resistance", 0)

        # Gatekeeping: Werkzeug reicht für dieses Objekt nicht aus
        if obj_val > tool["max_level"]:
            return {"success": False, "reason": "Objekt zu komplex/stabil fuer dieses Werkzeug."}

        duration = tool["base_time"] * (1 + obj_val / 100.0) * (1 - skill / 150.0)
        noise = tool["base_noise"] * (1 + obj_val / 200.0) * (1 - skill / 200.0)

        ev_mult, noise_mult = 1.0, 1.0
        for g in self._gear(char):
            ev_mult *= g["evidence_mult"]
            noise_mult *= g["noise_mult"]

        final_noise = noise * noise_mult
        final_evidence = tool["evidence"] * ev_mult
        self.state["total_evidence"] += final_evidence

        if tool["destroys"]:
            target["is_destroyed"] = True

        # Zustandsänderungen und Sabotage-Effekte
        if target["type"] == "DOOR":
            target["is_locked"] = False
            target["is_open"] = True
        elif target["type"] == "PHONE_LINE":
            self.state["security_network"]["phone_line_intact"] = False
        elif target["type"] == "ALARM_PANEL":
            target["is_bypassed"] = True
            for s_id in target.get("controls", []):
                self.state["security_network"]["sensors"][s_id]["active"] = False
        elif target["type"] == "SAFE" and not target.get("is_destroyed"):
            target["is_locked"] = False

        self._log(f"{char['id']} nutzt {tool_id} an {target_id}: {duration:.2f}s, {final_noise:.1f} dB")

        # Lärm an Umgebung senden (Quelle: Objektposition, sonst Position der Figur)
        origin = target.get("pos", char["pos"])
        self.broadcast_noise(origin, final_noise)

        return {
            "success": True,
            "duration_sec": round(duration, 2),
            "noise_db": round(final_noise, 1),
            "evidence": round(final_evidence, 2),
        }

    def close_door(self, target_id):
        target = self.state["security_network"]["nodes"][target_id]
        target["is_open"] = False
        return {"success": True}

    # ------------------------------------------------------------------
    # 2. LÄRMAUSBREITUNG & SENSOREN
    # ------------------------------------------------------------------
    def _arriving_noise(self, origin, pos, noise_level, walls_between):
        ai_rules = self.cfg["ai_rules"]
        dist = math.dist(origin, pos)
        return (noise_level
                - dist * ai_rules["distance_damping_per_m"]
                - walls_between * ai_rules["wall_damping_db"])

    def broadcast_noise(self, origin_pos, noise_level, walls_between=1):
        # Sensoren (z. B. Mikrofone)
        for s_id, sensor in self.state["security_network"]["sensors"].items():
            if not sensor["active"]:
                continue
            arriving = self._arriving_noise(origin_pos, sensor["pos"], noise_level, walls_between)
            if arriving > sensor["threshold"]:
                self.trigger_alarm(source=s_id, kind="SENSOR")

        # KI-Entitäten (Wachen und Streifen)
        for ai in self.state["ai_entities"]:
            arriving = self._arriving_noise(origin_pos, ai["pos"], noise_level, walls_between)
            if arriving > ai["hearing_threshold"]:
                gain = (arriving - ai["hearing_threshold"]) * 2.5
                self.update_ai_suspicion(ai, gain)

    # ------------------------------------------------------------------
    # 3. KI-WAHRNEHMUNG (SICHT & VERDACHT)
    # ------------------------------------------------------------------
    def evaluate_vision(self, ai, char, target_pos, is_destroyed_door=False, is_dark=False, dt=1.0):
        dist = math.dist(ai["pos"], target_pos)
        if dist > ai["core_vision_m"]:
            return 0.0

        light_factor = 0.2 if is_dark else 1.0
        status_mult = self.cfg["ai_rules"]["destroyed_door_vis_mult"] if is_destroyed_door else 1.0
        vis_mult = self.char_visibility(char)

        vis_rate = 40.0 * (1.0 - dist / ai["core_vision_m"]) * light_factor * status_mult * vis_mult
        self.update_ai_suspicion(ai, vis_rate * dt)
        return vis_rate * dt

    def decay(self, dt):
        """Verdachtsabbau über die Zeit (Rate aus ai_rules)."""
        rate = self.cfg["ai_rules"]["suspicion_decay_per_sec"]
        for ai in self.state["ai_entities"]:
            if ai["state"] != "ALARMED":
                self.update_ai_suspicion(ai, -rate * dt)

    def update_ai_suspicion(self, ai, amount):
        if ai["state"] == "ALARMED":
            return  # Ausgelöster Alarm wird nicht mehr zurückgenommen
        ai["suspicion"] = min(100.0, max(0.0, ai["suspicion"] + amount))
        s = ai["suspicion"]

        if s == 0:
            ai["state"] = "PATROL"
        elif s < 40:
            ai["state"] = "ALERT"          # bleibt stehen, lauscht
        elif s < 80:
            ai["state"] = "INVESTIGATE"    # läuft zur Lärmquelle / offenen Tür
        else:
            ai["state"] = "ALARMED"
            delay = ai["reaction_delay_sec"]
            # Gekappte Telefonleitung: Wache muss nach draußen rennen (+20 s)
            if ai["type"] == INDOOR_GUARD and not self.state["security_network"]["phone_line_intact"]:
                delay += 20.0
            kind = "PATROL" if ai["type"] == STREET_PATROL else "GUARD"
            self.trigger_alarm(source=ai["id"], kind=kind, delay=delay)

    # ------------------------------------------------------------------
    # 4. ALARM-KETTE & POLIZEI-COUNTDOWN
    # ------------------------------------------------------------------
    def trigger_alarm(self, source, kind="GUARD", delay=0.0):
        if self.state["police_countdown_sec"] is not None:
            return  # Countdown läuft bereits

        # Streife löst Alarm aus: Polizei ist sofort in der Nähe
        base = 12.0 if kind == "PATROL" else self.state["district_police_response_sec"]
        self.state["police_countdown_sec"] = base + delay
        self._log(f"ALARM durch {source}: Polizei in {self.state['police_countdown_sec']:.1f}s")

    def tick_police(self, dt):
        """Läuft den Polizei-Countdown herunter. True, wenn die Polizei da ist."""
        cd = self.state["police_countdown_sec"]
        if cd is None:
            return False
        cd -= dt
        if cd <= 0:
            self.state["police_countdown_sec"] = 0.0
            self._log("POLIZEI RIEGELT GEBAEUDE AB")
            return True
        self.state["police_countdown_sec"] = cd
        return False

    # ------------------------------------------------------------------
    # 5. FLUCHTWAGEN-TIMING
    # ------------------------------------------------------------------
    def call_getaway_driver(self):
        self.state["driver"]["status"] = "EN_ROUTE_TO_PICKUP"
        eta = self.state["driver"]["pickup_eta_sec"]
        self._log(f"Fluchtwagen angefordert, Ankunft in {eta:.1f}s")
        return eta

    def escape_possible(self):
        """Flucht gelingt, wenn der Wagen vor Ablauf des Countdowns ankommt."""
        cd = self.state["police_countdown_sec"]
        eta = self.state["driver"]["pickup_eta_sec"]
        if self.state["driver"]["status"] == "EN_ROUTE_TO_PICKUP":
            return cd is None or cd >= eta
        return False
