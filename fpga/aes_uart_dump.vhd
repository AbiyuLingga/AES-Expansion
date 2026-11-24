-- Sends all 11 round keys as ASCII after AES finishes.
-- Each line: K00:32_HEX_DIGITS CR LF (38 bytes).
-- This educational code transmits PUBLIC NIST test keys: never use real secret keys.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity aes_uart_dump is
    generic (CLOCK_HZ : positive := 50000000; BAUD_RATE : positive := 115200);
    port (
        clk : in std_logic;
        rst : in std_logic;
        start_dump : in std_logic; -- single pulse after bank is ready
        round_sel : out std_logic_vector(3 downto 0); -- selects key from top's bank
        key_data : in std_logic_vector(127 downto 0);
        dump_busy : out std_logic;
        uart_txd : out std_logic
    );
end entity aes_uart_dump;

architecture rtl of aes_uart_dump is
    type state_t is (D_IDLE, D_PREP, D_WAIT, D_ADVANCE);
    signal state : state_t := D_IDLE;
    signal round_no : integer range 0 to 10 := 0;
    signal char_pos : integer range 0 to 37 := 0;
    signal tx_byte : std_logic_vector(7 downto 0) := x"00";
    signal tx_send : std_logic := '0';
    signal tx_busy, tx_done : std_logic;

    function nibble_to_ascii(n: std_logic_vector(3 downto 0))
        return std_logic_vector is
        variable v : integer;
    begin
        v := to_integer(unsigned(n));
        if v <= 9 then
            return std_logic_vector(to_unsigned(48+v,8));
        else
            return std_logic_vector(to_unsigned(65+v-10,8));
        end if;
    end function;
begin
    round_sel <= std_logic_vector(to_unsigned(round_no,4));
    dump_busy <= '0' when state = D_IDLE else '1';

    u_tx: entity work.uart_tx_8n1
        generic map (CLOCK_HZ=>CLOCK_HZ, BAUD_RATE=>BAUD_RATE)
        port map (
            clk=>clk, rst=>rst, send=>tx_send,
            data_in=>tx_byte, tx=>uart_txd, busy=>tx_busy, done=>tx_done
        );

    process(clk)
        variable n : integer;
    begin
        if rising_edge(clk) then
            tx_send <= '0';
            if rst='1' then
                round_no <= 0;
                char_pos <= 0;
                state <= D_IDLE;
                tx_byte <= x"00";
            else
                case state is
                    when D_IDLE =>
                        if start_dump='1' then
                            round_no <= 0;
                            char_pos <= 0;
                            state <= D_PREP;
                        end if;
                    when D_PREP =>
                        if tx_busy='0' then
                            case char_pos is
                                when 0 => tx_byte <= x"4B"; -- K
                                when 1 => tx_byte <=
                                    std_logic_vector(to_unsigned(48 + (round_no / 10), 8));
                                when 2 => tx_byte <=
                                    std_logic_vector(to_unsigned(48 + (round_no mod 10), 8));
                                when 3 => tx_byte <= x"3A"; -- colon
                                when 4 to 35 =>
                                    n := char_pos - 4;
                                    tx_byte <= nibble_to_ascii(
                                        key_data(127 - 4*n downto 124 - 4*n));
                                when 36 => tx_byte <= x"0D";
                                when 37 => tx_byte <= x"0A";
                                when others => tx_byte <= x"3F";
                            end case;
                            tx_send <= '1';
                            state <= D_WAIT;
                        end if;
                    when D_WAIT =>
                        if tx_done='1' then
                            state <= D_ADVANCE;
                        end if;
                    when D_ADVANCE =>
                        if char_pos=37 then
                            if round_no=10 then
                                state <= D_IDLE;
                            else
                                round_no <= round_no+1;
                                char_pos <= 0;
                                state <= D_PREP;
                            end if;
                        else
                            char_pos <= char_pos+1;
                            state <= D_PREP;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture rtl;
