-- Verify two complete schedules and all 256 S-Box values.
-- Report every round key and export NIST key schedule to TXT.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.aes128_keyexp_pkg.all;
use work.tb_vectors_pkg.all;
entity tb_aes128_keyexp is end entity;
architecture sim of tb_aes128_keyexp is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal start : std_logic := '0';
    signal key_in : std_logic_vector(127 downto 0) := (others => '0');
    signal round_key : std_logic_vector(127 downto 0);
    signal round_index : std_logic_vector(3 downto 0);
    signal valid, done, busy : std_logic;
    signal finished : boolean := false;
begin
    clk <= not clk after 5 ns when not finished else '0';
    dut : entity work.aes128_keyexp port map(
        clk=>clk, rst=>rst, start=>start, key_in=>key_in,
        round_key=>round_key, round_index=>round_index,
        valid=>valid, done=>done, busy=>busy);

    process
        file outfile : text open write_mode is "roundkeys_sim.txt";
        variable linebuf : line;
        variable expected : keys_t;
        variable waits : natural;
    begin
        -- Full S-Box truth table against independent reference array.
        for i in 0 to 255 loop
            assert aes_sbox(std_logic_vector(to_unsigned(i,8))) = SBOX_REFERENCE(i)
                report "ERROR: S-Box mismatch at byte " & integer'image(i)
                severity failure;
        end loop;
        report "PASS: all 256 S-Box inputs" severity note;

        wait for 41 ns;
        wait until falling_edge(clk);
        rst <= '0';
        for test_no in 1 to 2 loop
            if test_no=1 then expected := KEYS_NIST;
            else expected := KEYS_SEQ; end if;

            wait until falling_edge(clk);
            key_in <= expected(0);
            start <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            assert valid='1' and round_index=x"0" and
                   round_key=expected(0) and done='0' and busy='1'
                report "ERROR at K0" severity failure;
            report "Test " & integer'image(test_no) & " K0 = " & to_hex(round_key) severity note;
            if test_no=1 then write(linebuf,to_hex(round_key)); writeline(outfile,linebuf); end if;
            start <= '0';

            for i in 1 to 10 loop
                waits := 0;
                loop
                    wait until rising_edge(clk);
                    wait for 1 ns;
                    waits := waits + 1;
                    exit when valid='1';
                    assert waits < 5 report "ERROR: Key expansion timeout" severity failure;
                end loop;
                assert waits = 2 report "ERROR: 2-cycle schedule violated" severity failure;
                assert round_key=expected(i) report "ERROR: wrong round key K" & integer'image(i) severity failure;
                assert unsigned(round_index)=to_unsigned(i,4)
                  report "ERROR: wrong round index" severity failure;
                if i=10 then
                    assert done='1' and busy='0' report "ERROR: DONE at K10" severity failure;
                else
                    assert done='0' and busy='1' report "ERROR: busy/done during round" severity failure;
                end if;
                report "Test " & integer'image(test_no) & " K" & integer'image(i) & " = " & to_hex(round_key) severity note;
                if test_no=1 then write(linebuf,to_hex(round_key)); writeline(outfile,linebuf); end if;
            end loop;
            wait for 2 ns;
        end loop;
        report "PASS: two complete AES-128 schedules (22/22 keys)" severity note;
        report "ROUNDKEY FILE: roundkeys_sim.txt" severity note;
        finished <= true;
        wait;
    end process;
end architecture sim;
