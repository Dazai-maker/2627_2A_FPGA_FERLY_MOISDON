library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library pll;
use pll.all;

entity telecran is
    port (
        -- FPGA
        i_clk_50 : in std_logic;

        -- HDMI
        io_hdmi_i2c_scl : inout std_logic;
        io_hdmi_i2c_sda : inout std_logic;
        o_hdmi_tx_clk   : out std_logic;
        o_hdmi_tx_d     : out std_logic_vector(23 downto 0);
        o_hdmi_tx_de    : out std_logic;
        o_hdmi_tx_hs    : out std_logic;
        i_hdmi_tx_int   : in std_logic;
        o_hdmi_tx_vs    : out std_logic;

        -- KEYs
        i_rst_n : in std_logic;

        -- LEDs
        o_leds      : out std_logic_vector(9 downto 0);
        o_de10_leds : out std_logic_vector(7 downto 0);

        -- Coder
        i_left_ch_a  : in std_logic;
        i_left_ch_b  : in std_logic;
        i_left_pb    : in std_logic;
        i_right_ch_a : in std_logic;
        i_right_ch_b : in std_logic;
        i_right_pb   : in std_logic
    );
end entity telecran;

architecture rtl of telecran is

    component encodeur
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

    component diviseur_1ms
        port (
            clk   : in  std_logic;
            rst_n : in  std_logic;
            tick  : out std_logic
        );
    end component;

    component I2C_HDMI_Config
        port (
            iCLK        : in std_logic;
            iRST_N      : in std_logic;
            I2C_SCLK    : out std_logic;
            I2C_SDAT    : inout std_logic;
            HDMI_TX_INT : in std_logic
        );
    end component;

    component pll
        port (
            refclk   : in std_logic;
            rst      : in std_logic;
            outclk_0 : out std_logic;
            locked   : out std_logic
        );
    end component;

    component hdmi_controler
        generic (
            h_res  : positive := 720;
            v_res  : positive := 480;
            h_sync : positive := 61;
            h_fp   : positive := 58;
            h_bp   : positive := 18;
            v_sync : positive := 5;
            v_fp   : positive := 30;
            v_bp   : positive := 9
        );
        port (
            i_clk           : in std_logic;
            i_rst_n         : in std_logic;
            o_hdmi_hs       : out std_logic;
            o_hdmi_vs       : out std_logic;
            o_hdmi_de       : out std_logic;
            o_pixel_en      : out std_logic;
            o_pixel_address : out natural range 0 to (h_res * v_res - 1);
            o_x_counter     : out natural range 0 to (h_res - 1);
            o_y_counter     : out natural range 0 to (v_res - 1)
        );
    end component;

    component dpram
        generic (
            mem_size   : natural := 720 * 480;
            data_width : natural := 8
        );
        port (
            i_clk_a  : in std_logic;
            i_clk_b  : in std_logic;
            i_data_a : in std_logic_vector(data_width-1 downto 0);
            i_data_b : in std_logic_vector(data_width-1 downto 0);
            i_addr_a : in natural range 0 to mem_size-1;
            i_addr_b : in natural range 0 to mem_size-1;
            i_we_a   : in std_logic := '1';
            i_we_b   : in std_logic := '1';
            o_q_a    : out std_logic_vector(data_width-1 downto 0);
            o_q_b    : out std_logic_vector(data_width-1 downto 0)
        );
    end component;

    constant h_res    : natural := 720;
    constant v_res    : natural := 480;
    constant mem_size : natural := h_res * v_res;

    signal s_clk_27  : std_logic;
    signal s_rst_n   : std_logic;
    signal s_hdmi_de : std_logic;

    signal s_x_counter     : natural range 0 to (h_res - 1);
    signal s_y_counter     : natural range 0 to (v_res - 1);
    signal s_pixel_address : natural range 0 to (mem_size - 1);

    signal s_tick_1ms      : std_logic;
    signal s_enc_left_val  : std_logic_vector(9 downto 0);
    signal s_enc_right_val : std_logic_vector(9 downto 0);

    signal s_pos_x : natural range 0 to (h_res - 1) := 0;
    signal s_pos_y : natural range 0 to (v_res - 1) := 0;

    -- Signaux DPRAM
    signal s_addr_cursor : natural range 0 to (mem_size - 1);
    signal s_ram_addr_a  : natural range 0 to (mem_size - 1);
    signal s_ram_data_a  : std_logic_vector(7 downto 0);
    signal s_ram_q_b     : std_logic_vector(7 downto 0);

    -- Signaux d'effacement
    signal s_clear_active : std_logic := '0';
    signal s_clear_addr   : natural range 0 to (mem_size - 1) := 0;

begin
    o_leds      <= (others => '0');
    o_de10_leds <= (others => '0');

    -- PLL 27 MHz
    pll0 : component pll
        port map (
            refclk   => i_clk_50,
            rst      => not(i_rst_n),
            outclk_0 => s_clk_27,
            locked   => s_rst_n
        );

    -- Configuration I2C HDMI
    I2C_HDMI_Config0 : component I2C_HDMI_Config
        port map (
            iCLK        => i_clk_50,
            iRST_N      => i_rst_n,
            I2C_SCLK    => io_hdmi_i2c_scl,
            I2C_SDAT    => io_hdmi_i2c_sda,
            HDMI_TX_INT => i_hdmi_tx_int
        );

    o_hdmi_tx_clk <= s_clk_27;
    o_hdmi_tx_de  <= s_hdmi_de;

    -- Controleur HDMI
    hdmi_controler0 : component hdmi_controler
        port map (
            i_clk           => s_clk_27,
            i_rst_n         => s_rst_n,
            o_hdmi_hs       => o_hdmi_tx_hs,
            o_hdmi_vs       => o_hdmi_tx_vs,
            o_hdmi_de       => s_hdmi_de,
            o_pixel_en      => open,
            o_pixel_address => s_pixel_address,
            o_x_counter     => s_x_counter,
            o_y_counter     => s_y_counter
        );

    -- Diviseur 1 ms (anti-rebond)
    diviseur0 : component diviseur_1ms
        port map (
            clk   => i_clk_50,
            rst_n => i_rst_n,
            tick  => s_tick_1ms
        );

    -- Encodeur gauche (horizontal X)
    enc_left : component encodeur
        generic map (
            N => 10
        )
        port map (
            A   => i_left_ch_a,
            B   => i_left_ch_b,
            CLK => i_clk_50,
            rst => i_rst_n,
            ena => s_tick_1ms,
            val => s_enc_left_val
        );

    -- Encodeur droit (vertical Y)
    enc_right : component encodeur
        generic map (
            N => 10
        )
        port map (
            A   => i_right_ch_a,
            B   => i_right_ch_b,
            CLK => i_clk_50,
            rst => i_rst_n,
            ena => s_tick_1ms,
            val => s_enc_right_val
        );

    -- Position (X, Y) issue des encodeurs, bornee aux dimensions de l'ecran
    process(i_clk_50, i_rst_n)
        variable v_x, v_y : integer;
    begin
        if (i_rst_n = '0') then
            s_pos_x <= 0;
            s_pos_y <= 0;
        elsif rising_edge(i_clk_50) then
            v_x := to_integer(unsigned(s_enc_left_val));
            v_y := to_integer(unsigned(s_enc_right_val));

            if v_x < integer(h_res) then
                s_pos_x <= v_x;
            else
                s_pos_x <= h_res - 1;
            end if;

            if v_y < integer(v_res) then
                s_pos_y <= v_y;
            else
                s_pos_y <= v_res - 1;
            end if;
        end if;
    end process;

    -- Calcul de l'adresse lineaire du pixel courant
    s_addr_cursor <= (s_pos_y * h_res) + s_pos_x;

    -- Machine d'effacement de la RAM sur appui de i_left_pb
    process(i_clk_50, i_rst_n)
    begin
        if (i_rst_n = '0') then
            s_clear_active <= '0';
            s_clear_addr   <= 0;
        elsif rising_edge(i_clk_50) then
            if s_clear_active = '0' then
                if i_left_pb = '0' then
                    s_clear_active <= '1';
                    s_clear_addr   <= 0;
                end if;
            else
                if s_clear_addr = mem_size - 1 then
                    s_clear_active <= '0';
                    s_clear_addr   <= 0;
                else
                    s_clear_addr <= s_clear_addr + 1;
                end if;
            end if;
        end if;
    end process;

    -- Multiplexage Port A (ecriture pixel vs effacement complet)
    s_ram_addr_a <= s_clear_addr  when s_clear_active = '1' else s_addr_cursor;
    s_ram_data_a <= x"00"         when s_clear_active = '1' else x"01";

    -- Memoire Dual-Port (Framebuffer)
    dpram0 : component dpram
        generic map (
            mem_size   => mem_size,
            data_width => 8
        )
        port map (
            i_clk_a  => i_clk_50,
            i_clk_b  => s_clk_27,
            i_data_a => s_ram_data_a,
            i_data_b => (others => '0'),
            i_addr_a => s_ram_addr_a,
            i_addr_b => s_pixel_address,
            i_we_a   => '1',
            i_we_b   => '0',
            o_q_a    => open,
            o_q_b    => s_ram_q_b
        );

    -- Affichage video (lecture Port B + curseur rouge)
    process(s_clk_27, s_rst_n)
    begin
        if (s_rst_n = '0') then
            o_hdmi_tx_d <= x"000000";
        elsif rising_edge(s_clk_27) then
            if s_hdmi_de = '1' then
                if (s_x_counter = s_pos_x) and (s_y_counter = s_pos_y) then
                    o_hdmi_tx_d <= x"FF0000"; -- Pixel courant en rouge
                elsif s_ram_q_b = x"01" then
                    o_hdmi_tx_d <= x"FFFFFF"; -- Trace memorise en blanc
                else
                    o_hdmi_tx_d <= x"000000"; -- Fond noir
                end if;
            else
                o_hdmi_tx_d <= x"000000";
            end if;
        end if;
    end process;

end architecture rtl;
