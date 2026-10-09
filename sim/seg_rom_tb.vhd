library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity seg_rom_tb is
end seg_rom_tb;

architecture Behavioral of seg_rom_tb is
    signal digit : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal seg   : STD_LOGIC_VECTOR(6 downto 0);

begin

    uut : entity work.seg_rom
        port map (
            digit => digit,
            seg   => seg
        );

    stim_proc : process
    begin
        -- seg(6 downto 0) = a b c d e f g
        -- 1 = segment svítí

        digit <= "0000";
        wait for 10 ns;
        assert seg = "1111110"
            report "Chyba ROM: digit 0" severity error;

        digit <= "0001";
        wait for 10 ns;
        assert seg = "0110000"
            report "Chyba ROM: digit 1" severity error;

        digit <= "0010";
        wait for 10 ns;
        assert seg = "1101101"
            report "Chyba ROM: digit 2" severity error;

        digit <= "0011";
        wait for 10 ns;
        assert seg = "1111001"
            report "Chyba ROM: digit 3" severity error;

        digit <= "0100";
        wait for 10 ns;
        assert seg = "0110011"
            report "Chyba ROM: digit 4" severity error;

        digit <= "0101";
        wait for 10 ns;
        assert seg = "1011011"
            report "Chyba ROM: digit 5" severity error;

        digit <= "0110";
        wait for 10 ns;
        assert seg = "1011111"
            report "Chyba ROM: digit 6" severity error;

        digit <= "0111";
        wait for 10 ns;
        assert seg = "1110000"
            report "Chyba ROM: digit 7" severity error;

        digit <= "1000";
        wait for 10 ns;
        assert seg = "1111111"
            report "Chyba ROM: digit 8" severity error;

        digit <= "1001";
        wait for 10 ns;
        assert seg = "1111011"
            report "Chyba ROM: digit 9" severity error;

        -- Neplatné hodnoty 10-15 mají zhasnout
        digit <= "1010";
        wait for 10 ns;
        assert seg = "0000000"
            report "Chyba ROM: digit 10 ma byt zhasnuty" severity error;

        digit <= "1111";
        wait for 10 ns;
        assert seg = "0000000"
            report "Chyba ROM: digit 15 ma byt zhasnuty" severity error;

        report "seg_rom_tb hotovo: vsechny testy prosly" severity note;

        wait;
    end process;

end Behavioral;
