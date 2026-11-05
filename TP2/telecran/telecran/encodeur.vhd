library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library pll;
use pll.all;

entity Encodeur is 
    port (
        A   : in  std_logic;
        B   : in  std_logic;
        CLK : in  std_logic;
        rst : in  std_logic;
		  ena : in  std_logic;
        val : out std_logic_vector(9 downto 0)
    );
end entity;

architecture arch of Encodeur is
    signal ACRT     : std_logic;
    signal APREV    : std_logic;
    signal BCRT     : std_logic;
    signal BPREV    : std_logic; 
    signal COMPTEUR : unsigned(9 downto 0);
begin                       

    process(CLK, rst)
    begin
        if rst = '0' then 
            ACRT     <= '0';
            APREV    <= '0';
            BCRT     <= '0';
            BPREV    <= '0';
            COMPTEUR <= (others => '0');
            
        elsif rising_edge(CLK) then
			if ena = '1' then
					ACRT  <= A;
					APREV <= ACRT;
					BCRT  <= B;
					BPREV <= BCRT;
        
					if (ACRT = '1' and APREV = '0' and BCRT = '0' and BPREV = '0') then
						COMPTEUR <= COMPTEUR + 1;
                
					elsif (ACRT = '0' and APREV = '0' and BCRT = '1' and BPREV = '0') then
						COMPTEUR <= COMPTEUR - 1;
					end if;
        end if;
    end process;
	val <= std_logic_vector(COMPTEUR) 
end arch;