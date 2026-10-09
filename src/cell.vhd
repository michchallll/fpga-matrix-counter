library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity cell is
    Port (
        bcd_bit    : in  STD_LOGIC;
        image_bit  : in  STD_LOGIC;
        right_bit  : in  STD_LOGIC;
        mode       : in  STD_LOGIC_VECTOR(2 downto 0);
        invert     : in  STD_LOGIC;
        anim_bit   : in  STD_LOGIC;
        q          : out STD_LOGIC
    );
end cell;

architecture Behavioral of cell is
    signal selected : STD_LOGIC;
begin
    process(bcd_bit, image_bit, right_bit, mode, anim_bit)
    begin
        case mode is
            when "000" =>
                selected <= bcd_bit;     -- BCD normálne
                
            when "001" =>
                selected <= bcd_bit;     -- BCD invertovane

            when "010" =>
                selected <= image_bit;   -- obrazek

            when "011" =>
                selected <= right_bit;   -- kopie souseda napravo

            when "100" =>
                selected <= anim_bit;    -- animace

            when others =>
                selected <= '0';
        end case;
    end process;

    q <= not selected when invert = '1' else selected;
end Behavioral;
