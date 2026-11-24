-- UART RX 8N1, LSB first; 50 MHz / 115200 nominal.
-- Two-flop input synchronizer and midpoint sampling.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity uart_rx_8n1 is
  generic (CLOCK_HZ : positive := 50000000; BAUD_RATE : positive := 115200);
  port (clk : in std_logic; rst : in std_logic; rx : in std_logic;
        data_out : out std_logic_vector(7 downto 0); data_valid : out std_logic);
end entity;
architecture rtl of uart_rx_8n1 is
  constant BIT_TICKS : positive := (CLOCK_HZ + BAUD_RATE/2)/BAUD_RATE;
  type state_t is (ST_IDLE, ST_START, ST_BITS, ST_STOP);
  signal state : state_t := ST_IDLE;
  signal ff1, ff2 : std_logic := '1';
  signal timer : integer range 0 to BIT_TICKS-1 := 0;
  signal bit_no : integer range 0 to 7 := 0;
  signal shreg : std_logic_vector(7 downto 0) := (others=>'0');
  signal data_r : std_logic_vector(7 downto 0) := (others=>'0');
  signal valid_r : std_logic := '0';
begin
  data_out <= data_r;
  data_valid <= valid_r;
  process(clk)
  begin
    if rising_edge(clk) then
      ff1 <= rx;
      ff2 <= ff1;
      valid_r <= '0';
      if rst='1' then
        state <= ST_IDLE;
        timer <= 0;
        bit_no <= 0;
        shreg <= (others=>'0');
        data_r <= (others=>'0');
      else
        case state is
          when ST_IDLE =>
            timer <= 0;
            if ff2='0' then state<=ST_START; end if;
          when ST_START =>
            if timer = BIT_TICKS/2-1 then
              timer<=0;
              if ff2='0' then
                bit_no<=0;
                state<=ST_BITS;
              else
                state<=ST_IDLE;
              end if;
            else timer<=timer+1; end if;
          when ST_BITS =>
            if timer=BIT_TICKS-1 then
              timer<=0;
              shreg(bit_no)<=ff2;
              if bit_no=7 then
                state<=ST_STOP;
              else
                bit_no<=bit_no+1;
              end if;
            else timer<=timer+1; end if;
          when ST_STOP =>
            if timer=BIT_TICKS-1 then
              timer<=0;
              if ff2='1' then
                data_r<=shreg;
                valid_r<='1';
              end if;
              state<=ST_IDLE;
            else timer<=timer+1; end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
