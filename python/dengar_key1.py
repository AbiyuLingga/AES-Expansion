"""Read FPGA key schedule after manually pressing KEY1. TX-only path test."""
import argparse
import re
import time
try: import serial
except ImportError: raise SystemExit('Install: python -m pip install pyserial')
from aes_reference import NIST_KEY, SEQ_KEY, key_expansion
p=argparse.ArgumentParser()
p.add_argument('--port',default='COM8')
p.add_argument('--key',choices=['nist','seq'],default='nist')
a=p.parse_args()
ref=key_expansion(bytes.fromhex(NIST_KEY if a.key=='nist' else SEQ_KEY))
with serial.Serial(a.port,115200,timeout=0.3,xonxoff=False,rtscts=False,dsrdtr=False) as s:
 s.reset_input_buffer()
 input('Open. Set SW7='+('0' if a.key=='nist' else '1')+'; press ENTER then press KEY1 FPGA... ')
 observed={}
 deadline=time.monotonic()+12
 while time.monotonic()<deadline and len(observed)<11:
  packet=s.readline()
  if not packet: continue
  line=packet.decode('ascii','replace').strip()
  m=re.fullmatch(r'K(\d\d):([a-fA-F0-9]{32})',line)
  if not m:
   print('Other RX:',repr(line))
   continue
  k=int(m.group(1))
  if 0<=k<=10:
   observed[k]=m.group(2).upper()
   print(f'K{k:02}: {observed[k]}', 'PASS' if observed[k]==ref[k] else 'FAIL')
 print(f'Received {len(observed)}/11 key lines')
