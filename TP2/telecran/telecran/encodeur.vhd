library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Encodeur is
    generic (
        N            : integer := 10;
        DEBOUNCE_MAX : integer := 54000 -- ~2 ms à 27 MHz
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
    -- Synchronisation double bascule (métastabilité)
    signal a_sync_0, a_sync_1 : std_logic;
    signal b_sync_0, b_sync_1 : std_logic;

    -- Signaux filtrés anti-rebond
    signal a_clean : std_logic;
    signal b_clean : std_logic;
    signal a_cnt   : integer range 0 to DEBOUNCE_MAX;
    signal b_cnt   : integer range 0 to DEBOUNCE_MAX;

    -- États courant et précédent pour la quadrature
    signal ACRT     : std_logic;
    signal APREV    : std_logic;
    signal BCRT     : std_logic;
    signal BPREV    : std_logic;
    signal COMPTEUR : unsigned(N-1 downto 0);
begin

    -- Anti-rebond sur A et B + comptage en quadrature
    process(CLK, rst)
    begin
        if rst = '0' then
            a_sync_0 <= '0';
            a_sync_1 <= '0';
            b_sync_0 <= '0';
            b_sync_1 <= '0';

            a_clean <= '0';
            b_clean <= '0';
            a_cnt   <= 0;
            b_cnt   <= 0;

            ACRT     <= '0';
            APREV    <= '0';
            BCRT     <= '0';
            BPREV    <= '0';
            COMPTEUR <= (others => '0');

        elsif rising_edge(CLK) then
            -- Resynchronisation sur CLK
            a_sync_0 <= A;
            a_sync_1 <= a_sync_0;
            b_sync_0 <= B;
            b_sync_1 <= b_sync_0;

            -- Filtre anti-rebond canal A
            if a_sync_1 = a_clean then
                a_cnt <= 0;
            else
                if a_cnt = DEBOUNCE_MAX then
                    a_clean <= a_sync_1;
                    a_cnt   <= 0;
                else
                    a_cnt <= a_cnt + 1;
                end if;
            end if;

            -- Filtre anti-rebond canal B
            if b_sync_1 = b_clean then
                b_cnt <= 0;
            else
                if b_cnt = DEBOUNCE_MAX then
                    b_clean <= b_sync_1;
                    b_cnt   <= 0;
                else
                    b_cnt <= b_cnt + 1;
                end if;
            end if;

            -- Détection quadrature sur signaux filtrés
            if ena = '1' then
                ACRT  <= a_clean;
                APREV <= ACRT;
                BCRT  <= b_clean;
                BPREV <= BCRT;

                if ((ACRT = '1' and APREV = '0' and BCRT = '0') or
                    (ACRT = '0' and APREV = '1' and BCRT = '1')) then
                    COMPTEUR <= COMPTEUR + 1;

                elsif ((BCRT = '1' and BPREV = '0' and ACRT = '0') or
                       (BCRT = '0' and BPREV = '1' and ACRT = '1')) then
                    COMPTEUR <= COMPTEUR - 1;
                end if;
            end if;
        end if;
    end process;

    val <= std_logic_vector(COMPTEUR);

end architecture arch;
