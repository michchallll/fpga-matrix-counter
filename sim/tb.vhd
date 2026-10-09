library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb is
end tb;

architecture Behavioral of tb is
    constant TB_CLK_HZ : integer := 10000;

    signal clk : std_logic := '0';
    signal row : std_logic_vector(7 downto 0);
    signal col : std_logic_vector(7 downto 0);
begin

    -- 10 kHz clock: perioda 100 us
    clk <= not clk after 50 us;

    uut : entity work.top
        generic map (
            CLK_HZ => TB_CLK_HZ
        )
        port map (
            clk => clk,
            row => row,
            col => col
        );

end Behavioral;
