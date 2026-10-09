-- Testovani counteru
-- Autor: Michael Kubat

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
 
ENTITY counter_tb IS
END counter_tb;
 
ARCHITECTURE behavior OF counter_tb IS 
 
    component counter IS
        port (
            CLK    : IN  STD_LOGIC;                    -- hodinovy signal
            RESET  : IN  STD_LOGIC;                    -- synchronni reset (aktivni v 1)
            DIR    : IN  STD_LOGIC;                    -- smer citani (0 = nahoru, 1 = dolu)
            EN     : IN  STD_LOGIC;                    -- enable (povoluje zmenu stavu)
            Q      : OUT STD_LOGIC_VECTOR(3 downto 0); -- aktualni hodnota citace (BCD)
            EN_OUT : OUT STD_LOGIC                     -- preteceni (carry/borrow)
        );
    end component;

    -- Clock a řízení
    signal clk   : STD_LOGIC := '0';    -- hodinovy signal
    signal dir   : STD_LOGIC := '0';    -- smer citani
    signal reset    : STD_LOGIC := '1'; -- reset druheho citace
    signal reset_main : STD_LOGIC := '1'; -- pocatecni reset jednotek
    signal reset_hold : STD_LOGIC := '0'; -- drzeni jednotek v nule pri citani po desitkach
    signal reset_u1   : STD_LOGIC;        -- skutecny reset prvniho citace
    
    -- Enable signály
    signal en1 : STD_LOGIC := '0'; -- enable pro prvni citace
    signal en1_mux : STD_LOGIC;    -- enable po pruchodu multiplexorem
    signal en2 : STD_LOGIC;        -- enable pro druhy citac
    
    -- Ridici signal multiplexoru
    -- 0 = normalni pocitani po jednotkach
    -- 1 = pocitani po desitkach
    signal mux_in : STD_LOGIC := '0';

    -- Vystupy obou citacu
    signal q1 : STD_LOGIC_VECTOR(3 downto 0); -- jednotky
    signal q2 : STD_LOGIC_VECTOR(3 downto 0); -- desitky
    
    -- Preteceni z prvniho citace
    signal en1_out : STD_LOGIC;
    
    -- Signal pro zastaveni generovani EN
    signal stop_sim : BOOLEAN := false;
    
BEGIN
    -- CLK simulace, hodiny se preklopi kazdych 5 ns
    clk <= not clk after 5 ns;
    
    -- Multiplexor pro rizeni citacu
    -- mux_in = '0'
    --   prvni citac dostava normalni enable
    --   druhy citac se inkrementuje pri preteceni prvniho citace
    -- mux_in = '1'
    --   prvni citac je zastaven
    --   druhy citac dostava enable primo
    --   pocita se pouze po desitkach
    en1_mux <= en1 when mux_in = '0' else '0';
    en2 <= en1_out when mux_in = '0' else en1;
    reset_u1 <= reset_main or reset_hold;

    -- Prvni citac (jednotky)
    U1: counter port map(
        CLK    => clk,
        RESET  => reset_u1,
        DIR    => dir,
        EN     => en1_mux,
        Q      => q1,
        EN_OUT => en1_out
    );

    -- Druhy citac (desitky)
    -- spusti se pri preteceni prvniho citace
    U2: counter port map(
        CLK    => clk,
        RESET  => reset,
        DIR    => dir,
        EN     => en2,
        Q      => q2,
        EN_OUT => open
    );
    
    -- Generovani enable signalu
    -- aktivni pouze 1 takt, pak 4 takty neaktivni
    process 
    begin
        while not stop_sim loop
            en1 <= '1';
            wait for 10 ns; -- aktivní po dobu 1 periody CLK
            en1 <= '0';
            wait for 40 ns; -- neaktivní po dobu 4 period CLK
        end loop;
        
        -- po ukonceni simulace bude EN vypnuty
        en1 <= '0';
        wait;
    end process;

    -- Reset citacu
    process
    begin
        -- Na zacatku simulace je reset aktivni 20 ns
        reset <= '1';
        reset_main <= '1';
        
        wait for 20 ns;

        reset <= '0';
        reset_main <= '0';

        wait;
    end process;

    -- Testovaci proces
    process 
        variable value : INTEGER := 0;      -- aktualni dvouciferna hodnota
        variable prev_value : INTEGER := 0; -- predchozi hodnota
    begin
        -- Cekani na dokonceni resetu
        wait for 30 ns;
        
        -- Citani 00 -> 99
        dir <= '0';
        mux_in <= '0';

        while value /= 99 loop
            wait until rising_edge(clk);

            -- spojeni citacu do jedne hodnoty
            value := to_integer(unsigned(q2))*10 + to_integer(unsigned(q1));

            -- kontrola rozsahu
            assert value >= 0 and value <= 99
                report "Count up error: Hodnota mimo rozsah"
                severity error;
            
            -- kontrola spravneho kroku
            if en1 = '1' then
                if value /= prev_value then
                    assert value = (prev_value + 1) mod 100
                        report "Count up error: Vyskyt neocekavane hodnoty"
                        severity error;

                    prev_value := value;
                end if;
            end if;
        end loop;
        
        report "Dosazeno hodnoty 99, otaceni smeru citani" severity note;

        -- Citani 99 -> 00 po desitkach
        wait until rising_edge(clk);

        -- prepnuti smeru
        dir <= '1';
        mux_in <= '1';
        
        -- jednotkovy citac bude od dalsi nabezne hrany drzeny v resetu
        reset_hold <= '1';

        -- pockame na nabeznou hranu, kde se jednotky opravdu vynuluji
        wait until rising_edge(clk);

        -- po teto hrane uz by q1 melo byt 0
        wait for 1 ns;

        prev_value := 100;
        value := to_integer(unsigned(q2))*10;
        
        while value /= 0 loop
            wait until rising_edge(clk);

            value := to_integer(unsigned(q2))*10;

            -- kontrola spravneho kroku smerem dolu
            if en1 = '1' then
                if value /= prev_value then
                    assert value = prev_value - 10
                        report "Count down error: Ocekavana hodnota byla "
                           & integer'image(prev_value - 10)
                           & ", ale skutecna hodnota je "
                           & integer'image(value)
                        severity error;

                    prev_value := value;
                end if;
            end if;
        end loop;
        
        report "Simulace dokoncena (00 -> 99 -> 00)" severity note;
        
        -- Zastaveni simulace
        stop_sim <= true;
        wait;
    end process;
END;
