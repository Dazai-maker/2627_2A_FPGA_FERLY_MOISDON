library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- entité principale liant l'encodeur rotatif aux leds
entity Chenillard_Encodeur is
    port (
        CLK  : in  std_logic; -- horloge système
        rst  : in  std_logic; -- reset actif à l'état bas
        ena  : in  std_logic; -- validation d'activation
        A    : in  std_logic; -- voie a de l'encodeur
        B    : in  std_logic; -- voie b de l'encodeur
        LEDS : out std_logic_vector(9 downto 0) -- bus des 10 leds
    );
end entity Chenillard_Encodeur;

architecture rtl of Chenillard_Encodeur is

    -- déclaration du composant encodeur
    component Encodeur is
        generic (
            N : integer := 10
        );
        port (
            A   : in  std_logic;
            B   : in  std_logic;
            CLK : in  std_logic;
            rst : in  std_logic;
            ena : in  std_logic;
            val : out std_logic_vector(N-1 downto 0)
        );
    end component;

    signal s_val      : std_logic_vector(9 downto 0); -- valeur courante issue de l'encodeur
    signal s_val_prev : unsigned(9 downto 0); -- valeur précédente mémorisée
    signal s_led_idx  : integer range 0 to 9; -- index de la led allumée

begin

    -- instanciation de l'encodeur sur 10 bits
    inst_encodeur : Encodeur
        generic map (
            N => 10
        )
        port map (
            A   => A,
            B   => B,
            CLK => CLK,
            rst => rst,
            ena => ena,
            val => s_val
        );

    -- mise à jour de l'index de led selon le sens de rotation
    process(CLK, rst)
        variable v_cur : unsigned(9 downto 0); -- conversion non signée de s_val
    begin
        if rst = '0' then
            s_val_prev <= (others => '0');
            s_led_idx  <= 0;
        elsif rising_edge(CLK) then
            if ena = '1' then
                v_cur := unsigned(s_val);

                if v_cur /= s_val_prev then
                    -- incrément (avec rebouclage de 1023 à 0)
                    if (v_cur = s_val_prev + 1) or ((s_val_prev = to_unsigned(1023, 10)) and (v_cur = 0)) then
                        if s_led_idx = 9 then
                            s_led_idx <= 0;
                        else
                            s_led_idx <= s_led_idx + 1;
                        end if;
                    -- décrément (avec rebouclage de 0 à 1023)
                    elsif (v_cur = s_val_prev - 1) or ((s_val_prev = 0) and (v_cur = to_unsigned(1023, 10))) then
                        if s_led_idx = 0 then
                            s_led_idx <= 9;
                        else
                            s_led_idx <= s_led_idx - 1;
                        end if;
                    end if;

                    s_val_prev <= v_cur;
                end if;
            end if;
        end if;
    end process;

    -- décodage de l'index vers le vecteur de leds
    process(s_led_idx, rst)
        variable v_leds : std_logic_vector(9 downto 0); -- vecteur temporaire des leds
    begin
        v_leds := (others => '0');
        if rst = '1' then
            v_leds(s_led_idx) := '1';
        end if;
        LEDS <= v_leds;
    end process;

end architecture rtl;
