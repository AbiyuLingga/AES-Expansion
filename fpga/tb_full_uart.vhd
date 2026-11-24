-- Full UART protocol simulation at 1 Mbaud (FPGA hardware is 115200).
-- Test: Python-style K<32hex> LF -> AES core -> 11 ASCII round key lines.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tb_vectors_pkg.all;
entity tb_full_uart is end entity;
architecture sim of tb_full_uart is
  constant BIT_TIME : time := 1000 ns;
  signal clk : std_logic := '0';
  signal key0 : std_logic := '1';
  signal key1 : std_logic := '1';
  signal uart_rx : std_logic := '1';
  signal uart_tx : std_logic;
  signal led0,led1,led2,led3 : std_logic;
  signal passed : std_logic := '0';
  procedure send_byte(signal wire : out std_logic; ch : character) is
    variable n : integer := character'pos(ch);
  begin
    wire <= '0'; wait for BIT_TIME;
    for b in 0 to 7 loop
      if (n/(2**b)) mod 2 = 1 then wire<='1'; else wire<='0'; end if;
      wait for BIT_TIME;
    end loop;
    wire<='1'; wait for BIT_TIME;
  end procedure;
  procedure receive_byte(signal wire : in std_logic; variable ch : out character) is
    variable n : integer;
  begin
    wait until wire='0';
    wait for BIT_TIME + BIT_TIME/2;
    n:=0;
    for b in 0 to 7 loop
      if wire='1' then n:=n+2**b; end if;
      wait for BIT_TIME;
    end loop;
    assert wire='1' report "UART stop-bit error" severity failure;
    ch:=character'val(n);
  end procedure;
  signal sw : std_logic_vector(7 downto 0) := (others=>'0');
begin
  clk <= not clk after 10 ns;
  dut: entity work.aes_de1_fixed
    generic map(BAUD_RATE=>1000000)
    port map(CLOCK_50=>clk, KEY0=>key0, KEY1=>key1,
      SW0=>sw(0),SW1=>sw(1),SW2=>sw(2),SW3=>sw(3),
      SW4=>sw(4),SW5=>sw(5),SW6=>sw(6),SW7=>sw(7),
      UART_RXD=>uart_rx, UART_TXD=>uart_tx,
      LEDG0=>led0, LEDG1=>led1, LEDG2=>led2, LEDG3=>led3,
      HEX0_A=>open,HEX0_B=>open,HEX0_C=>open,HEX0_D=>open,
      HEX0_E=>open,HEX0_F=>open,HEX0_G=>open,
      HEX1_A=>open,HEX1_B=>open,HEX1_C=>open,HEX1_D=>open,
      HEX1_E=>open,HEX1_F=>open,HEX1_G=>open,
      HEX2_A=>open,HEX2_B=>open,HEX2_C=>open,HEX2_D=>open,
      HEX2_E=>open,HEX2_F=>open,HEX2_G=>open,
      HEX3_A=>open,HEX3_B=>open,HEX3_C=>open,HEX3_D=>open,
      HEX3_E=>open,HEX3_F=>open,HEX3_G=>open);
  sender: process
    constant command : string := "K2B7E151628AED2A6ABF7158809CF4F3C";
  begin
    wait for 1 us;
    for i in command'range loop
      send_byte(uart_rx,command(i));
    end loop;
    send_byte(uart_rx,character'val(10));
    wait;
  end process;
  receiver: process
    variable recv_ch : character;
    variable expected_line : string(1 to 38);
    variable d0,d1 : character;
  begin
    for r in 0 to 10 loop
      d0:=character'val(48+r/10);
      d1:=character'val(48+(r mod 10));
      expected_line:='K' & d0 & d1 & ':' & to_hex(KEYS_NIST(r)) &
                     character'val(13) & character'val(10);
      for n in 1 to 38 loop
        receive_byte(uart_tx,recv_ch);
        assert recv_ch=expected_line(n)
          report "UART mismatch on round " & integer'image(r) &
                 ", character " & integer'image(n) &
                 ": expected " & character'image(expected_line(n)) &
                 ", got " & character'image(recv_ch)
          severity failure;
      end loop;
    end loop;
    assert led0='1' report "LEDG0 ready never asserted" severity failure;
    passed<='1';
    report "PASS FULL UART: python-style key command -> FPGA -> all 11 NIST lines" severity note;
    wait;
  end process;
  watchdog: process
  begin
    wait for 6 ms;
    assert passed='1' report "FAIL: 11 UART lines not complete before 6ms" severity failure;
    report "PASS UART TEST FINISHED" severity note;
    wait;
  end process;
end architecture;
