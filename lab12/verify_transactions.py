"""Два независимых подключения libpq без дополнительных Python-пакетов."""
import ctypes as C
import os
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import time
import json

os.add_dll_directory(r'D:\Programms1\PostgreSQL\bin')
pq = C.CDLL(r'D:\Programms1\PostgreSQL\bin\libpq.dll')
def bind(name, restype, args):
    f = getattr(pq, name); f.restype = restype; f.argtypes = args; return f
connect = bind('PQconnectdb',C.c_void_p,[C.c_char_p])
status = bind('PQstatus',C.c_int,[C.c_void_p])
execute = bind('PQexec',C.c_void_p,[C.c_void_p,C.c_char_p])
rstatus = bind('PQresultStatus',C.c_int,[C.c_void_p])
error = bind('PQerrorMessage',C.c_char_p,[C.c_void_p])
rerror = bind('PQresultErrorMessage',C.c_char_p,[C.c_void_p])
field = bind('PQresultErrorField',C.c_char_p,[C.c_void_p,C.c_int])
rows = bind('PQntuples',C.c_int,[C.c_void_p]); cols=bind('PQnfields',C.c_int,[C.c_void_p])
value = bind('PQgetvalue',C.c_char_p,[C.c_void_p,C.c_int,C.c_int])
clear=bind('PQclear',None,[C.c_void_p]); finish=bind('PQfinish',None,[C.c_void_p])
class DB:
    def __init__(self,name):
        self.conn=connect(f'host=127.0.0.1 port=5433 dbname=olist user=student password=student application_name=lab12_{name}'.encode())
        if status(self.conn): raise RuntimeError(error(self.conn).decode())
        self.q('SET statement_timeout=15000')
    def q(self,sql):
        r=execute(self.conn,sql.encode('utf-8'))
        try:
            if rstatus(r) not in (1,2):
                state=field(r,ord('C'))
                raise RuntimeError((state or b'').decode()+': '+rerror(r).decode())
            return [[value(r,i,j).decode() for j in range(cols(r))] for i in range(rows(r))]
        finally: clear(r)
    def close(self): finish(self.conn)

log=[]
def record(label,data): log.append({'experiment':label,'result':data}); print(label,data,flush=True)
a=DB('A'); b=DB('B'); observer=DB('observer')
p1,p2=[r[0] for r in a.q('SELECT product_id FROM lab.inventory ORDER BY product_id LIMIT 2')]
saved=a.q(f"SELECT product_id,qty,version FROM lab.inventory WHERE product_id IN ('{p1}','{p2}') ORDER BY product_id")
pool=ThreadPoolExecutor(2)
def qty(db=a): return int(db.q(f"SELECT qty FROM lab.inventory WHERE product_id='{p1}'")[0][0])
def reset():
    a.q('ROLLBACK'); b.q('ROLLBACK')
    a.q(f"UPDATE lab.inventory SET qty=10,version=0 WHERE product_id IN ('{p1}','{p2}')")
try:
    record('pids',{'A':a.q('SELECT pg_backend_pid()')[0][0],'B':b.q('SELECT pg_backend_pid()')[0][0]})
    reset(); a.q('BEGIN'); b.q('BEGIN'); qa=qty(a); qb=qty(b)
    a.q(f"UPDATE lab.inventory SET qty={qa-1} WHERE product_id='{p1}'"); a.q('COMMIT')
    b.q(f"UPDATE lab.inventory SET qty={qb-1} WHERE product_id='{p1}'"); b.q('COMMIT')
    record('lost_update',{'read_A':qa,'read_B':qb,'actual':qty(),'expected':8})
    reset(); a.q('BEGIN'); b.q('BEGIN')
    a.q(f"SELECT qty FROM lab.inventory WHERE product_id='{p1}' FOR UPDATE")
    future=pool.submit(b.q,f"SELECT qty FROM lab.inventory WHERE product_id='{p1}' FOR UPDATE")
    time.sleep(.3)
    blocked=observer.q("SELECT application_name,wait_event_type,wait_event FROM pg_stat_activity WHERE application_name='lab12_B'")
    record('row_lock_wait',{'B_waiting':not future.done(),'activity':blocked})
    a.q(f"UPDATE lab.inventory SET qty=qty-1 WHERE product_id='{p1}'"); a.q('COMMIT')
    record('locked_B_read',future.result())
    b.q(f"UPDATE lab.inventory SET qty=qty-1 WHERE product_id='{p1}'"); b.q('COMMIT')
    record('locked_final_qty',qty())
    reset(); a.q(f"UPDATE lab.inventory SET qty=1 WHERE product_id='{p1}'")
    reserve=f"UPDATE lab.inventory SET qty=qty-1,version=version+1 WHERE product_id='{p1}' AND qty>0 RETURNING qty"
    fa=pool.submit(a.q,reserve); fb=pool.submit(b.q,reserve)
    record('atomic_last_unit',{'A':fa.result(),'B':fb.result(),'final':qty()})
    for level in ('READ COMMITTED','REPEATABLE READ'):
        reset(); a.q('BEGIN ISOLATION LEVEL '+level); before=qty()
        b.q(f"UPDATE lab.inventory SET qty=9 WHERE product_id='{p1}'")
        after=qty(); a.q('COMMIT')
        record(level,{'before':before,'after':after})
    reset(); a.q('BEGIN ISOLATION LEVEL READ COMMITTED')
    before=a.q("SELECT count(*) FROM lab.inventory_movements WHERE experiment='lab12_verify'")
    b.q(f"INSERT INTO lab.inventory_movements(product_id,delta,experiment) VALUES('{p1}',1,'lab12_verify')")
    after=a.q("SELECT count(*) FROM lab.inventory_movements WHERE experiment='lab12_verify'"); a.q('COMMIT')
    record('phantom',{'before':before,'after':after})
    reset(); a.q('BEGIN'); b.q('BEGIN')
    a.q(f"UPDATE lab.inventory SET version=version+1 WHERE product_id='{p1}'")
    b.q(f"UPDATE lab.inventory SET version=version+1 WHERE product_id='{p2}'")
    fa=pool.submit(a.q,f"UPDATE lab.inventory SET version=version+1 WHERE product_id='{p2}'")
    time.sleep(.2)
    fb=pool.submit(b.q,f"UPDATE lab.inventory SET version=version+1 WHERE product_id='{p1}'")
    outcomes={}
    # Разблокировать выжившего сразу после отката жертвы, независимо от выбора PostgreSQL.
    while not fa.done() and not fb.done(): time.sleep(.05)
    for name,db,f in [('A',a,fa),('B',b,fb)]:
        if f.done():
            try: outcomes[name]=f.result(); db.q('COMMIT')
            except RuntimeError as ex: outcomes[name]=str(ex); db.q('ROLLBACK')
    for name,db,f in [('A',a,fa),('B',b,fb)]:
        if name not in outcomes:
            try: outcomes[name]=f.result(timeout=5); db.q('COMMIT')
            except RuntimeError as ex: outcomes[name]=str(ex); db.q('ROLLBACK')
    record('deadlock',outcomes)
    reset(); a.q('BEGIN ISOLATION LEVEL SERIALIZABLE'); b.q('BEGIN ISOLATION LEVEL SERIALIZABLE')
    qty(a); qty(b)
    a.q(f"UPDATE lab.inventory SET qty=qty-1 WHERE product_id='{p1}'"); a.q('COMMIT')
    try: b.q(f"UPDATE lab.inventory SET qty=qty-1 WHERE product_id='{p1}'"); b.q('COMMIT')
    except RuntimeError as ex:
        record('serialization_failure',str(ex)); b.q('ROLLBACK')
        b.q('BEGIN ISOLATION LEVEL SERIALIZABLE'); b.q(reserve); b.q('COMMIT')
        record('serialization_retry_qty',qty())
finally:
    a.q('ROLLBACK'); b.q('ROLLBACK')
    for pid,q,v in saved: a.q(f"UPDATE lab.inventory SET qty={q},version={v} WHERE product_id='{pid}'")
    a.q("DELETE FROM lab.inventory_movements WHERE experiment='lab12_verify'")
    record('restored',a.q(f"SELECT product_id,qty,version FROM lab.inventory WHERE product_id IN ('{p1}','{p2}') ORDER BY product_id"))
    for db in (a,b,observer): db.close()
    pool.shutdown()
    out=Path(__file__).resolve().with_name('transactions.json'); out.write_text(json.dumps(log,ensure_ascii=False,indent=2),encoding='utf-8')
