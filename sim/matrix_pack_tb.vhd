library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.matrix_pack.all;

-- Testovani funkci WLOG_REDUCE a NEAREST2N z baliku matrix_pack
entity matrix_pack_tb is
end entity matrix_pack_tb;

architecture function_testing of matrix_pack_tb is

begin
process
    variable wlog_result : STD_LOGIC;
    variable pow2_result : natural;
begin

    -- Testovani funkce WLOG_REDUCE
    wlog_result := WLOG_REDUCE("0000", "0000");
    assert wlog_result = '0'
    report "Test of function NEAREST2N(0000, 0000) failed"
    severity error;

    wlog_result := WLOG_REDUCE("1010", "0101");
    assert wlog_result = '0'
    report "Test of function NEAREST2N(1010, 0101) failed"
    severity error;
    
    wlog_result := WLOG_REDUCE("1010101010101010", "0010000000000000");
    assert wlog_result = '1'
    report "WLOG_REDUCE test failed for 16-bit vectors"
    severity error;

    wlog_result := WLOG_REDUCE(
    "10000000000000000000000000000000",
    "10000000000000000000000000000000"
    );
    assert wlog_result = '1'
    report "WLOG_REDUCE test failed for 32-bit vectors"
    severity error;

    -- Testovani funkce NEAREST2N
    pow2_result := NEAREST2N(6);
    assert pow2_result = 8
    report "Test of function NEAREST2N(6) failed"
    severity error;

    pow2_result := NEAREST2N(42);
    assert pow2_result = 64
    report "Test of function NEAREST2N(42) failed"
    severity error;

    pow2_result := NEAREST2N(64);
    assert pow2_result = 64
    report "Test of function NEAREST2N(64) failed"
    severity error;

    -- Kdyz vsechny testy projdou, vypise se oznameni:
    report "Simulation completed: all test cases passed";
    wait;
end process;
end architecture function_testing;
