"""Test PC TX -> DE1 UART_RXD -> DE1 UART_TXD -> PC RX.
REQUIRES de1_uart_echo.sof from 02_TES_UART_RX_ECHO, not AES .sof.
"""
import argparse
import time
try:
    import serial
except ImportError:
    raise SystemExit('Install: python -m pip install pyserial')

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--port',default='COM8')
    p.add_argument('--baud',type=int,default=115200)
    args=p.parse_args()
    payload=b'K'  # single byte: HEX1/HEX0 should display 4B; LEDG3 should latch.
    print('PROGRAM FPGA FIRST with de1_uart_echo.sof in 02_TES_UART_RX_ECHO!')
    print('Open',args.port,'@',args.baud,'8N1; send',payload)
    print('Close RealTerm, serial monitor, and other Python serial programs.')
    try:
        with serial.Serial(args.port,args.baud,timeout=1,write_timeout=2,
                           xonxoff=False,rtscts=False,dsrdtr=False) as dev:
            dev.reset_input_buffer()
            time.sleep(0.05)
            dev.write(payload)
            dev.flush()
            received=dev.read(len(payload))
            print('RX RAW:',repr(received))
            if received==payload:
                print('PASS: PC TX -> FPGA RX -> FPGA TX -> PC RX is connected.')
                print('FPGA seven-seg should show E04B; LEDG1/2/3 should be ON.')
            else:
                print('FAIL: echo not received. The FPGA RX signal or cable path is suspect.')
                print('Check FPGA shows E000 after programming. Re-test with KEY0 reset.')
    except serial.SerialException as exc:
        print('SERIAL ERROR:',exc)
if __name__=='__main__':
    main()
