-- UART transmitter: 50 MHz / 115200 baud, 8 data, no parity, 1 stop.
-- DE1 on-board MAX232 converts FPGA-level UART into RS-232 DB9 signalling.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx_8n1 is
    generic (
        CLOCK_HZ : positive := 50000000;
        BAUD_RATE : positive := 115200
    );
    port (
        clk : in std_logic;
        rst : in std_logic; -- synchronous active-high
        send : in std_logic; -- one-cycle pulse
        data_in : in std_logic_vector(7 downto 0);
        tx : out std_logic;
        busy : out std_logic;
        done : out std_logic
    );
end entity uart_tx_8n1;

architecture rtl of uart_tx_8n1 is
    constant TICKS_PER_BIT : positive := (CLOCK_HZ + BAUD_RATE / 2) / BAUD_RATE;
    type state_t is (ST_IDLE, ST_START, ST_DATA, ST_STOP);
    signal state : state_t := ST_IDLE;
    signal tick_count : integer range 0 to TICKS_PER_BIT-1 := 0;
    signal bit_count : integer range 0 to 7 := 0;
    signal data_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_reg : std_logic := '1';
    signal busy_reg, done_reg : std_logic := '0';
begin
    tx <= tx_reg;
    busy <= busy_reg;
    done <= done_reg;
    process(clk)
    begin
        if rising_edge(clk) then
            done_reg <= '0';
            if rst='1' then
                state <= ST_IDLE;
                tick_count <= 0;
                bit_count <= 0;
                data_reg <= (others => '0');
                tx_reg <= '1';
                busy_reg <= '0';
            else
                case state is
                    when ST_IDLE =>
                        tx_reg <= '1';
                        busy_reg <= '0';
                        tick_count <= 0;
                        if send='1' then
                            data_reg <= data_in;
                            busy_reg <= '1';
                            tx_reg <= '0'; -- start bit
                            state <= ST_START;
                        end if;
                    when ST_START =>
                        if tick_count = TICKS_PER_BIT-1 then
                            tick_count <= 0;
                            bit_count <= 0;
                            tx_reg <= data_reg(0);
                            state <= ST_DATA;
                        else
                            tick_count <= tick_count + 1;
                        end if;
                    when ST_DATA =>
                        if tick_count = TICKS_PER_BIT-1 then
                            tick_count <= 0;
                            if bit_count = 7 then
                                tx_reg <= '1'; -- stop bit
                                state <= ST_STOP;
                            else
                                bit_count <= bit_count + 1;
                                tx_reg <= data_reg(bit_count+1);
                            end if;
                        else
                            tick_count <= tick_count + 1;
                        end if;
                    when ST_STOP =>
                        if tick_count = TICKS_PER_BIT-1 then
                            tick_count <= 0;
                            tx_reg <= '1';
                            busy_reg <= '0';
                            done_reg <= '1';
                            state <= ST_IDLE;
                        else
                            tick_count <= tick_count + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture rtl;
