library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Chenillard_Encodeur is
    port (
        CLK     : in  std_logic;
        rst     : in  std_logic;
        ena     : in  std_logic;
        A       : in  std_logic;
        B       : in  std_logic;
        LEDS    : out std_logic_vector(9 downto 0)
    );
end entity Chenillard_Encodeur;

architecture rtl of Chenillard_Encodeur is

    -- Composant Encodeur
    component Encodeur is
        port (
            A   : in  std_logic;
            B   : in  std_logic;
            CLK : in  std_logic;
            rst : in  std_logic;
            ena : in  std_logic;
            val : out std_logic_vector(9 downto 0)
        );
    end component;

    signal s_val : std_logic_vector(9 downto 0);

begin

    -- Instanciation du bloc encodeur
    inst_encodeur : Encodeur
        port map (
            A   => A,
            B   => B,
            CLK => CLK,
            rst => rst,
            ena => ena,
            val => s_val
        );

    -- Gestion du chenillard en fonction de la valeur du compteur
    process(CLK, rst)
        variable v_index : integer range 0 to 9;
    begin
        if rst = '0' then
            LEDS <= (others => '0');
        elsif rising_edge(CLK) then
            if ena = '1' then
                -- Récupération des 4 bits de poids faible pour déterminer la LED active (0 à 9)
                v_index := to_integer(unsigned(s_val)) mod 10;
                
                -- Décalage du bit à 1 pour faire le chenillard
                LEDS <= (others => '0');
                LEDS(v_index) <= '1';
            end if;
        end if;
    end process;

end architecture rtl;