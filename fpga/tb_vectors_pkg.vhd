-- VHDL-93 test-only constants, NOT added to Quartus project.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
package tb_vectors_pkg is
    type sbox_ref_t is array (0 to 255) of std_logic_vector(7 downto 0);
    constant SBOX_REFERENCE : sbox_ref_t := (
        -- 00 .. 0F
        x"63", x"7C", x"77", x"7B", x"F2", x"6B", x"6F", x"C5", x"30", x"01", x"67", x"2B", x"FE", x"D7", x"AB", x"76",
        -- 10 .. 1F
        x"CA", x"82", x"C9", x"7D", x"FA", x"59", x"47", x"F0", x"AD", x"D4", x"A2", x"AF", x"9C", x"A4", x"72", x"C0",
        -- 20 .. 2F
        x"B7", x"FD", x"93", x"26", x"36", x"3F", x"F7", x"CC", x"34", x"A5", x"E5", x"F1", x"71", x"D8", x"31", x"15",
        -- 30 .. 3F
        x"04", x"C7", x"23", x"C3", x"18", x"96", x"05", x"9A", x"07", x"12", x"80", x"E2", x"EB", x"27", x"B2", x"75",
        -- 40 .. 4F
        x"09", x"83", x"2C", x"1A", x"1B", x"6E", x"5A", x"A0", x"52", x"3B", x"D6", x"B3", x"29", x"E3", x"2F", x"84",
        -- 50 .. 5F
        x"53", x"D1", x"00", x"ED", x"20", x"FC", x"B1", x"5B", x"6A", x"CB", x"BE", x"39", x"4A", x"4C", x"58", x"CF",
        -- 60 .. 6F
        x"D0", x"EF", x"AA", x"FB", x"43", x"4D", x"33", x"85", x"45", x"F9", x"02", x"7F", x"50", x"3C", x"9F", x"A8",
        -- 70 .. 7F
        x"51", x"A3", x"40", x"8F", x"92", x"9D", x"38", x"F5", x"BC", x"B6", x"DA", x"21", x"10", x"FF", x"F3", x"D2",
        -- 80 .. 8F
        x"CD", x"0C", x"13", x"EC", x"5F", x"97", x"44", x"17", x"C4", x"A7", x"7E", x"3D", x"64", x"5D", x"19", x"73",
        -- 90 .. 9F
        x"60", x"81", x"4F", x"DC", x"22", x"2A", x"90", x"88", x"46", x"EE", x"B8", x"14", x"DE", x"5E", x"0B", x"DB",
        -- A0 .. AF
        x"E0", x"32", x"3A", x"0A", x"49", x"06", x"24", x"5C", x"C2", x"D3", x"AC", x"62", x"91", x"95", x"E4", x"79",
        -- B0 .. BF
        x"E7", x"C8", x"37", x"6D", x"8D", x"D5", x"4E", x"A9", x"6C", x"56", x"F4", x"EA", x"65", x"7A", x"AE", x"08",
        -- C0 .. CF
        x"BA", x"78", x"25", x"2E", x"1C", x"A6", x"B4", x"C6", x"E8", x"DD", x"74", x"1F", x"4B", x"BD", x"8B", x"8A",
        -- D0 .. DF
        x"70", x"3E", x"B5", x"66", x"48", x"03", x"F6", x"0E", x"61", x"35", x"57", x"B9", x"86", x"C1", x"1D", x"9E",
        -- E0 .. EF
        x"E1", x"F8", x"98", x"11", x"69", x"D9", x"8E", x"94", x"9B", x"1E", x"87", x"E9", x"CE", x"55", x"28", x"DF",
        -- F0 .. FF
        x"8C", x"A1", x"89", x"0D", x"BF", x"E6", x"42", x"68", x"41", x"99", x"2D", x"0F", x"B0", x"54", x"BB", x"16"
    );
    type keys_t is array(0 to 10) of std_logic_vector(127 downto 0);
    constant KEYS_NIST : keys_t := (
         0 => x"2B7E151628AED2A6ABF7158809CF4F3C",
         1 => x"A0FAFE1788542CB123A339392A6C7605",
         2 => x"F2C295F27A96B9435935807A7359F67F",
         3 => x"3D80477D4716FE3E1E237E446D7A883B",
         4 => x"EF44A541A8525B7FB671253BDB0BAD00",
         5 => x"D4D1C6F87C839D87CAF2B8BC11F915BC",
         6 => x"6D88A37A110B3EFDDBF98641CA0093FD",
         7 => x"4E54F70E5F5FC9F384A64FB24EA6DC4F",
         8 => x"EAD27321B58DBAD2312BF5607F8D292F",
         9 => x"AC7766F319FADC2128D12941575C006E",
        10 => x"D014F9A8C9EE2589E13F0CC8B6630CA6"
    );
    constant KEYS_SEQ : keys_t := (
         0 => x"000102030405060708090A0B0C0D0E0F",
         1 => x"D6AA74FDD2AF72FADAA678F1D6AB76FE",
         2 => x"B692CF0B643DBDF1BE9BC5006830B3FE",
         3 => x"B6FF744ED2C2C9BF6C590CBF0469BF41",
         4 => x"47F7F7BC95353E03F96C32BCFD058DFD",
         5 => x"3CAAA3E8A99F9DEB50F3AF57ADF622AA",
         6 => x"5E390F7DF7A69296A7553DC10AA31F6B",
         7 => x"14F9701AE35FE28C440ADF4D4EA9C026",
         8 => x"47438735A41C65B9E016BAF4AEBF7AD2",
         9 => x"549932D1F08557681093ED9CBE2C974E",
        10 => x"13111D7FE3944A17F307A78B4D2B30C5"
    );
    function to_hex(x : std_logic_vector(127 downto 0)) return string;
    function seg7_ref(n : std_logic_vector(3 downto 0)) return std_logic_vector;
end package;
package body tb_vectors_pkg is
    function to_hex(x : std_logic_vector(127 downto 0)) return string is
        constant digits : string := "0123456789ABCDEF";
        variable result : string(1 to 32);
    begin
        for k in 0 to 31 loop
            result(k+1) := digits(to_integer(unsigned(x(127-4*k downto 124-4*k)))+1);
        end loop;
        return result;
    end function;
    function seg7_ref(n : std_logic_vector(3 downto 0)) return std_logic_vector is
    begin
        case n is
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
end package body;
