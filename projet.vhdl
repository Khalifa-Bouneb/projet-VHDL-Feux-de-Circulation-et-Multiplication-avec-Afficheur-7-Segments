library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Entité principale
entity traffic_light_system is
    Port (
        clk      : in  STD_LOGIC;                     -- Horloge principale
        rst      : in  STD_LOGIC;                     -- Réinitialisation
        mode_sel : in  STD_LOGIC;                     -- Sélection de mode (0: automatique, 1: manuel)
        ual_sel  : in  STD_LOGIC;                     -- Sélection UAL (0: feux de circulation, 1: multiplication)
        a, b     : in  STD_LOGIC_VECTOR (3 downto 0); -- Entrées de l'UAL
        light    : out STD_LOGIC_VECTOR (2 downto 0); -- Sortie pour les feux (R, O, G)
        seg      : out STD_LOGIC_VECTOR (6 downto 0); -- Sortie pour les segments du 7 segments
        an       : out STD_LOGIC_VECTOR (3 downto 0)  -- Sortie pour les anodes du 7 segments
    );
end traffic_light_system;

architecture Behavioral of traffic_light_system is
    -- Déclaration des états pour le feu de circulation
    type state_type is (RED, GREEN, ORANGE);
    signal state       : state_type := RED;
    signal timer       : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal count       : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal product     : STD_LOGIC_VECTOR(7 downto 0);

    -- Signaux pour l'affichage 7 segments
    signal digit0, digit1, digit2, digit3 : STD_LOGIC_VECTOR(3 downto 0);

    -- Déclaration du composant pour l'affichage 7 segments
    component SevenSegmentDisplay is
        Port (
            clk    : in  STD_LOGIC;
            reset  : in  STD_LOGIC;
            digit0 : in  STD_LOGIC_VECTOR(3 downto 0);
            digit1 : in  STD_LOGIC_VECTOR(3 downto 0);
            digit2 : in  STD_LOGIC_VECTOR(3 downto 0);
            digit3 : in  STD_LOGIC_VECTOR(3 downto 0);
            seg    : out STD_LOGIC_VECTOR(6 downto 0);
            an     : out STD_LOGIC_VECTOR(3 downto 0)
        );
    end component;

begin
    -- Processus principal
    process(clk, rst)
    begin
        if rst = '1' then
            state <= RED;
            light <= "100";  -- Rouge
            timer <= "0000";
            count <= "0000";
            product <= (others => '0');

        elsif rising_edge(clk) then
            if ual_sel = '0' then  -- Mode feux de circulation
                if mode_sel = '0' then  -- Mode automatique
                    -- Gestion du timer
                    if timer = "1111" then  -- Reset à 15
                        timer <= "0000";
                    else
                        timer <= timer + 1;
                    end if;

                    -- Machine à états
                    case state is
                        when RED =>
                            light <= "100";  -- Rouge
                            if timer = "1111" then
                                state <= GREEN;
                            end if;

                        when GREEN =>
                            light <= "001";  -- Vert
                            if timer = "1111" then
                                state <= ORANGE;
                            end if;

                        when ORANGE =>
                            light <= "010";  -- Orange
                            if timer = "0111" then  -- Durée plus courte pour l'orange
                                state <= RED;
                            end if;
                    end case;

                else  -- Mode manuel
                    if count = "1111" then
                        count <= "0000";
                    else
                        count <= count + 1;
                    end if;

                    -- Changement d'état tous les 4 cycles
                    case count is
                        when "0011" => state <= GREEN;
                        when "0111" => state <= ORANGE;
                        when "1011" => state <= RED;
                        when others => null;
                    end case;

                    -- Mise à jour des feux
                    case state is
                        when RED    => light <= "100";
                        when GREEN  => light <= "001";
                        when ORANGE => light <= "010";
                    end case;
                end if;

            else  -- Mode UAL (multiplication)
                product <= a * b;
            end if;
        end if;
    end process;

    -- Mappage des chiffres pour l'affichage
    digit0 <= product(3 downto 0) when ual_sel = '1' else timer;
    digit1 <= product(7 downto 4) when ual_sel = '1' else "0000";
    digit2 <= "0000";
    digit3 <= "0000";

    -- Instanciation du module d'affichage
    SevenSegment: SevenSegmentDisplay
        Port map (
            clk    => clk,
            reset  => rst,
            digit0 => digit0,
            digit1 => digit1,
            digit2 => digit2,
            digit3 => digit3,
            seg    => seg,
            an     => an
        );

end Behavioral;

-- Module d'affichage 7 segments
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity SevenSegmentDisplay is
    Port (
        clk    : in  STD_LOGIC;
        reset  : in  STD_LOGIC;
        digit0 : in  STD_LOGIC_VECTOR(3 downto 0);
        digit1 : in  STD_LOGIC_VECTOR(3 downto 0);
        digit2 : in  STD_LOGIC_VECTOR(3 downto 0);
        digit3 : in  STD_LOGIC_VECTOR(3 downto 0);
        seg    : out STD_LOGIC_VECTOR(6 downto 0);
        an     : out STD_LOGIC_VECTOR(3 downto 0)
    );
end SevenSegmentDisplay;

architecture Behavioral of SevenSegmentDisplay is
    signal refresh_counter : STD_LOGIC_VECTOR(19 downto 0) := (others => '0');  -- Compteur pour le rafraîchissement
    signal display_select : STD_LOGIC_VECTOR(1 downto 0) := "00";              -- Sélection de l'afficheur
    signal current_digit  : STD_LOGIC_VECTOR(3 downto 0) := "0000";            -- Chiffre actuellement affiché
    signal anode_select   : STD_LOGIC_VECTOR(3 downto 0) := "1111";            -- Sélection des anodes
begin
    -- Processus de rafraîchissement et multiplexage
    process(clk, reset)
    begin
        if reset = '1' then
            refresh_counter <= (others => '0');
            display_select <= "00";
        elsif rising_edge(clk) then
            refresh_counter <= refresh_counter + 1;
            -- Utilise les 2 bits supérieurs pour la sélection de l'afficheur
            display_select <= refresh_counter(19 downto 18);
        end if;
    end process;

    -- Sélection du chiffre à afficher
    process(display_select, digit0, digit1, digit2, digit3)
    begin
        case display_select is
            when "00" => current_digit <= digit0;
            when "01" => current_digit <= digit1;
            when "10" => current_digit <= digit2;
            when "11" => current_digit <= digit3;
            when others => current_digit <= "0000";
        end case;
    end process;

    -- Décodage pour l'activation des anodes
    process(display_select)
    begin
        case display_select is
            when "00" => anode_select <= "1110";
            when "01" => anode_select <= "1101";
            when "10" => anode_select <= "1011";
            when "11" => anode_select <= "0111";
            when others => anode_select <= "1111";
        end case;
    end process;

    -- Décodage BCD vers 7 segments (actif à '0')
    process(current_digit)
    begin
        case current_digit is
            when "0000" => seg <= "1000000"; -- 0
            when "0001" => seg <= "1111001"; -- 1
            when "0010" => seg <= "0100100"; -- 2
            when "0011" => seg <= "0110000"; -- 3
            when "0100" => seg <= "0011001"; -- 4
            when "0101" => seg <= "0010010"; -- 5
            when "0110" => seg <= "0000010"; -- 6
            when "0111" => seg <= "1111000"; -- 7
            when "1000" => seg <= "0000000"; -- 8
            when "1001" => seg <= "0010000"; -- 9
            when others => seg <= "1111111"; -- Éteint
        end case;
    end process;

    -- Assignation des anodes
    an <= anode_select;
end Behavioral;
