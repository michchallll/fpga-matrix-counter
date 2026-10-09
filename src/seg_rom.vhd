library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity seg_rom is
    Port (
        digit : in  STD_LOGIC_VECTOR(3 downto 0);
        seg   : out STD_LOGIC_VECTOR(6 downto 0)
    );
end seg_rom;

architecture Behavioral of seg_rom is
begin
    -- 1 = segment svítí
    process(digit)
    begin
        case digit is
            when "0000" => seg <= "1111110"; -- 0
            when "0001" => seg <= "0110000"; -- 1
            when "0010" => seg <= "1101101"; -- 2
            when "0011" => seg <= "1111001"; -- 3
            when "0100" => seg <= "0110011"; -- 4
            when "0101" => seg <= "1011011"; -- 5
            when "0110" => seg <= "1011111"; -- 6
            when "0111" => seg <= "1110000"; -- 7
            when "1000" => seg <= "1111111"; -- 8
            when "1001" => seg <= "1111011"; -- 9
            when others => seg <= "0000000";
        end case;
    end process;
end Behavioral;
