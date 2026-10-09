library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package matrix_pack is

-- Vyctovy typ STATE_T, ktery obsahuje stavy pro zobrazeni
type STATE_T is (
    S_BCD_NORM,
    S_BCD_INV,
    S_ALT
);

-- Funkce provede bitovy AND mezi bity vektoru DATA_A a DATA_B
-- a nasledne provede OR redukci vysledne hodnoty
function WLOG_REDUCE(DATA_A, DATA_B : in STD_LOGIC_VECTOR) return STD_LOGIC;

-- Funkce vraci nejblizsi vyssi mocninu cisla 2 pro zadanou hodnotu DATA.
function NEAREST2N(DATA : in natural) return natural;
end package matrix_pack;

package body matrix_pack is

function WLOG_REDUCE(DATA_A, DATA_B : in STD_LOGIC_VECTOR) return STD_LOGIC is
    variable or_reduce : STD_LOGIC := '0';
begin

    -- Kontrola, ze velikost vektoru je stejna
    if DATA_A'length /= DATA_B'length then
        report "Parameters DATA_A and DATA_B have different sizes"
        severity failure;
    end if;

    for i in DATA_A'range loop
        or_reduce := or_reduce or (DATA_A(i) and DATA_B(i));
    end loop;

    return or_reduce;
end function WLOG_REDUCE;

function NEAREST2N(DATA : in natural) return natural is
    variable next_pow2 : natural := 1;
begin

    while next_pow2 < DATA loop
        next_pow2 := next_pow2 * 2;
    end loop;

    return next_pow2;
end function NEAREST2N;
end package body matrix_pack;
