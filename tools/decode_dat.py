#!/usr/bin/env python3
"""Dekodiert die DAT-Dateien von Der Clou! (Original-DOS-Daten).

Aufbau laut Quellcode (cosp, database.c, dbLoadAllObjects / dbLoadOrSaveObject):
- Jeder Datensatz beginnt mit drei 32-Bit-Werten (nr, type, size), Little-Endian (wie auf dem PC).
- Danach folgen die Felder des Typs (Größe je Typ, siehe SAVE_SIZE).
- nr 0xFFFFFFFF bzw. type 0xFFFFFFFF beendet die Liste (Füllwerte).

Aufruf: python3 decode_dat.py <Datei.DAT> [--json]
"""
import json
import struct
import sys

HEADER = "<III"
HEADER_SIZE = 12

TYPES = {
    9900: "Person", 9901: "Player", 9902: "Car", 9903: "Location", 9904: "Ability",
    9905: "Item", 9906: "Tool", 9907: "Environment", 9908: "London", 9909: "Evidence",
    9910: "Loot", 9911: "CompleteLoot", 9912: "LSOLock", 9913: "LSObject",
    509990: "Building", 509991: "Police", 509992: "LSArea", 509993: "LSRoom",
}

# Felder je Typ: (Name, Format). Format wie struct, hier Little-Endian (<).
FIELDS = {
    "Building": [
        ("LocationNr", "<I"), ("PoliceTime", "<H"), ("GTime", "<H"), ("Exactlyness", "<B"),
        ("GRate", "<B"), ("Strike", "<B"), ("Values", "<I"), ("EscapeRoute", "<H"),
        ("EscapeRouteLength", "<B"), ("RadioGuarding", "<B"), ("MaxVolume", "<B"),
        ("GuardStrength", "<B"), ("CarXPos", "<H"), ("CarYPos", "<H"),
    ],
    "LSArea": [
        ("Coll16ID", "<H"), ("Coll32ID", "<H"), ("Coll48ID", "<H"), ("PlanColl16ID", "<H"),
        ("PlanColl32ID", "<H"), ("PlanColl48ID", "<H"), ("FloorCollID", "<H"), ("PlanFloorCollID", "<H"),
        ("Width", "<H"), ("Height", "<H"), ("ObjectBaseNr", "<I"), ("Darkness", "<B"),
        ("StartX0", "<H"), ("StartX1", "<H"), ("StartX2", "<H"), ("StartX3", "<H"), ("StartX4", "<H"), ("StartX5", "<H"),
        ("StartY0", "<H"), ("StartY1", "<H"), ("StartY2", "<H"), ("StartY3", "<H"), ("StartY4", "<H"), ("StartY5", "<H"),
    ],
    "LSRoom": [("LeftEdge", "<H"), ("TopEdge", "<H"), ("Width", "<H"), ("Height", "<H")],
    "LSObject": [
        ("OffsetFact", "<H"), ("DestX", "<H"), ("DestY", "<H"), ("ExactX", "<B"), ("ExactY", "<B"),
        ("ExactX1", "<B"), ("ExactY1", "<B"), ("Size", "<B"), ("Visible", "<B"), ("Chained", "<B"),
        ("Status", "<I"), ("Type", "<I"),
    ],
    "LSOLock": [("Type", "<H")],
    "Police": [("PictID", "<H"), ("LivingID", "<B")],
    "Location": [("LocationNr", "<I"), ("OpenFromMinute", "<H"), ("OpenToMinute", "<H")],
    "Tool": [("PictID", "<H"), ("Value", "<I"), ("Danger", "<B"), ("Volume", "<B"), ("Effect", "<B")],
    "Loot": [("Type", "<H"), ("Name", "<H"), ("Volume", "<I"), ("Weight", "<H"), ("PictID", "<H")],
}

# Datensatzgröße je Typ (aus dbGetObjSaveSize, Standard-Diskette)
SAVE_SIZE = {
    "Item": 22, "London": 1, "Evidence": 48, "CompleteLoot": 48, "Ability": 6,
    "Environment": 7, "Player": 31, "Tool": 9, "LSOLock": 2, "LSObject": 21, "Loot": 12,
    "LSRoom": 8, "Building": 25, "Police": 3, "LSArea": 49,
}


def _fields_size(name):
    return sum(struct.calcsize(fmt) for _, fmt in FIELDS.get(name, []))


def decode(path):
    data = open(path, "rb").read()
    records = []
    pos = 0
    while pos + HEADER_SIZE <= len(data):
        nr, typ, size = struct.unpack_from(HEADER, data, pos)
        pos += HEADER_SIZE
        if nr == 0xFFFFFFFF or typ == 0xFFFFFFFF or size == 0xFFFFFFFF:
            break
        name = TYPES.get(typ, f"unbekannt_{typ}")
        body = data[pos:pos + size]
        pos += size
        rec = {"nr": nr, "type": name, "size": size, "raw": body.hex()}
        fields = FIELDS.get(name, [])
        if name == "Building" and size == SAVE_SIZE["Building"] + 1:
            fields = fields + [("DiskId", "<B")]   # Profi-Version mit Datenträger-Kennung
        if name in FIELDS and size == sum(struct.calcsize(f) for _, f in fields):
            vals = {}
            off = 0
            for fname, fmt in fields:
                n = struct.calcsize(fmt)
                vals[fname] = struct.unpack_from(fmt, body, off)[0]
                off += n
            rec["fields"] = vals
        records.append(rec)
    return records


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    recs = decode(sys.argv[1])
    if "--json" in sys.argv:
        print(json.dumps(recs, indent=1, ensure_ascii=False))
        return 0
    counts = {}
    for r in recs:
        counts[r["type"]] = counts.get(r["type"], 0) + 1
    print("Datensätze:", len(recs), counts)
    for r in recs:
        if "fields" in r:
            print(r["nr"], r["type"], r["fields"])
        else:
            print(r["nr"], r["type"], "size", r["size"], "(nicht dekodiert)" if r["type"] not in FIELDS else "(Größe weicht ab)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
