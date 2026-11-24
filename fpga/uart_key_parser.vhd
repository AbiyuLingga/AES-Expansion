-- ASCII protocol: K followed by exactly 32 hex digits, optional CR, then LF.
-- e.g. K2B7E151628AED2A6ABF7158809CF4F3C\n
-- Emits one-cycle key_valid with 128-bit key_value.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity uart_key_parser is
  port(clk : in std_logic; rst : in std_logic;
       byte_in : in std_logic_vector(7 downto 0); byte_valid : in std_logic;
       key_value : out std_logic_vector(127 downto 0); key_valid : out std_logic);
end entity;
architecture rtl of uart_key_parser is
  type state_t is (P_IDLE, P_HEX, P_END);
  signal state : state_t := P_IDLE;
  signal digits : integer range 0 to 32 := 0;
  signal shift_reg : std_logic_vector(127 downto 0) := (others=>'0');
  signal key_reg : std_logic_vector(127 downto 0) := (others=>'0');
  signal key_pulse : std_logic := '0';
  function to_nibble(c: std_logic_vector(7 downto 0)) return integer is
    variable u: integer;
  begin
    u:=to_integer(unsigned(c));
    if u>=48 and u<=57 then return u-48;
    elsif u>=65 and u<=70 then return u-65+10;
    elsif u>=97 and u<=102 then return u-97+10;
    else return -1; end if;
  end function;
begin
  key_value <= key_reg;
  key_valid <= key_pulse;
  process(clk)
    variable nib : integer;
  begin
    if rising_edge(clk) then
      key_pulse<='0';
      if rst='1' then
        state<=P_IDLE;
        digits<=0;
        shift_reg<=(others=>'0');
        key_reg<=(others=>'0');
      elsif byte_valid='1' then
        nib:=to_nibble(byte_in);
        case state is
          when P_IDLE =>
            if byte_in=x"4B" or byte_in=x"6B" then
              state<=P_HEX;
              digits<=0;
              shift_reg<=(others=>'0');
            end if;
          when P_HEX =>
            if nib>=0 then
              shift_reg<=shift_reg(123 downto 0) & std_logic_vector(to_unsigned(nib,4));
              if digits=31 then
                digits<=32;
                state<=P_END;
              else digits<=digits+1; end if;
            else
              state<=P_IDLE;
            end if;
          when P_END =>
            if byte_in=x"0A" then
              key_reg<=shift_reg;
              key_pulse<='1';
              state<=P_IDLE;
            elsif byte_in=x"0D" then
              null; -- tolerate CRLF from terminal
            else
              state<=P_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
