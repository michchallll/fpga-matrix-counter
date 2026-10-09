-- BCD citac
-- IVH projekt - ukol2
-- autor: Michael Kubat

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY counter IS
    PORT (
        CLK    : IN STD_LOGIC;                      -- hodinovy signal 
        RESET  : IN STD_LOGIC;                      -- synchronni reset (aktivni v 1)
        DIR    : IN STD_LOGIC;                      -- smer citani (0 = nahoru, 1 = dolu)
        EN     : IN STD_LOGIC;                      -- enable (povoluje zmenu stavu)
        Q      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);  -- aktualni hodnota citace (BCD)
        EN_OUT : OUT STD_LOGIC                      -- preteceni (carry/borrow)
    );
END counter;

ARCHITECTURE Behavioral OF counter is
    -- interní registr citace (4 bity, pro BCD 0-9)
    signal q_bcd : unsigned(3 downto 0) := (others => '0');

BEGIN
    process(CLK)
    begin
        if rising_edge(CLK) then

            -- synchronní reset
            if RESET = '1' then
                q_bcd  <= (others => '0');  -- vynulování cítace (00)
                EN_OUT <= '0';              -- zadne preteceni

            else
                EN_OUT <= '0';

                -- enable logika
                if EN = '1' then
                    -- citani smerem nahoru
                    if DIR = '0' then
                        -- pri hodnote '9' dojde k preteceni
                        if q_bcd = to_unsigned(9,4) then
                            q_bcd  <= (others => '0');
                            EN_OUT <= '1';
                        else
                            q_bcd <= q_bcd + 1;
                        end if;

                    -- citani smerem dolu
                    else
                        -- pri hodnote '0' dojde k podteceni
                        if q_bcd = to_unsigned(0,4) then
                            q_bcd  <= to_unsigned(9,4);
                            EN_OUT <= '1';
                        else
                            q_bcd <= q_bcd - 1;
                        end if;
                    end if;
                end if; -- EN
            end if; -- RESET
        end if; -- rising_edge
    end process;

    -- vystup mimo proces, bez vytvareni registru
    Q <= STD_LOGIC_VECTOR(q_bcd);
END Behavioral;
