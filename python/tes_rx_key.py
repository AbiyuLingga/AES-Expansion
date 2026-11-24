"""Send one valid AES master key; print bytes received from FPGA (no parsing assumption)."""
import argparse
import time
try:
 import serial
except ImportError:
 raise SystemExit('Install: python -m pip install pyserial')

def main():
 ap=argparse.ArgumentParser()
 ap.add_argument('--port',default='COM8')
 ap.add_argument('--baud',type=int,default=115200)
 ap.add_argument('--key',default='2B7E151628AED2A6ABF7158809CF4F3C')
 a=ap.parse_args()
 try:
  key=bytes.fromhex(a.key)
 except ValueError:
  ap.error('Key must contain 32 hexadecimal digits')
 if len(key)!=16:ap.error('Key must be 16 bytes exactly')
 cmd=b'K'+key.hex().upper().encode('ascii')+b'\n'
 print('IMPORTANT: Program .sof from 01_AES_FULL_DUPLEX. Idle display = F128.')
 print('After KEY0 reset LEDG1, LEDG2, LEDG3 should be OFF.')
 print('Sending:', repr(cmd),'over',a.port,'@',a.baud)
 try:
  with serial.Serial(a.port,a.baud,timeout=0.4,write_timeout=2, xonxoff=False,
                     rtscts=False,dsrdtr=False) as dev:
   dev.reset_input_buffer()
   dev.write(cmd)
   dev.flush()
   t=time.monotonic()+8
   total=bytearray()
   while time.monotonic()<t and total.count(b'\n')<11:
    raw=dev.read(128)
    if raw:
     total.extend(raw)
     print('[RX]',repr(raw))
   if total:
    print('\nDecoded output:\n'+total.decode('ascii',errors='replace'))
   else:
    print('NO RESPONSE. Inspect LEDs: 1=RX edge, 2=UART byte, 3=valid key, 0=AES done.')
 except serial.SerialException as e:
  print('ERROR opening serial:',e)
if __name__=='__main__':main()
