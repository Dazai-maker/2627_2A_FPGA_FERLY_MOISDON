library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Encodeur is 
    generic (
        N : integer := 10 -- Paramètre de taille indispensable pour l'instanciation
    );
    port (
        A   : in  std_logic;
        B   : in  std_logic;
        CLK : in  std_logic;
        rst : in  std_logic;
        ena : in  std_logic;
        val : out std_logic_vector(N-1 downto 0)
    );
end entity Encodeur;

architecture arch of Encodeur is
    signal ACRT     : std_logic;
    signal APREV    : std_logic;
    signal BCRT     : std_logic;
    signal BPREV    : std_logic; 
    signal COMPTEUR : unsigned(N-1 downto 0);
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
                -- Échantillonnage des signaux
                ACRT  <= A;
                APREV <= ACRT;
                BCRT  <= B;
                BPREV <= BCRT;
        
                -- Incrémentation : Front montant A (A=1, APREV=0) et B est à l'état bas (BCRT=0)
                -- OU Front descendant A (A=0, APREV=1) et B est à l'état haut (BCRT=1)
                if ((ACRT = '1' and APREV = '0' and BCRT = '0') or 
                    (ACRT = '0' and APREV = '1' and BCRT = '1')) then
                    COMPTEUR <= COMPTEUR + 1;
            
                -- Décrémentation : Front montant B (B=1, BPREV=0) et A est à l'état bas (ACRT=0)
                -- OU Front descendant B (B=0, BPREV=1) et A est à l'état haut (ACRT=1)
                elsif ((BCRT = '1' and BPREV = '0' and ACRT = '0') or 
                       (BCRT = '0' and BPREV = '1' and ACRT = '1')) then                    
                    COMPTEUR <= COMPTEUR - 1;
                end if;
            end if;
        end if;
    end process;

    -- Assignation de la valeur interne vers la sortie
    val <= std_logic_vector(COMPTEUR); 

end architecture arch;