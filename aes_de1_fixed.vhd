-- AES-128 Key Expansion on original Terasic DE1 Cyclone II.
-- Standalone: auto-starts on FPGA configuration / KEY0 release.
-- KEY0 active-low reset and auto restart, KEY1 active-low manual restart.
-- SW7 selects public NIST test key, SW6..3 round 0..10, SW2..0 page 0..7.
-- 4x seven-segment displays one 16-bit page in hexadecimal.
-- All board pins use individual scalar top-level names so QSF Location can be audited.
-- Unmasked educational demonstration only; NEVER display actual secret keys.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity aes_de1_fixed is
    port (
        CLOCK_50 : in std_logic;
        KEY0 : in std_logic;
        KEY1 : in std_logic;
        SW0 : in std_logic;
        SW1 : in std_logic;
        SW2 : in std_logic;
        SW3 : in std_logic;
        SW4 : in std_logic;
        SW5 : in std_logic;
        SW6 : in std_logic;
        SW7 : in std_logic;
        LEDG0 : out std_logic;
        LEDG1 : out std_logic;
        LEDG2 : out std_logic;
        LEDG3 : out std_logic;
        HEX0_A : out std_logic;
        HEX0_B : out std_logic;
        HEX0_C : out std_logic;
        HEX0_D : out std_logic;
        HEX0_E : out std_logic;
        HEX0_F : out std_logic;
        HEX0_G : out std_logic;
        HEX1_A : out std_logic;
        HEX1_B : out std_logic;
        HEX1_C : out std_logic;
        HEX1_D : out std_logic;
        HEX1_E : out std_logic;
        HEX1_F : out std_logic;
        HEX1_G : out std_logic;
        HEX2_A : out std_logic;
        HEX2_B : out std_logic;
        HEX2_C : out std_logic;
        HEX2_D : out std_logic;
        HEX2_E : out std_logic;
        HEX2_F : out std_logic;
        HEX2_G : out std_logic;
        HEX3_A : out std_logic;
        HEX3_B : out std_logic;
        HEX3_C : out std_logic;
        HEX3_D : out std_logic;
        HEX3_E : out std_logic;
        HEX3_F : out std_logic;
        HEX3_G : out std_logic
    );
end entity aes_de1_fixed;

architecture rtl of aes_de1_fixed is
    type bank_t is array (0 to 10) of std_logic_vector(127 downto 0);
    type phase_t is (BOOT, STARTING, RUNNING, PH_READY);
    signal phase : phase_t := BOOT;
    signal bank : bank_t := (others => (others => '0'));
    signal ready : std_logic := '0';
    signal key0_ff1, key0_ff2 : std_logic := '1';
    signal key1_ff1, key1_ff2, key1_prev : std_logic := '1';
    signal sw_ff1, sw_ff2 : std_logic_vector(7 downto 0) := (others=>'0');
    signal core_reset, core_start : std_logic;
    signal core_rk : std_logic_vector(127 downto 0);
    signal core_idx : std_logic_vector(3 downto 0);
    signal core_valid, core_done, core_busy : std_logic;
    signal test_key : std_logic_vector(127 downto 0);
    signal selected : std_logic_vector(15 downto 0) := (others=>'0');
    signal display_valid : std_logic := '0';
    signal seg0, seg1, seg2, seg3 : std_logic_vector(6 downto 0);
    signal heartbeat : unsigned(24 downto 0) := (others=>'0');
    function seg7(x: std_logic_vector(3 downto 0)) return std_logic_vector is
    begin
        -- vector(6 downto 0) = G F E D C B A, active low
        case x is
            when x"0" => return "1000000";
            when x"1" => return "1111001";
            when x"2" => return "0100100";
            when x"3" => return "0110000";
            when x"4" => return "0011001";
            when x"5" => return "0010010";
            when x"6" => return "0000010";
            when x"7" => return "1111000";
            when x"8" => return "0000000";
            when x"9" => return "0010000";
            when x"A" => return "0001000";
            when x"B" => return "0000011";
            when x"C" => return "1000110";
            when x"D" => return "0100001";
            when x"E" => return "0000110";
            when x"F" => return "0001110";
            when others => return "1111111";
        end case;
    end function;
begin
    -- Synchronizers; DE1 button hardware already has Schmitt debouncing.
    process(CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            key0_ff1 <= KEY0; key0_ff2 <= key0_ff1;
            key1_ff1 <= KEY1; key1_ff2 <= key1_ff1;
            key1_prev <= key1_ff2;
            sw_ff1(0) <= SW0;
            sw_ff1(1) <= SW1;
            sw_ff1(2) <= SW2;
            sw_ff1(3) <= SW3;
            sw_ff1(4) <= SW4;
            sw_ff1(5) <= SW5;
            sw_ff1(6) <= SW6;
            sw_ff1(7) <= SW7;
            sw_ff2 <= sw_ff1;
        end if;
    end process;
    core_reset <= '1' when (phase=BOOT or key0_ff2='0') else '0';
    core_start <= '1' when phase=STARTING else '0';
    test_key <= x"2B7E151628AED2A6ABF7158809CF4F3C" when sw_ff2(7)='0' else
                x"000102030405060708090A0B0C0D0E0F";
    u_aes : entity work.aes128_keyexp port map (
        clk=>CLOCK_50, rst=>core_reset, start=>core_start, key_in=>test_key,
        round_key=>core_rk, round_index=>core_idx,
        valid=>core_valid, done=>core_done, busy=>core_busy
    );
    -- Power-up BOOT state automatically starts a new AES key schedule.
    -- On RUNNING, capture each registered valid key into display bank.
    process(CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            heartbeat <= heartbeat + 1;
            if key0_ff2 = '0' then
                phase <= BOOT;
                bank <= (others => (others=>'0'));
                ready <= '0';
            else
                case phase is
                    when BOOT =>
                        ready <= '0';
                        bank <= (others => (others=>'0'));
                        phase <= STARTING;
                    when STARTING =>
                        phase <= RUNNING;
                    when RUNNING =>
                        if core_valid='1' then
                            bank(to_integer(unsigned(core_idx))) <= core_rk;
                        end if;
                        if core_done='1' then
                            ready <= '1';
                            phase <= PH_READY;
                        end if;
                    when PH_READY =>
                        if key1_prev='1' and key1_ff2='0' then
                            phase <= BOOT;
                        end if;
                end case;
            end if;
        end if;
    end process;
    -- SW6..3: round index. SW2..0: 16-bit segment page.
    process(bank, sw_ff2, ready)
        variable round_no, page_no : integer;
    begin
        selected <= (others=>'0');
        display_valid <= '0';
        round_no := to_integer(unsigned(sw_ff2(6 downto 3)));
        page_no := to_integer(unsigned(sw_ff2(2 downto 0)));
        if ready='1' and round_no<=10 then
            selected <= bank(round_no)(127-16*page_no downto 112-16*page_no);
            display_valid <= '1';
        end if;
    end process;
    seg3 <= seg7(selected(15 downto 12)) when display_valid='1' else "1111111";
    seg2 <= seg7(selected(11 downto 8)) when display_valid='1' else "1111111";
    seg1 <= seg7(selected(7 downto 4)) when display_valid='1' else "1111111";
    seg0 <= seg7(selected(3 downto 0)) when display_valid='1' else "1111111";
    LEDG0 <= ready;
    LEDG1 <= core_busy;
    LEDG2 <= heartbeat(24);
    LEDG3 <= sw_ff2(7);
    HEX0_A <= seg0(0);
    HEX0_B <= seg0(1);
    HEX0_C <= seg0(2);
    HEX0_D <= seg0(3);
    HEX0_E <= seg0(4);
    HEX0_F <= seg0(5);
    HEX0_G <= seg0(6);
    HEX1_A <= seg1(0);
    HEX1_B <= seg1(1);
    HEX1_C <= seg1(2);
    HEX1_D <= seg1(3);
    HEX1_E <= seg1(4);
    HEX1_F <= seg1(5);
    HEX1_G <= seg1(6);
    HEX2_A <= seg2(0);
    HEX2_B <= seg2(1);
    HEX2_C <= seg2(2);
    HEX2_D <= seg2(3);
    HEX2_E <= seg2(4);
    HEX2_F <= seg2(5);
    HEX2_G <= seg2(6);
    HEX3_A <= seg3(0);
    HEX3_B <= seg3(1);
    HEX3_C <= seg3(2);
    HEX3_D <= seg3(3);
    HEX3_E <= seg3(4);
    HEX3_F <= seg3(5);
    HEX3_G <= seg3(6);
end architecture rtl;
