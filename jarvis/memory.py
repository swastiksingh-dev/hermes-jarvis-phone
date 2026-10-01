#!/usr/bin/env python3
"""Light SQLite memory for 4GB phone. <100MB. stdlib only.
Usage: memory.py remember <text> | recall <query> [n] | list [n]
DB: ~/hermes-9i/memory/memory.db
"""
import os, sqlite3, sys, time
DB = os.path.expanduser("~/hermes-9i/memory/memory.db")
os.makedirs(os.path.dirname(DB), exist_ok=True)
con = sqlite3.connect(DB)
con.execute("CREATE TABLE IF NOT EXISTS mem(id INTEGER PRIMARY KEY, ts INTEGER, kind TEXT, text TEXT)")
con.execute("CREATE INDEX IF NOT EXISTS idx_mem_text ON mem(text)")
con.commit()

def remember(text, kind="note"):
    con.execute("INSERT INTO mem(ts,kind,text) VALUES(?,?,?)", (int(time.time()), kind, text))
    con.commit()
    # cap at 5000 rows for 4GB phone
    con.execute("DELETE FROM mem WHERE id NOT IN (SELECT id FROM mem ORDER BY id DESC LIMIT 5000)")
    con.commit()
    print("remembered")

def recall(q, n=5):
    # cheap LIKE recall (no embeddings = no RAM). Good enough for 9i.
    words = [w for w in q.split() if len(w) > 2][:6]
    if not words:
        rows = con.execute("SELECT text FROM mem ORDER BY id DESC LIMIT ?", (n,)).fetchall()
    else:
        like = " OR ".join(["text LIKE ?"] * len(words))
        rows = con.execute(f"SELECT text FROM mem WHERE {like} ORDER BY id DESC LIMIT ?", (["%"+w+"%" for w in words]+[n])).fetchall()
        if not rows:
            rows = con.execute("SELECT text FROM mem ORDER BY id DESC LIMIT ?", (n,)).fetchall()
    for r in rows: print("-", r[0][:500])

if __name__ == "__main__":
    if len(sys.argv) < 2: print(__doc__); sys.exit(1)
    if sys.argv[1] == "remember": remember(" ".join(sys.argv[2:]))
    elif sys.argv[1] == "recall": recall(" ".join(sys.argv[2:-1]) if sys.argv[-1].isdigit() else " ".join(sys.argv[2:]), int(sys.argv[-1]) if sys.argv[-1].isdigit() else 5)
    elif sys.argv[1] == "list": recall("", int(sys.argv[2]) if len(sys.argv) > 2 else 10)
