-- IVH projekt 2026
-- autor: Michael Kubat

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    Generic (
        CLK_HZ : integer := 25_000_000
    );
    Port (
        clk : in  STD_LOGIC;
        row : out STD_LOGIC_VECTOR(7 downto 0);
        col : out STD_LOGIC_VECTOR(7 downto 0)
    );
end top;

architecture Behavioral of top is

    type phase_t is (
        S_START_RESET,
        S_UP_SLOW,   -- 00 -> 10, krok 1 s
        S_UP_FAST,   -- 10 -> 99, krok 100 ms
        S_DOWN_INV,  -- 90 -> 00, krok 500 ms, inverzni zobrazeni
        S_IMAGE,     -- zobrazeni obrazku po dobu 5 s
        S_ROTATE,    -- rotace obrazku doleva
        S_FILL,      -- postupne zaplneni displeje
        S_BLINK,     -- blikani celeho displeje
        S_SPIRAL     -- spiralove zhasinani displeje
    );

    subtype matrix_vec_t is STD_LOGIC_VECTOR(0 to 63);

    -- Pocet taktu pro jednotlive casove intervaly.
    -- Hodnota CLK_HZ je v realnem navrhu 25 MHz, v simulaci muze byt zmensena.
    constant TICK_1S_MAX    : integer := CLK_HZ - 1;
    constant TICK_100MS_MAX : integer := CLK_HZ / 10 - 1;
    constant TICK_500MS_MAX : integer := CLK_HZ / 2 - 1;

    -- Multiplex displeje: jeden sloupec je aktivni priblizne 2 ms.
    constant SCAN_MAX : integer := CLK_HZ / 500 - 1;
    
    -- Doba zobrazeni statickeho obrazku.
    constant IMAGE_5S_MAX : integer := 5 * CLK_HZ - 1;
    
    -- Rychlost rotace obrazku.
    constant ROTATE_STEP_MAX : integer := CLK_HZ / 4 - 1;
    
    -- Rychlost animace postupneho zaplneni.
    constant FILL_STEP_MAX : integer := CLK_HZ / 16 - 1;
    
    -- Rychlost blikani a spiraloveho zhasinani.
    constant BLINK_STEP_MAX  : integer := CLK_HZ / 4 - 1;
    constant SPIRAL_STEP_MAX : integer := CLK_HZ / 32 - 1;

    -- Bitmapa obrazku srdce.
    -- Jednicka znamena rozsvicenou LED.
    -- Poradi radku je upraveno podle fyzicke orientace displeje.
    constant HEART_MATRIX : matrix_vec_t :=
        "00011000" &
        "00111100" &
        "01111110" &
        "11111111" &
        "11111111" &
        "01111110" &
        "00100100" &
        "00000000";

    -- Pomocne procedury pro kresleni do 8x8 bitmapy
    procedure set_pixel(
        variable m : inout matrix_vec_t;
        constant r : in integer;
        constant c : in integer
    ) is
    begin
        if r >= 0 and r <= 7 and c >= 0 and c <= 7 then
            m(r * 8 + c) := '1';
        end if;
    end procedure;

    procedure hline(
        variable m : inout matrix_vec_t;
        constant r  : in integer;
        constant c1 : in integer;
        constant c2 : in integer
    ) is
    begin
        for c in c1 to c2 loop
            set_pixel(m, r, c);
        end loop;
    end procedure;

    procedure vline(
        variable m : inout matrix_vec_t;
        constant c  : in integer;
        constant r1 : in integer;
        constant r2 : in integer
    ) is
    
    begin
        for r in r1 to r2 loop
            set_pixel(m, r, c);
        end loop;
    end procedure;

    -- Vykresleni jedne sedmisegmentove cislice do 8x8 bitmapy.
    -- seg(6 downto 0) = a b c d e f g
    --
    -- Logicky tvar cislice:
    -- a a a
    -- f   b
    -- g g g
    -- e   c
    -- d d d
    --
    -- Kvuli fyzicke orientaci displeje jsou horni a dolni segmenty
    -- pri kresleni prohozene. Tim se cislice zobrazuji spravne na desce.
    procedure draw_digit(
        variable m : inout matrix_vec_t;
        constant seg : in STD_LOGIC_VECTOR(6 downto 0);
        constant x : in integer
    ) is
        constant y : integer := 1;
        
    begin
        if seg(6) = '1' then
            hline(m, y + 4, x + 0, x + 2);
        end if;

        -- b: pravý horní segment, fyzicky kreslený jako pravý dolní
        if seg(5) = '1' then
            vline(m, x + 2, y + 2, y + 4);
        end if;

        -- c: pravý dolní segment, fyzicky kreslený jako pravý horní
        if seg(4) = '1' then
            vline(m, x + 2, y + 0, y + 2);
        end if;

        -- d: dolní segment, fyzicky kreslený nahoru
        if seg(3) = '1' then
            hline(m, y + 0, x + 0, x + 2);
        end if;

        -- e: levý dolní segment, fyzicky kreslený jako levý horní
        if seg(2) = '1' then
            vline(m, x + 0, y + 0, y + 2);
        end if;

        -- f: levý horní segment, fyzicky kreslený jako levý dolní
        if seg(1) = '1' then
            vline(m, x + 0, y + 2, y + 4);
        end if;

        -- g: prostřední segment zůstává uprostřed
        if seg(0) = '1' then
            hline(m, y + 2, x + 0, x + 2);
        end if;
    end procedure;

    -- Funkce vraci index LED v poradi spiraloveho zhasinani.
    -- Indexy odpovidaji 8x8 bitmapě ulozene po radcich.
    function spiral_index(constant pos : integer) return integer is
    begin
        case pos is
            -- horni radek zleva doprava
            when 0  => return 0;
            when 1  => return 1;
            when 2  => return 2;
            when 3  => return 3;
            when 4  => return 4;
            when 5  => return 5;
            when 6  => return 6;
            when 7  => return 7;

            -- pravy sloupec shora dolu
            when 8  => return 15;
            when 9  => return 23;
            when 10 => return 31;
            when 11 => return 39;
            when 12 => return 47;
            when 13 => return 55;
            when 14 => return 63;

            -- spodni radek zprava doleva
            when 15 => return 62;
            when 16 => return 61;
            when 17 => return 60;
            when 18 => return 59;
            when 19 => return 58;
            when 20 => return 57;
            when 21 => return 56;

            -- levy sloupec zdola nahoru
            when 22 => return 48;
            when 23 => return 40;
            when 24 => return 32;
            when 25 => return 24;
            when 26 => return 16;
            when 27 => return 8;

            -- druhy prstenec
            when 28 => return 9;
            when 29 => return 10;
            when 30 => return 11;
            when 31 => return 12;
            when 32 => return 13;
            when 33 => return 14;

            when 34 => return 22;
            when 35 => return 30;
            when 36 => return 38;
            when 37 => return 46;
            when 38 => return 54;

            when 39 => return 53;
            when 40 => return 52;
            when 41 => return 51;
            when 42 => return 50;
            when 43 => return 49;

            when 44 => return 41;
            when 45 => return 33;
            when 46 => return 25;
            when 47 => return 17;

            -- treti prstenec
            when 48 => return 18;
            when 49 => return 19;
            when 50 => return 20;
            when 51 => return 21;

            when 52 => return 29;
            when 53 => return 37;
            when 54 => return 45;

            when 55 => return 44;
            when 56 => return 43;
            when 57 => return 42;

            when 58 => return 34;
            when 59 => return 26;

            -- stred
            when 60 => return 27;
            when 61 => return 28;
            when 62 => return 36;
            when others => return 35;
        end case;
    end function;

    -- Vnitrni signaly
    
    -- Aktualni stav hlavniho FSM automatu.
    signal phase : phase_t := S_START_RESET;

    -- Kratky startovni reset pro BCD citace.
    signal startup_cnt : integer range 0 to 15 := 0;

    -- Citace pro generovani casovych pulzu.
    signal cnt_1s    : integer range 0 to TICK_1S_MAX := 0;
    signal cnt_100ms : integer range 0 to TICK_100MS_MAX := 0;
    signal cnt_500ms : integer range 0 to TICK_500MS_MAX := 0;

    -- Jednotaktove povolovaci pulzy.
    signal tick_1s    : STD_LOGIC := '0';
    signal tick_100ms : STD_LOGIC := '0';
    signal tick_500ms : STD_LOGIC := '0';

    -- Signaly pro multiplexovani maticoveho displeje
    signal scan_cnt : integer range 0 to SCAN_MAX := 0;
    signal col_idx  : integer range 0 to 7 := 0;

    -- BCD hodnoty jednotek a desitek.
    signal digit_ones : STD_LOGIC_VECTOR(3 downto 0);
    signal digit_tens : STD_LOGIC_VECTOR(3 downto 0);

    -- Hodnoty posilane do ROM. V odpoctu se jednotky nahrazuji nulou.
    signal disp_ones : STD_LOGIC_VECTOR(3 downto 0);
    signal disp_tens : STD_LOGIC_VECTOR(3 downto 0);

    -- Vystupy ROM ve forme sedmisegmentoveho kodu.
    signal seg_ones : STD_LOGIC_VECTOR(6 downto 0);
    signal seg_tens : STD_LOGIC_VECTOR(6 downto 0);

    signal reset_cnt : STD_LOGIC := '0';
    signal dir_cnt   : STD_LOGIC := '0';

    signal en_ones : STD_LOGIC := '0';
    signal en_tens : STD_LOGIC := '0';

    signal carry_ones_unused : STD_LOGIC;
    signal carry_tens_unused : STD_LOGIC;

    signal base_matrix  : matrix_vec_t := (others => '0');
    signal shown_matrix : matrix_vec_t := (others => '0');

    signal row_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '1');
    signal col_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    
    signal image_cnt : integer range 0 to IMAGE_5S_MAX := 0;
    
    signal rotate_cnt      : integer range 0 to ROTATE_STEP_MAX := 0;
    signal rotate_step_cnt : integer range 0 to 15 := 0;
    signal rotate_matrix   : matrix_vec_t := (others => '0');
    
    signal fill_cnt      : integer range 0 to FILL_STEP_MAX := 0;
    signal fill_pos      : integer range 0 to 63 := 0;
    signal fill_matrix   : matrix_vec_t := (others => '0');
    
    signal blink_cnt       : integer range 0 to BLINK_STEP_MAX := 0;
    signal blink_step_cnt  : integer range 0 to 5 := 0;
    signal blink_on        : STD_LOGIC := '1';

    signal spiral_cnt      : integer range 0 to SPIRAL_STEP_MAX := 0;
    signal spiral_pos      : integer range 0 to 63 := 0;
    signal spiral_matrix   : matrix_vec_t := (others => '1');
    
    signal cell_matrix : matrix_vec_t := (others => '0');
    signal cell_mode   : STD_LOGIC_VECTOR(2 downto 0) := "000";
    signal cell_invert : STD_LOGIC := '0';
    signal bcd_input   : matrix_vec_t := (others => '0');
    signal image_input : matrix_vec_t := (others => '0');
    signal anim_input  : matrix_vec_t := (others => '0');
    
    signal debug_leds : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

begin
    -- 64 bunek displeje
    -- Kazda bunka vybira mezi BCD obrazem, obrazkem, animaci
    -- ci inverzi vystupu.
    gen_cells : for i in 0 to 63 generate
        cell_i : entity work.cell
            port map (
                bcd_bit   => bcd_input(i),
                image_bit => image_input(i),
                right_bit => image_input((i / 8) * 8 + ((i mod 8 + 1) mod 8)),
                mode      => cell_mode,
                invert    => cell_invert,
                anim_bit  => anim_input(i),
                q         => cell_matrix(i)
            );
    end generate;

    -- Casove pulzy 1 s, 100 ms, 500 ms
    process(clk)
    begin
        if rising_edge(clk) then
            tick_1s    <= '0';
            tick_100ms <= '0';
            tick_500ms <= '0';

            if cnt_1s = TICK_1S_MAX then
                cnt_1s <= 0;
                tick_1s <= '1';
            else
                cnt_1s <= cnt_1s + 1;
            end if;

            if cnt_100ms = TICK_100MS_MAX then
                cnt_100ms <= 0;
                tick_100ms <= '1';
            else
                cnt_100ms <= cnt_100ms + 1;
            end if;

            if cnt_500ms = TICK_500MS_MAX then
                cnt_500ms <= 0;
                tick_500ms <= '1';
            else
                cnt_500ms <= cnt_500ms + 1;
            end if;
        end if;
    end process;

    -- Hlavni FSM automat
    -- Ridi celou posloupnost projektu:
    -- pomale citani, rychle citani, inverzni odpocet,
    -- zobrazeni obrazku, rotaci a vlastni animace.
    process(clk)
    begin
        if rising_edge(clk) then
            reset_cnt <= '0';

            case phase is

                when S_START_RESET =>
                    reset_cnt <= '1';

                    if startup_cnt = 15 then
                        phase <= S_UP_SLOW;
                    else
                        startup_cnt <= startup_cnt + 1;
                    end if;

                when S_UP_SLOW =>
                    -- 00 az 10, jedno cislo po dobu 1 s
                    if tick_1s = '1' then
                        if digit_tens = "0001" and digit_ones = "0000" then
                            -- už bylo zobrazeno 10, dál pojedeme rychle
                            phase <= S_UP_FAST;
                        end if;
                    end if;

                when S_UP_FAST =>
                    -- 10 az 99, jedno cislo po dobu 100 ms
                    if tick_100ms = '1' then
                        if digit_tens = "1001" and digit_ones = "1001" then
                            -- prechod 99 -> 90 resime tak,
                            -- ze v DOWN režimu jednotky jen zobrazime jako 0
                            phase <= S_DOWN_INV;
                        end if;
                    end if;

                when S_DOWN_INV =>
                    -- 90, 80, ..., 00, inverzni zobrazeni
                    if tick_500ms = '1' then
                        if digit_tens = "0000" then
                            -- po 00 přejdeme na obrázek
                            image_cnt <= 0;
                            phase <= S_IMAGE;
                        end if;
                    end if;

                when S_IMAGE =>
                    -- Obrazek srdce je zobrazen po dobu 5 s
                    if image_cnt = IMAGE_5S_MAX then
                        image_cnt <= 0;

                    
                        rotate_cnt <= 0;
                        rotate_step_cnt <= 0;
                        rotate_matrix <= HEART_MATRIX;

                        phase <= S_ROTATE;
                    else
                        image_cnt <= image_cnt + 1;
                    end if;
                
                when S_ROTATE =>
                    if rotate_cnt = ROTATE_STEP_MAX then
                        rotate_cnt <= 0;

                        -- Posun obrazku doleva. 
                        -- Pravy sloupec se doplni puvodnim levym sloupcem.
                        for r in 0 to 7 loop
                            for c in 0 to 6 loop
                                rotate_matrix(r * 8 + c) <= rotate_matrix(r * 8 + c + 1);
                            end loop;

                            rotate_matrix(r * 8 + 7) <= rotate_matrix(r * 8 + 0);
                        end loop;

                        if rotate_step_cnt = 15 then
                            rotate_step_cnt <= 0;
                            
                            fill_cnt <= 0;
                            fill_pos <= 0;
                            fill_matrix <= (others => '0');

                            phase <= S_FILL;
                        else
                            rotate_step_cnt <= rotate_step_cnt + 1;
                        end if;

                    else
                        rotate_cnt <= rotate_cnt + 1;
                    end if;
                    
                when S_FILL =>
                    if fill_cnt = FILL_STEP_MAX then
                        fill_cnt <= 0;

                        -- Postupne zaplneni celeho displeje.
                        -- Korekce radku zajistuje spravne fyzicke umisteni na displeji.
                        fill_matrix(((fill_pos / 8 + 7) mod 8) * 8 + (fill_pos mod 8)) <= '1';

                        if fill_pos = 63 then
                            fill_pos <= 0;
                            
                            blink_cnt <= 0;
                            blink_step_cnt <= 0;
                            blink_on <= '1';

                            phase <= S_BLINK;
                        else
                            fill_pos <= fill_pos + 1;
                        end if;

                    else
                        fill_cnt <= fill_cnt + 1;
                    end if;
                
                when S_BLINK =>
                    if blink_cnt = BLINK_STEP_MAX then
                        blink_cnt <= 0;

                        if blink_step_cnt = 5 then
                            blink_step_cnt <= 0;

                            -- Po blikani zacina spiralove zhasinani z plneho displeje.
                            spiral_cnt <= 0;
                            spiral_pos <= 0;
                            spiral_matrix <= (others => '1');

                            phase <= S_SPIRAL;
                        else
                            blink_step_cnt <= blink_step_cnt + 1;
                            blink_on <= not blink_on;
                        end if;

                    else
                        blink_cnt <= blink_cnt + 1;
                    end if;
                
                when S_SPIRAL =>
                    if spiral_cnt = SPIRAL_STEP_MAX then
                        spiral_cnt <= 0;

                        -- Po dokonceni spiraly se citace vynuluji a sekvence zacina znovu.
                        -- Korekce radku: fyzicky posuneme spiralu o jeden radek dolu.
                        spiral_matrix((((spiral_index(spiral_pos) / 8) + 7) mod 8) * 8 +
                            (spiral_index(spiral_pos) mod 8)) <= '0';

                        if spiral_pos = 63 then
                            spiral_pos <= 0;
                            reset_cnt <= '1';
                            phase <= S_UP_SLOW;
                    else
                        spiral_pos <= spiral_pos + 1;
                    end if;

                else
                    spiral_cnt <= spiral_cnt + 1;
                end if;
                
            end case;
        end if;
    end process;

    -- Rizeni dvou BCD citacu
    -- Citac jednotek a citac desitek jsou povolovany podle aktualni faze.
    dir_cnt <= '0' when phase = S_UP_SLOW or phase = S_UP_FAST else '1';

    -- Jednotky:
    -- v pomale fazi citaji 1x za sekundu do 10
    -- v rychlé fazi citaji kazdych 100 ms do 99
    -- v DOWN fazi stoji, protože zobrazujeme 90,80,...,00
    en_ones <= '1' when (
                    phase = S_UP_SLOW and
                    tick_1s = '1' and
                    not (digit_tens = "0001" and digit_ones = "0000")
                ) or (
                    phase = S_UP_FAST and
                    tick_100ms = '1' and
                    not (digit_tens = "1001" and digit_ones = "1001")
                )
               else '0';

    -- Desitky:
    -- pri citani nahoru se zvetsi pri prechodu jednotek 9 -> 0,
    -- pri odpoctu se zmensuji kazdych 500 ms.
    en_tens <= '1' when (
                    phase = S_UP_SLOW and
                    tick_1s = '1' and
                    digit_ones = "1001"
                ) or (
                    phase = S_UP_FAST and
                    tick_100ms = '1' and
                    digit_ones = "1001" and
                    not (digit_tens = "1001" and digit_ones = "1001")
                ) or (
                    phase = S_DOWN_INV and
                    tick_500ms = '1' and
                    digit_tens /= "0000"
                )
               else '0';

    -- Dve instance counter.vhd
    cnt_ones_inst : entity work.counter
        port map (
            CLK    => clk,
            RESET  => reset_cnt,
            DIR    => dir_cnt,
            EN     => en_ones,
            Q      => digit_ones,
            EN_OUT => carry_ones_unused
        );

    cnt_tens_inst : entity work.counter
        port map (
            CLK    => clk,
            RESET  => reset_cnt,
            DIR    => dir_cnt,
            EN     => en_tens,
            Q      => digit_tens,
            EN_OUT => carry_tens_unused
        );

    -- Zobrazovane cislice
    disp_tens <= digit_tens;

    -- V odpoctu po desitkach zobrazujeme jednotky jako 0.
    -- Diky tomu se 99 vizualne zmeni na 90.
    disp_ones <= digit_ones when phase /= S_DOWN_INV else "0000";

    -- ROM prevodniky BCD cislice na sedmisegmentovy kod
    -- Pouzity jsou dve instance, jedna pro desitky a jedna pro jednotky.
    rom_tens_inst : entity work.seg_rom
        port map (
            digit => disp_tens,
            seg   => seg_tens
        );

    rom_ones_inst : entity work.seg_rom
        port map (
            digit => disp_ones,
            seg   => seg_ones
        );

    -- Prevod sedmisegmentovych cislic na 64bitovou bitmapu
    -- Vysledkem je obraz dvou cislic v matici 8x8.
    process(seg_tens, seg_ones)
        variable m : matrix_vec_t;
    begin
        m := (others => '0');

        draw_digit(m, seg_tens, 1); -- levá číslice, sloupce 1..3
        draw_digit(m, seg_ones, 5); -- pravá číslice, sloupce 5..7

        base_matrix <= m;
    end process;

    bcd_input <= base_matrix;

    image_input <= HEART_MATRIX when phase = S_IMAGE else
                   rotate_matrix when phase = S_ROTATE else
                   HEART_MATRIX;

    anim_input <= fill_matrix when phase = S_FILL else
                  (others => blink_on) when phase = S_BLINK else
                  spiral_matrix when phase = S_SPIRAL else
                  (others => '0');

    cell_mode <= "010" when phase = S_IMAGE or phase = S_ROTATE else
                 "100" when phase = S_FILL or phase = S_BLINK or phase = S_SPIRAL else
                 "001" when phase = S_DOWN_INV else
                 "000";

    cell_invert <= '1' when phase = S_DOWN_INV else '0';

    -- Stabilni snimek pro displej
    -- Vystup bunek cell_matrix se muze zmenit kdykoliv.
    -- Do zobrazovace se ale kopiruje pouze po dokonceni celeho pruchodu
    -- vsemi osmi sloupci, aby nedochazelo k problikavani obrazu.
    process(clk)
        begin
            if rising_edge(clk) then
                if scan_cnt = SCAN_MAX and col_idx = 7 then
                    shown_matrix <= cell_matrix;
                end if;
            end if;
        end process;

    -- Multiplexovani maticoveho displeje
    -- Aktivni je vzdy prave jeden sloupec.
    -- Sloupce jsou aktivni v logicke 1, radky jsou aktivni v logicke 0.
    process(clk)
    begin
        if rising_edge(clk) then
            if scan_cnt = SCAN_MAX then
                scan_cnt <= 0;

                if col_idx = 7 then
                    col_idx <= 0;
                else
                    col_idx <= col_idx + 1;
                end if;
            else
                scan_cnt <= scan_cnt + 1;
            end if;
        end if;
    end process;

    process(col_idx, shown_matrix)
        variable c : STD_LOGIC_VECTOR(7 downto 0);
        variable r : STD_LOGIC_VECTOR(7 downto 0);
        variable dbg : STD_LOGIC_VECTOR(7 downto 0);
    begin
        c := (others => '0');
        r := (others => '1');
        dbg := (others => '0');

        c(col_idx) := '1';

        for row_i in 0 to 7 loop
            -- 1 = LED má svítit v aktuálním sloupci
            dbg(row_i) := shown_matrix(((row_i + 7) mod 8) * 8 + col_idx);

            -- fyzický displej: row = 0 znamená svítí
            r(row_i) := not dbg(row_i);
        end loop;

        col_reg <= c;
        row_reg <= r;
        debug_leds <= dbg;
    end process;

    col <= col_reg;
    row <= row_reg;

end Behavioral;
