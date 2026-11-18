-- AES-128 Key Expansion, no masking or encryption.
-- Explicit 3-state controller and 2-cycle-per-round datapath.
-- Interface K0 issued at START; K1..K10 issued every second clock.
-- Reduces combinational path versus one-round/clock GF inverse design.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.aes128_keyexp_pkg.all;

entity aes128_keyexp is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic; -- synchronous active HIGH
        start       : in  std_logic; -- one-cycle pulse; accepted when idle
        key_in      : in  std_logic_vector(127 downto 0);
        round_key   : out std_logic_vector(127 downto 0);
        round_index : out std_logic_vector(3 downto 0);
        valid       : out std_logic;
        done        : out std_logic;
        busy        : out std_logic
    );
end entity aes128_keyexp;

architecture rtl of aes128_keyexp is
    type state_t is (IDLE, CALC_SUBWORD, CALC_NEXT);
    signal state : state_t := IDLE;
    signal key_reg : std_logic_vector(127 downto 0) := (others => '0');
    signal sbox_reg : word_t := (others => '0');
    signal rcon_reg : byte_t := x"01";
    signal round_count : unsigned(3 downto 0) := (others => '0');
    signal out_key : std_logic_vector(127 downto 0) := (others => '0');
    signal out_index : std_logic_vector(3 downto 0) := (others => '0');
    signal out_valid, out_done : std_logic := '0';
begin
    round_key <= out_key;
    round_index <= out_index;
    valid <= out_valid;
    done <= out_done;
    busy <= '0' when state = IDLE else '1';

    process(clk)
        variable w0, w1, w2, w3 : word_t;
        variable t : word_t;
        variable p01, p23 : word_t;
        variable n0, n1, n2, n3 : word_t;
    begin
        if rising_edge(clk) then
            out_valid <= '0';
            out_done <= '0';
            if rst = '1' then
                state <= IDLE;
                key_reg <= (others => '0');
                sbox_reg <= (others => '0');
                rcon_reg <= x"01";
                round_count <= (others => '0');
                out_key <= (others => '0');
                out_index <= (others => '0');
                out_valid <= '0';
                out_done <= '0';
            else
                case state is
                    when IDLE =>
                        if start = '1' then
                            key_reg <= key_in;
                            out_key <= key_in;  -- K0 is the master key
                            out_index <= x"0";
                            out_valid <= '1';
                            round_count <= (others => '0');
                            rcon_reg <= x"01";
                            state <= CALC_SUBWORD;
                        end if;

                    when CALC_SUBWORD =>
                        -- Four 8-bit S-Boxes operate in parallel.
                        sbox_reg <= aes_subword(aes_rotword(key_reg(31 downto 0)));
                        state <= CALC_NEXT;

                    when CALC_NEXT =>
                        w0 := key_reg(127 downto 96);
                        w1 := key_reg(95 downto 64);
                        w2 := key_reg(63 downto 32);
                        w3 := key_reg(31 downto 0);
                        t := sbox_reg xor (rcon_reg & x"000000");
                        -- Prefix XOR terms to shorten t -> output depth.
                        p01 := w0 xor w1;
                        p23 := w2 xor w3;
                        n0 := t xor w0;
                        n1 := t xor p01;
                        n2 := t xor (p01 xor w2);
                        n3 := t xor (p01 xor p23);

                        key_reg <= n0 & n1 & n2 & n3;
                        out_key <= n0 & n1 & n2 & n3;
                        out_index <= std_logic_vector(round_count + 1);
                        out_valid <= '1';
                        round_count <= round_count + 1;
                        rcon_reg <= aes_xtime(rcon_reg);
                        if round_count = to_unsigned(9,4) then
                            out_done <= '1';  -- asserted with K10 valid
                            state <= IDLE;
                        else
                            state <= CALC_SUBWORD;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture rtl;
